#!/usr/bin/env bash
#
# download_lc_sdk.sh — 极简 SDK 平台检测与下载引导
#
# 运行后自动识别当前硬件平台，输出：
#   - [Detection]     硬件/软件检测结果（CPU / GPU / NPU / 运行时版本号）
#   - [Support]       推荐包与不支持原因（L4T 过旧 / glibc 过低 / Android / 非目标芯片等）
#   - [Download links] 当前机器适用的 SDK 版本及下载页面链接
#
# 完全离线运行，无外部依赖，无配置项。
#
set -euo pipefail

# 版本管理系统 Web 下载页面根地址（唯一可改项）。
WEB_BASE="https://version.manifoldtech.cn"

# ============================================================================
# 检测函数
# ============================================================================

detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64)  echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        *)             echo "unsupported:$(uname -m)" ;;
    esac
}

detect_hardware() {
    # device-tree model（ARM / Jetson / RK 等设备）
    if [ -f /proc/device-tree/model ]; then
        cat /proc/device-tree/model | tr -d '\0'
        return
    fi
    # DMI 主板/机器型号（x86 PC）
    if [ -r /sys/devices/virtual/dmi/id/product_name ]; then
        cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null
        return
    fi
    if [ -r /sys/devices/virtual/dmi/id/board_name ]; then
        cat /sys/devices/virtual/dmi/id/board_name 2>/dev/null
        return
    fi
    echo "unknown"
}

detect_cpu_vendor() {
    grep -m1 "vendor_id" /proc/cpuinfo 2>/dev/null | awk '{print $3}' || echo "unknown"
}

# detect_cpu_model: CPU 型号（x86 用 model name，ARM 用 Hardware 或 CPU part 解析）。
detect_cpu_model() {
    if [ -r /proc/cpuinfo ]; then
        if grep -q "model name" /proc/cpuinfo 2>/dev/null; then
            grep -m1 "model name" /proc/cpuinfo 2>/dev/null | sed 's/.*model name[[:space:]]*:[[:space:]]*//'
            return
        fi
        if grep -q "^Hardware" /proc/cpuinfo 2>/dev/null; then
            grep -m1 "^Hardware" /proc/cpuinfo 2>/dev/null | sed 's/.*:[[:space:]]*//'
            return
        fi
        # ARM: 从 CPU part 字段解析（多核异构取并集）
        local parts names p
        parts="$(grep "^CPU part" /proc/cpuinfo 2>/dev/null | awk '{print $4}' | sort -u | tr '\n' ' ')"
        if [ -n "$parts" ]; then
            for p in $parts; do
                case "$p" in
                    0xd0b) names="${names:+${names}+}Cortex-A76" ;;
                    0xd05) names="${names:+${names}+}Cortex-A55" ;;
                    0xd0a) names="${names:+${names}+}Cortex-A75" ;;
                    0xd09) names="${names:+${names}+}Cortex-A73" ;;
                    0xd08) names="${names:+${names}+}Cortex-A72" ;;
                    0xd03) names="${names:+${names}+}Cortex-A53" ;;
                    0xd04) names="${names:+${names}+}Cortex-A35" ;;
                    0xd0c) names="${names:+${names}+}Neoverse-N2" ;;
                    0xd44) names="${names:+${names}+}Cortex-X2" ;;
                    0xd47) names="${names:+${names}+}Cortex-X3" ;;
                    0xd4d) names="${names:+${names}+}Cortex-A720" ;;
                    *)     names="${names:+${names}+}${p}" ;;
                esac
            done
            [ -n "$names" ] && { echo "$names"; return; }
        fi
    fi
    echo "unknown"
}

# detect_gpu: GPU 型号（Jetson 集成 Tegra / RK3588 Mali / NVIDIA 独显 / Intel/AMD 集显）。
detect_gpu() {
    if is_jetson; then
        echo "Tegra (integrated)"
        return
    fi
    if is_rk3588; then
        echo "Mali-G610"
        return
    fi
    # NVIDIA 独立 GPU
    if command -v nvidia-smi >/dev/null 2>&1; then
        local gpu
        gpu="$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)"
        [ -n "$gpu" ] && { echo "$gpu"; return; }
    fi
    # Intel / AMD 集显（lspci VGA/Display 控制器）
    if command -v lspci >/dev/null 2>&1; then
        local vga
        vga="$(lspci 2>/dev/null | grep -iE "VGA compatible controller|3D controller|Display controller" | head -1 | sed 's/^[0-9a-f:.]* //;s/.*controller: //;s/ (rev.*//')"
        [ -n "$vga" ] && { echo "$vga"; return; }
    fi
    echo ""
}

