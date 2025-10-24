#!/bin/bash
# ======================================================================
# Xray One-Click Install Script (Alpine/Debian/Ubuntu Auto)
# ======================================================================

# ---------------------------- Step 0: Set Variables ----------------------------
readonly xray_binary_path="/usr/local/bin/xray"
red="\033[31m"
green="\033[32m"
yellow="\033[33m"
cyan="\033[36m"
none="\033[0m"


#---------------------------- Step 0: Prepare Directory ----------------------------
# 获取当前目录最后一级
current_dir=$(basename "$PWD")

# 如果不是 latters，就创建并进入
if [[ "$current_dir" != "latters" ]]; then
    mkdir -p latters
    cd latters || exit 1
fi

# ---------------------------- Step 0.1: Detect OS ----------------------------
OS_TYPE=$(awk -F= '/^ID=/{print $2}' /etc/os-release 2>/dev/null || echo "unknown")
echo -e "${cyan}Detected OS: ${OS_TYPE}${none}"

# ---------------------------- Step 0.2: Determine Reality Script ----------------------------
if [[ "$OS_TYPE" == "alpine" ]]; then
    # Alpine 专用
    echo -e " OS type is ${yellow}alpine${none}, using alpine_xray_reality.sh"
    REALITY_SCRIPT="./alpine_xray_reality.sh"
    REALITY_URL="https://raw.githubusercontent.com/lzy-Jolly/kai_ssh/refs/heads/main/alpine_xray_reality.sh"
else
    # Debian/Ubuntu/其他 - 直接执行对应脚本
    echo -e " OS type is ${yellow}${OS_TYPE}${none}, for Debian/Ubuntu is ok others not sure."
    REALITY_SCRIPT="./axray_vless_reality_.sh"
    REALITY_URL="https://raw.githubusercontent.com/lzy-Jolly/kai_ssh/refs/heads/main/axray_vless_reality_.sh"
    
    # 下载并执行 Debian/Ubuntu 脚本
    if [[ ! -f "$REALITY_SCRIPT" ]]; then
        curl -O -L "$REALITY_URL"
    fi
    chmod +x "$REALITY_SCRIPT"
    echo "Run script by ./$REALITY_SCRIPT "
    bash "$REALITY_SCRIPT"
    exit 0
fi

# ---------------------------- Step 1: Check Xray Status (Alpine only) ----------------------------
if command -v xray >/dev/null 2>&1; then
    # 获取版本号，直接用 xray 命令
    xray_version=$(xray version 2>/dev/null | awk 'NR==1{print $2}' || echo "未知")

    # 获取服务状态
    if command -v rc-service >/dev/null 2>&1 && rc-service xray status &>/dev/null; then
        service_status="${green}运行中${none}"
    elif command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet xray; then
        service_status="${green}运行中${none}"
    else
        service_status="${yellow}未运行${none}"
    fi

    echo -e "Xray 状态: ${green}已安装${none} | ${service_status} | 版本: ${cyan}${xray_version}${none}"

    # 检查并执行 Reality 脚本
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
    # Xray 未安装
    echo -e "Xray 状态: ${red}未安装${none}"       
    
fi

# ---------------------------- Step 2: Ensure curl (Alpine only) ----------------------------
echo "Alpine system: check dependencies and install Xray."
if ! command -v curl >/dev/null 2>&1; then
    apk update
    apk add --no-cache curl
    if [ $? -ne 0 ]; then
        echo "curl installation failed. Check network or APK source."
        exit 1
    fi
fi
# ---------------------------- Step 3: Download and Install Xray (Alpine only) ----------------------------
XRAY_SCRIPT="install-release.sh"
XRAY_URL="https://github.com/XTLS/Xray-install/raw/main/alpinelinux/install-release.sh"
echo "Downloading Xray install script..."
curl -O -L "$XRAY_URL"
chmod +x "$XRAY_SCRIPT"
echo "Running Xray install script..."
ash "$XRAY_SCRIPT"

# ---------------------------- Step 4: Execute Reality Script (Alpine only) ----------------------------
if [[ -f "$REALITY_SCRIPT" ]]; then
    echo "Executing $REALITY_SCRIPT..."
    bash "$REALITY_SCRIPT"
else
    echo "Downloading $REALITY_SCRIPT..."
    curl -O -L "$REALITY_URL"
    chmod +x "$REALITY_SCRIPT"
    bash "$REALITY_SCRIPT"
fi

echo "Run script by ./$REALITY_SCRIPT "
