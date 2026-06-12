# i18n 配置说明（你需要做的 3 件事）

中文站点 + 英文站点都由 GitHub Actions **构建期**生成（不再依赖在线翻译脚本），所以网页加载是 0 等待的。

中文版地址保持不变：`https://manifoldtechltd.github.io/wiki/`
英文版地址：`https://manifoldtechltd.github.io/wiki/en/`

每页右上角有 `中文 | EN` 切换按钮。

---

## ① 申请 DeepL Free API key（5 分钟）

1. 访问 <https://www.deepl.com/pro-api> → 选 **DeepL API Free**（每月 50 万字符免费，本仓库一次全量翻译约用 4 万字符 ≈ 8% 配额）
2. 注册时**需要绑定信用卡用于身份验证**（不会扣费，免费档严格不超额）
3. 登录后进入 [Account → API keys](https://www.deepl.com/account/summary) 复制 **Authentication Key**

> 如果不想给信用卡，可换成 **Google Cloud Translation v3**（每月 50 万字符免费）。需要在脚本里把端点改成 Google API，并改一下认证方式。需要的话告诉我。

## ② 把 key 加到 GitHub Secrets

仓库主页 → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

| Name             | Secret                          |
|------------------|---------------------------------|
| `DEEPL_API_KEY`  | 上一步复制的 Authentication Key |

> 如果你用的是 DeepL **Pro** 而非 Free，再加一个变量 `DEEPL_API_URL = https://api.deepl.com/v2/translate`（Pro 端点）。Free 用户不需要。

## ③ 切换 Pages 部署源为 GitHub Actions

仓库 → **Settings** → **Pages** → **Source** 下拉选 **GitHub Actions**（之前是 *Deploy from a branch*）。

> 这一步是必须的——只有这样自定义 Action 才能部署。改完后第一次部署的 URL 仍然是 `https://manifoldtechltd.github.io/wiki/`，不影响访客。

---

## 之后是怎么工作的？

每次 push 到 `master`：

```
.github/workflows/build-and-deploy.yml
  ├─ 用 scripts/translate_md.py 增量把 docs/*.md → docs_en/*.md
  │   （hash 缓存：未变化的文件跳过，不消耗 DeepL 配额）
  ├─ Jekyll 构建中文站  →  _site/
  ├─ Jekyll 构建英文站  →  _site/en/
  └─ Deploy 到 GitHub Pages
```

第一次 build 大概需要 **4–6 分钟**（22 个文件 × DeepL 串行调用）。后续只翻译变更过的文件，通常 **30 秒**就能跑完。

## 想本地预览英文版

```bash
cd wiki
export DEEPL_API_KEY=xxx        # 或不设，会原样复制中文（用于无 key 调试）
python3 scripts/translate_md.py # 生成 docs_en/

# 然后照常 jekyll serve 中文版
cd docs && bundle exec jekyll serve
# 想看英文版本地预览：
cp docs/_config.yml docs_en/_config.yml
cp -r docs/_includes docs_en/_includes
echo 'lang: en' >> docs_en/_config.yml
cd .. && bundle exec jekyll serve -s docs_en --baseurl /wiki/en
```

## 文件改了之后

* **改中文文档** → push → CI 自动重译那一个文件 → 英文版自动同步
* **想手动调整某个英文译文** → 直接改 `docs_en/xx.md` 即可，但下次中文文件再变它会被重译覆盖。**永久修订**请改 `scripts/translate_md.py` 里的术语映射（暂未实现，未来可加 `glossary` 字段）

## 翻译质量说明

DeepL 在技术文档上的水平大致接近母语工程师水平。代码块、Mermaid、命令、API 名、链接、图片路径、Liquid 模板都被保护**不会**被翻译。少数中文专有名词（如「留形科技」「具身智能」）可能音译，如果你想锁定专门的英文译法，告诉我术语对照表我加进脚本。