# detect_npu: NPU 型号（RK3588 NPU / Intel NPU）。
detect_npu() {
    if is_rk3588; then
        echo "RK3588 NPU"
        return
    fi
    if [ -e /dev/accel0 ] || [ -d /sys/class/accel/accel0 ] || [ -e /dev/intel_npu ]; then
        echo "Intel NPU"
        return
    fi
    echo ""
}

detect_l4t_version() {
    if [ -f /etc/nv_tegra_release ]; then
        local ver
        ver=$(head -1 /etc/nv_tegra_release | sed -n 's/.*R\([0-9]*\).*/\1/p')
        [ -n "$ver" ] && echo "$ver" || echo "none"
    else
        echo "none"
    fi
}

# l4t_to_jetpack: L4T 主版本 → JetPack 版本。
l4t_to_jetpack() {
    case "$1" in
        35) echo "JetPack 5.x" ;;
        36) echo "JetPack 6.x" ;;
        38) echo "JetPack 7.x" ;;
        *)  echo "" ;;
    esac
}

# detect_cuda_version: CUDA 版本（nvcc 或 /usr/local/cuda/version.txt）。
detect_cuda_version() {
    if command -v nvcc >/dev/null 2>&1; then
        nvcc --version 2>/dev/null | grep -m1 "release" | sed 's/.*release //;s/,.*//'
    elif [ -f /usr/local/cuda/version.txt ]; then
        sed 's/.*release //;s/,.*//' /usr/local/cuda/version.txt 2>/dev/null
    else
        echo ""
    fi
}

detect_rknn_version() {
    local lib
    lib=$(find /usr/lib /lib /vendor/lib64 /system/lib64 -name "librknnrt.so*" 2>/dev/null | head -1)
    if [ -n "$lib" ]; then
        local ver
        ver=$(basename "$lib" | sed -n 's/librknnrt\.so\.\([0-9.]*\)/\1/p')
        [ -n "$ver" ] && { echo "$ver"; return; }
        echo "found"; return
    fi
    lib=$(find /usr/lib /lib /vendor/lib64 /system/lib64 -name "librknn_api.so*" 2>/dev/null | head -1)
    if [ -n "$lib" ]; then
        local ver
        ver=$(basename "$lib" | sed -n 's/librknn_api\.so\.\([0-9.]*\)/\1/p')
        [ -n "$ver" ] && { echo "$ver"; return; }
        echo "found"; return
    fi
    echo "none"
}

detect_openvino_soname() {
    local lib
    lib=$(find /usr/lib /lib -name "libopenvino.so.2*" 2>/dev/null | head -1)
    if [ -n "$lib" ]; then
        basename "$lib" | sed -n 's/^libopenvino\.so\.\([0-9][0-9]*\)$/\1/p'
    else
        echo "none"
    fi
}

soname_to_openvino_ver() {
    case "$1" in
        2520) echo "20250200" ;;
        2540) echo "20250400" ;;
        2541) echo "20250401" ;;
        *)    echo "" ;;
    esac
}

normalize_openvino_ver() {
    local raw="$1" y m d
    y=$(echo "$raw" | sed -n 's/.*\([0-9]\{4\}\)[._].*/\1/p')
    m=$(echo "$raw" | sed -n 's/.*[0-9]\{4\}[._]\([0-9]\{1,2\}\).*/\1/p')
    d=$(echo "$raw" | sed -n 's/.*[0-9]\{4\}[._][0-9]\{1,2\}[._]\([0-9]\{1,2\}\).*/\1/p')
    if [ -n "$y" ] && [ -n "$m" ] && [ -n "$d" ]; then
        printf "%s%02d%02d" "$y" "$m" "$d"
    else
        echo ""
    fi
}

detect_openvino_version() {
    local raw=""
    raw="${INTEL_OPENVINO_VERSION:-}"

    if [ -z "$raw" ]; then
        local setupvars=""
        for candidate in /opt/intel/openvino/setupvars.sh /opt/intel/openvino_*/setupvars.sh; do
            [ -f "$candidate" ] && { setupvars="$candidate"; break; }
        done
        [ -n "$setupvars" ] && raw="$(basename "$(dirname "$setupvars")")"
    fi

    if [ -z "$raw" ] && command -v pkg-config >/dev/null 2>&1; then
        raw="$(pkg-config --modversion openvino 2>/dev/null || true)"
    fi

    if [ -z "$raw" ]; then
        soname_to_openvino_ver "$(detect_openvino_soname)"
        return
    fi

    normalize_openvino_ver "$raw"
}

is_jetson() {
    [ -f /etc/nv_tegra_release ] && return 0
    if [ -r /proc/device-tree/model ]; then
        cat /proc/device-tree/model 2>/dev/null | tr -d '\0' | grep -qiE "jetson|orin|xavier|nvidia" && return 0
    fi
    return 1
}

