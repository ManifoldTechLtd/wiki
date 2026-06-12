#!/usr/bin/env python3
"""
Translate Chinese Markdown docs to English using DeepL API.

Reads:   docs/**/*.md
Writes:  docs_en/**/*.md   (mirror structure)

Features:
- Protects fenced code blocks, inline code, math, Liquid tags, raw HTML, links,
  images and URLs from being translated (DeepL XML tag-handling mode).
- Caches by SHA-256 in .translate-cache.json so unchanged files are skipped.
- Copies non-md assets (images, pdf, css, etc.) to docs_en/ verbatim.
- Falls back to identity translation when DEEPL_API_KEY is not set
  (lets the pipeline build something for testing without burning quota).

Env:
  DEEPL_API_KEY   required for actual translation
  DEEPL_API_URL   default https://api-free.deepl.com/v2/translate
                  (set to https://api.deepl.com/v2/translate for Pro)
"""

import hashlib
import json
import os
import re
import shutil
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

# ----------------------------- Config ---------------------------------------

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "docs"
DST = ROOT / "docs_en"
CACHE_PATH = ROOT / ".translate-cache.json"

DEEPL_KEY = os.environ.get("DEEPL_API_KEY", "").strip()
DEEPL_URL = os.environ.get(
    "DEEPL_API_URL", "https://api-free.deepl.com/v2/translate"
).strip()

# Directories under docs/ to skip entirely
SKIP_DIRS = {"_site", ".jekyll-cache"}

# Suffixes that we copy verbatim (binary or untranslated assets)
ASSET_SUFFIXES = {
    ".png", ".jpg", ".jpeg", ".gif", ".webp", ".svg", ".ico",
    ".pdf", ".stp", ".step", ".rar", ".zip", ".7z",
    ".css", ".js", ".woff", ".woff2", ".ttf",
    ".html",  # _includes/*.html — copied as-is
    ".yml", ".yaml",
    ".py",
}

# ----------------------------- Protect / Restore -----------------------------
# Patterns are tried IN ORDER. Earlier (longer) patterns get matched first.

PROTECT_PATTERNS = [
    # 1) Fenced code blocks  ```lang ... ```
    re.compile(r"```[\s\S]*?```", re.MULTILINE),
    # 2) Indented code (4-space) — risky to match generically; skip.
    # 3) Inline math  $$ ... $$  and  $ ... $
    re.compile(r"\$\$[\s\S]*?\$\$", re.MULTILINE),
    re.compile(r"(?<!\\)\$[^$\n]+\$"),
    # 4) Liquid tags  {% ... %}  and  {{ ... }}
    re.compile(r"\{%[\s\S]*?%\}"),
    re.compile(r"\{\{[\s\S]*?\}\}"),
    # 5) Markdown images  ![alt](url)  — keep verbatim (alt seldom present)
    re.compile(r"!\[[^\]]*\]\([^)]*\)"),
    # 6) Markdown links  [text](url)  — protect URL only by splitting later;
    #    here we protect the whole link to be safe (text may need translation
    #    but we accept losing that for safety; users can revise manually).
    #    To allow link-text translation, comment this line out.
    # re.compile(r"\[[^\]]+\]\([^)]+\)"),
    # 7) Inline code  `code`
    re.compile(r"`[^`\n]+`"),
    # 8) Bare URLs
    re.compile(r"https?://[^\s)>\]\"']+"),
    # 9) Raw HTML tags  <tag ...> and </tag>  (avoid our own <x id=...> placeholders)
    re.compile(r"</?(?!x\b)[a-zA-Z][^>]*>"),
]


def protect(text: str):
    """Replace protected fragments with <x id=N>P</x> placeholders.

    Returns (new_text, [original_fragments]).
    """
    fragments = []

    def make_replacer():
        def repl(m):
            fragments.append(m.group(0))
            return f'<x id="{len(fragments) - 1}">P</x>'

        return repl

    out = text
    for pat in PROTECT_PATTERNS:
        out = pat.sub(make_replacer(), out)
    return out, fragments


_PLACEHOLDER_RE = re.compile(r'<x id="(\d+)">[^<]*</x>')


def restore(text: str, fragments) -> str:
    def r(m):
        idx = int(m.group(1))
        if 0 <= idx < len(fragments):
            return fragments[idx]
        return m.group(0)

    return _PLACEHOLDER_RE.sub(r, text)


# ----------------------------- DeepL call -----------------------------------


def _deepl_request(text: str) -> str:
    """Single DeepL API call. Returns the translated string."""
    if not DEEPL_KEY:
        # No key: passthrough (useful for local dry-run / first-time CI before key set)
        return text

    data = urllib.parse.urlencode(
        {
            "auth_key": DEEPL_KEY,
            "text": text,
            "source_lang": "ZH",
            "target_lang": "EN-US",
            "tag_handling": "xml",
            "ignore_tags": "x",
            "split_sentences": "1",
            "preserve_formatting": "1",
        }
    ).encode("utf-8")

    req = urllib.request.Request(
        DEEPL_URL,
        data=data,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )
    last_err = None
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                payload = json.loads(r.read().decode("utf-8"))
            return payload["translations"][0]["text"]
        except Exception as e:
            last_err = e
            time.sleep(2 ** attempt)
    raise RuntimeError(f"DeepL request failed after retries: {last_err}")


