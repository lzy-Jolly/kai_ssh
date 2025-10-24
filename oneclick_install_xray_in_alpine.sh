#!/bin/bash
# ======================================================================
# Xray Alpine One-Click Install Script (Integrated Status Check + Reality)
# ======================================================================

# ---------------------------- Step 0: Set Variables ----------------------------
readonly xray_binary_path="/usr/local/bin/xray"
red="\033[31m"
green="\033[32m"
yellow="\033[33m"
cyan="\033[36m"
none="\033[0m"

# 获取当前目录最后一级
current_dir=$(basename "$PWD")

# 如果不是 latters，就创建并进入
if [[ "$current_dir" != "latters" ]]; then
    mkdir -p latters
    cd latters || exit 1
fi


REALITY_SCRIPT="./alpine_xray_reality.sh"
REALITY_URL="https://raw.githubusercontent.com/lzy-Jolly/kai_ssh/refs/heads/main/alpine_xray_reality.sh"

# ----------------- Step 0.5: Check Xray Status and jump to other-----------------------
if [[ -f "$xray_binary_path" ]]; then
    xray_version=$($xray_binary_path version 2>/dev/null | head -n 1 | awk '{print $2}' || echo "未知")
    if rc-service xray status &>/dev/null; then
        service_status="${green}运行中${none}"
    else
        service_status="${yellow}未运行${none}"
    fi
    echo -e "Xray 状态: ${green}已安装${none} | ${service_status} | 版本: ${cyan}${xray_version}${none}"

    # 检查是否有本地 Reality 脚本
    if [[ -f "$REALITY_SCRIPT" ]]; then
        echo "Found $REALITY_SCRIPT, executing..."
        bash "$REALITY_SCRIPT"
        exit 0
    else
        echo "Downloading $REALITY_SCRIPT..."
        curl -O -L "$REALITY_URL"
        chmod +x "$REALITY_SCRIPT"
        bash "$REALITY_SCRIPT"
        exit 0
    fi
else
    echo -e "Xray 状态: ${red}未安装${none}"
fi

# ---------------------------- Step 1: Ensure curl ----------------------------
echo "Checking curl..."
if ! command -v curl >/dev/null 2>&1; then
    echo "curl not found, installing..."
    apk update
    apk add --no-cache curl
    if [ $? -ne 0 ]; then
        echo "curl installation failed. Check network or APK source."
        exit 1
    fi
else
    echo "curl is already installed."
fi

# ---------------------------- Step 2: Download Xray Install Script ----------------------------
XRAY_SCRIPT="install-release.sh"
XRAY_URL="https://github.com/XTLS/Xray-install/raw/main/alpinelinux/install-release.sh"

echo "Downloading Xray install script..."
curl -O -L "$XRAY_URL"
if [ $? -ne 0 ]; then
    echo "Download failed. Check network."
    exit 1
fi
chmod +x "$XRAY_SCRIPT"
echo "Download completed and executable set."

# ---------------------------- Step 3: Run Xray Install Script ----------------------------
echo "Running Xray install script..."
ash "$XRAY_SCRIPT"
if [ $? -ne 0 ]; then
    echo "Xray installation failed."
    exit 1
fi

echo "Xray installation completed successfully."

echo "start running --------alpine_xray_reality.sh "
# 检查是否有本地 Reality 脚本
    if [[ -f "$REALITY_SCRIPT" ]]; then
        echo "Found $REALITY_SCRIPT, executing alpine_xray_reality.sh"
        # bash "$REALITY_SCRIPT"
        exit 0
    else
        echo "Downloading $REALITY_SCRIPT..."
        curl -O -L "$REALITY_URL"
        chmod +x "$REALITY_SCRIPT"
        # bash "$REALITY_SCRIPT"
        exit 0
    fi
echo "重新进入请执行 ./alpine_xray_reality.sh"