is_rk3588() {
    if [ -r /proc/device-tree/model ]; then
        cat /proc/device-tree/model 2>/dev/null | tr -d '\0' | grep -q "3588" && return 0
    fi
    [ -e /dev/rknpu ] && return 0
    return 1
}

# is_rockchip: Rockchip 平台（RK3588 以外的型号，如 RK3566/RK3399——无 NPU 加速包）
is_rockchip() {
    if [ -r /proc/device-tree/model ]; then
        cat /proc/device-tree/model 2>/dev/null | tr -d '\0' | grep -qi "rockchip" && return 0
    fi
    return 1
}

# detect_glibc: 主机 glibc 版本（deb 最低要求 2.29，即 Ubuntu 20.04+）
detect_glibc() {
    local out ver
    out="$(ldd --version 2>/dev/null || true)"
    out="${out%%$'\n'*}"
    ver="$(grep -o '[0-9][0-9.]*$' <<< "$out" || true)"
    [ -n "$ver" ] && echo "$ver" || echo "0"
}

# is_android: Android 系统（deb 包不适用，应走 HMS 部署流程）
is_android() {
    [ -e /system/build.prop ] || command -v getprop >/dev/null 2>&1
}

# has_intel_igpu: 是否有 Intel 核显（OpenVINO GPU 加速的前提）
has_intel_igpu() {
    local out
    command -v lspci >/dev/null 2>&1 || return 1
    out="$(lspci 2>/dev/null || true)"
    grep -qiE "VGA compatible controller.*Intel|Display controller.*Intel" <<< "$out"
}

is_intel() {
    grep -m1 "vendor_id" /proc/cpuinfo 2>/dev/null | grep -q "GenuineIntel"
}