def translate_text(text: str) -> str:
    """Protect → DeepL → restore. Returns translated text or original on no-op."""
    if not text or not text.strip():
        return text
    protected, frags = protect(text)
    if not protected.strip() or protected.strip() == "P":
        return text  # nothing translatable
    try:
        translated = _deepl_request(protected)
    except Exception as e:
        print(f"  [warn] DeepL failed, keeping original: {e}", file=sys.stderr)
        return text
    return restore(translated, frags)


# ----------------------------- Front matter ---------------------------------

_FM_RE = re.compile(r"^---\n([\s\S]*?)\n---\n?", re.MULTILINE)
# Front matter keys whose VALUES we translate. Other keys (parent, nav_order,
# layout, etc.) are kept untouched so just-the-docs nav links stay intact.
TRANSLATABLE_FM_KEYS = {"title", "description"}


def split_front_matter(text: str):
    m = _FM_RE.match(text)
    if not m:
        return None, text
    return m.group(1), text[m.end():]


def translate_front_matter(fm_text: str) -> str:
    out_lines = []
    for line in fm_text.split("\n"):
        m = re.match(r'^(\s*)([A-Za-z_][A-Za-z0-9_]*)(\s*:\s*)(.*)$', line)
        if not m:
            out_lines.append(line)
            continue
        indent, key, sep, val = m.groups()
        if key not in TRANSLATABLE_FM_KEYS:
            out_lines.append(line)
            continue
        val = val.strip()
        if not val:
            out_lines.append(line)
            continue
        # strip surrounding quotes
        quote = ""
        if (val.startswith('"') and val.endswith('"')) or (
            val.startswith("'") and val.endswith("'")
        ):
            quote = val[0]
            val = val[1:-1]
        translated = translate_text(val)
        if quote:
            translated = f"{quote}{translated}{quote}"
        out_lines.append(f"{indent}{key}{sep}{translated}")
    return "\n".join(out_lines)


# ----------------------------- File processing ------------------------------


def sha256_text(s: str) -> str:
    return hashlib.sha256(s.encode("utf-8")).hexdigest()


def translate_file(src: Path, dst: Path) -> None:
    text = src.read_text(encoding="utf-8")
    fm, body = split_front_matter(text)
    new_fm = translate_front_matter(fm) if fm is not None else None
    new_body = translate_text(body)

    dst.parent.mkdir(parents=True, exist_ok=True)
    out = ""
    if new_fm is not None:
        out = f"---\n{new_fm}\n---\n"
    out += new_body
    dst.write_text(out, encoding="utf-8")


def load_cache():
    if CACHE_PATH.exists():
        try:
            return json.loads(CACHE_PATH.read_text(encoding="utf-8"))
        except Exception:
            return {}
    return {}


def save_cache(c):
    CACHE_PATH.write_text(
        json.dumps(c, indent=2, ensure_ascii=False, sort_keys=True), encoding="utf-8"
    )


def is_skipped(rel: Path) -> bool:
    return any(p in SKIP_DIRS for p in rel.parts)


def main() -> int:
    if not SRC.exists():
        print(f"source not found: {SRC}", file=sys.stderr)
        return 1

    if not DEEPL_KEY:
        print("[warn] DEEPL_API_KEY not set; running in passthrough mode "
              "(English version will be the same as Chinese).", file=sys.stderr)

    cache = load_cache()
    new_cache = {}

    md_count = 0
    asset_count = 0
    skipped = 0

    for src in SRC.rglob("*"):
        if src.is_dir():
            continue
        rel = src.relative_to(SRC)
        if is_skipped(rel):
            continue

        dst = DST / rel
        suffix = src.suffix.lower()

        if suffix == ".md":
            text = src.read_text(encoding="utf-8")
            digest = sha256_text(text)
            new_cache[str(rel)] = digest
            if cache.get(str(rel)) == digest and dst.exists():
                skipped += 1
                continue
            print(f"translate: {rel}")
            try:
                translate_file(src, dst)
                md_count += 1
            except Exception as e:
                print(f"  [error] {e}", file=sys.stderr)
                # keep cache as old hash so retry next run
                new_cache[str(rel)] = cache.get(str(rel), "")
        elif suffix in ASSET_SUFFIXES:
            # copy verbatim if changed
            if (
                not dst.exists()
                or dst.stat().st_mtime < src.stat().st_mtime
                or dst.stat().st_size != src.stat().st_size
            ):
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src, dst)
                asset_count += 1
        else:
            # Unknown file type — copy verbatim to be safe
            if not dst.exists():
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src, dst)
                asset_count += 1

    save_cache(new_cache)
    print(f"\n=== Done. translated {md_count} md(s), copied {asset_count} asset(s), "
          f"skipped {skipped} cached file(s). ===")
    return 0


if __name__ == "__main__":
    sys.exit(main())