# ============================================================================
# 主流程
# ============================================================================
main() {
    local arch model cpu_vendor cpu_model
    arch="$(detect_arch)"
    model="$(detect_hardware)"
    cpu_vendor="$(detect_cpu_vendor)"
    cpu_model="$(detect_cpu_model)"

    local is_j=false is_rk=false is_in=false
    if is_jetson;  then is_j=true; fi
    if is_rk3588;  then is_rk=true; fi
    if is_intel;   then is_in=true; fi

    # 推荐 + 可用 + 显示列表（动态构建，只保留当前机器适用的版本）
    local recommended="" available=""
    local display=() unsupported=()
    local l4t rknn_ver

    # ── 平台 → 推荐 slug / 不支持原因 ──
    if is_android; then
        unsupported+=("Android 系统：deb 安装包不适用（请走 HMS 部署流程）")
    elif $is_j; then
        l4t="$(detect_l4t_version)"
        display+=("manifold-lc-sdk-arm64")
        available="manifold-lc-sdk-arm64"
        # 按服务器实际 slug 映射（其下托管的是 dist/1028 的 ONNX bundle 包）：
        #   jetpack515 → manifold-lc-sdk-arm64-jetpack5-nx_ubuntu20...-bundle.deb
        #   jetpack621 → manifold-lc-sdk-arm64-jetpack6-agx_ubuntu22...-bundle.deb
        #   jetpack7   → manifold-lc-sdk-arm64-jetpack7-thor_ubuntu24...-bundle.deb
        case "$l4t" in
            35) recommended="manifold-lc-sdk-arm64-jetpack515" ;;
            36) recommended="manifold-lc-sdk-arm64-jetpack621" ;;
            38) recommended="manifold-lc-sdk-arm64-jetpack7" ;;
            *)  recommended="manifold-lc-sdk-arm64"
                unsupported+=("JetPack 加速包：L4T R${l4t} 无对应版本（仅 CPU 版可用）")
                ;;
        esac
        [ "$recommended" = "manifold-lc-sdk-arm64" ] || display+=("$recommended")
    elif $is_rk; then
        rknn_ver="$(detect_rknn_version)"
        display+=("manifold-lc-sdk-arm64")
        available="manifold-lc-sdk-arm64"
        if [ "$rknn_ver" != "none" ]; then
            recommended="manifold-lc-sdk-arm64-3588npu"
            display+=("$recommended")
        else
            recommended="manifold-lc-sdk-arm64"
        fi
    elif is_rockchip; then
        # RK3588 以外的 Rockchip（RK3566/RK3399 等）：无 NPU 加速包
        display+=("manifold-lc-sdk-arm64")
        available="manifold-lc-sdk-arm64"
        recommended="manifold-lc-sdk-arm64"
        unsupported+=("该 Rockchip 型号无 NPU 加速包（仅 CPU 版可用）")
    elif [ "$arch" = "amd64" ]; then
        display+=("manifold-lc-sdk-amd64")
        available="manifold-lc-sdk-amd64"
        if $is_in; then
            if has_intel_igpu; then
                # 按服务器实际 slug：openvino20250401 项目当前托管的是
                # manifold-lc-sdk-amd64-openvino20250200_2.1.0.deb（自包含 runtime，Ubuntu 20/22/24 通用）
                recommended="manifold-lc-sdk-amd64-openvino20250401"
                display+=("$recommended")
            else
                recommended="manifold-lc-sdk-amd64"
                unsupported+=("无 Intel 核显：OpenVINO 加速不可用（仅 CPU 版）")
            fi
        else
            recommended="manifold-lc-sdk-amd64"
            unsupported+=("非 Intel CPU：OpenVINO 加速包不支持（仅 CPU 版可用）")
        fi
        if [ "$recommended" = "manifold-lc-sdk-amd64" ] && command -v nvidia-smi >/dev/null 2>&1; then
            unsupported+=("NVIDIA 独显：x86 无专用加速包（仅 CPU 版可用）")
        fi
    elif [ "$arch" = "arm64" ]; then
        display+=("manifold-lc-sdk-arm64")
        available="manifold-lc-sdk-arm64"
        recommended="manifold-lc-sdk-arm64"
    else
        unsupported+=("未知架构: $(uname -m)")
    fi

    # ── glibc 基线：deb 最低要求 glibc 2.29（Ubuntu 20.04+）──
    local glibc_ver
    glibc_ver="$(detect_glibc)"
    if [ -n "$recommended" ] && [ "$(printf '2.29\n%s\n' "$glibc_ver" | sort -V | head -1)" != "2.29" ]; then
        unsupported+=("系统 glibc ${glibc_ver} 过低（deb 需 Ubuntu 20.04+ / glibc ≥ 2.29）")
        recommended=""
    fi

    # ---- 采集检测明细（有则显示） ----
    local gpu npu cuda_ver jetpack l4t rknn_ver ov_ver
    gpu="$(detect_gpu)"
    npu="$(detect_npu)"
    cuda_ver="$(detect_cuda_version)"
    l4t="$(detect_l4t_version)"
    rknn_ver="$(detect_rknn_version)"
    ov_ver="$(detect_openvino_version)"
    jetpack="$(l4t_to_jetpack "$l4t")"

    # ---- Output ----
    echo ""
    echo "========================================"
    echo "  Manifold LC SDK - Platform Detection"
    echo "========================================"
    echo ""
    echo "[Detection]"

    local hw_label="$model"
    { [ -z "$hw_label" ] || [ "$hw_label" = "unknown" ]; } && hw_label="$cpu_vendor $arch"
    printf '  %-10s: %s\n' "Hardware" "$hw_label"
    printf '  %-10s: %s (%s)\n' "CPU" "$cpu_model" "$arch"

    # 统一输出所有检测到的项（不区分平台，有值就显示）
    [ -n "$gpu" ] && printf '  %-10s: %s\n' "GPU" "$gpu"
    [ -n "$npu" ] && printf '  %-10s: %s\n' "NPU" "$npu"
    [ "$l4t" != "none" ] && printf '  %-10s: R%s (%s)\n' "L4T" "$l4t" "${jetpack:-unknown}"
    [ -n "$cuda_ver" ] && printf '  %-10s: %s\n' "CUDA" "$cuda_ver"
    [ "$rknn_ver" != "none" ] && printf '  %-10s: %s\n' "RKNN" "$rknn_ver"
    [ -n "$ov_ver" ] && printf '  %-10s: %s\n' "OpenVINO" "$ov_ver"

    echo ""
    echo "[Support]"
    if [ -n "$recommended" ]; then
        printf '  %-14s: %s\n' "Recommended" "$recommended"
    else
        printf '  %-14s: %s\n' "Recommended" "NONE（无可用 SDK 包）"
    fi
    local reason
    for reason in "${unsupported[@]}"; do
        printf '  %-14s: %s\n' "Not supported" "$reason"
    done

    echo ""
    echo "[Download links]"

    if [ -z "$recommended" ]; then
        echo "  (无适用下载链接 — 见上方 [Support])"
    else
        local slug
        for slug in "${display[@]}"; do
            if [ "$slug" = "$recommended" ]; then
                printf '  \342\227\217 %s   RECOMMENDED\n' "$slug"
            elif [ "$slug" = "$available" ]; then
                printf '  \342\227\213 %s   AVAILABLE\n' "$slug"
            else
                printf '    %s\n' "$slug"
            fi
            echo "      ${WEB_BASE}/download/${slug}"
        done
    fi

    echo "========================================"
    echo ""
}

main
