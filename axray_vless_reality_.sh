#!/bin/bash
# this is axray_vless_reality_.sh
# ==============================================================================
# Xray VLESS-Reality 一键安装管理脚本
# 版本: V-Final-2.1
# 更新日志 (V-Final-2.1):
# - [改进] 增强端口占用检查
# - [改进] 增强UUID格式验证
# - [改进] 改进系统兼容性检查
# ==============================================================================

# --- Shell 严格模式 ---
set -euo pipefail

# --- 全局常量 ---
readonly SCRIPT_VERSION="V-Final-2.1"
readonly xray_config_path="/usr/local/etc/xray/config.json"
readonly xray_binary_path="/usr/local/bin/xray"
readonly xray_install_script_url="https://github.com/XTLS/Xray-install/raw/main/install-release.sh"

# --- 颜色定义 ---
readonly red='\e[91m' green='\e[92m' yellow='\e[93m'
readonly magenta='\e[95m' cyan='\e[96m' none='\e[0m'

# --- 全局变量 ---
xray_status_info=""
is_quiet=false

# --- 辅助函数 ---
error() { echo -e "\n$red[✖] $1$none\n" >&2; }
info() { [[ "$is_quiet" = false ]] && echo -e "\n$yellow[!] $1$none\n"; }
success() { [[ "$is_quiet" = false ]] && echo -e "\n$green[✔] $1$none\n"; }

spinner() {
    local pid=$1; local spinstr='|/-\'
    if [[ "$is_quiet" = true ]]; then
        wait "$pid"
        return
    fi
    while ps -p "$pid" > /dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep 0.1
        printf "\r"
    done
    printf "    \r"
}

get_public_ip() {
    local ip
    for cmd in "curl -4s --max-time 5" "wget -4qO- --timeout=5"; do
        for url in "https://api.ipify.org" "https://ip.sb" "https://checkip.amazonaws.com"; do
            ip=$($cmd "$url" 2>/dev/null) && [[ -n "$ip" ]] && echo "$ip" && return
        done
    done
    for cmd in "curl -6s --max-time 5" "wget -6qO- --timeout=5"; do
        for url in "https://api64.ipify.org" "https://ip.sb"; do
            ip=$($cmd "$url" 2>/dev/null) && [[ -n "$ip" ]] && echo "$ip" && return
        done
    done
    error "无法获取公网 IP 地址。" && return 1
}

execute_official_script() {
    local args="$1"
    local script_content
    script_content=$(curl -L "$xray_install_script_url")
    if [[ -z "$script_content" ]]; then
        error "下载 Xray 官方安装脚本失败！请检查网络连接。"
        return 1
    fi
    bash -c "$script_content" @ $args &> /dev/null &
    spinner $!
    if ! wait $!; then
        return 1
    fi
}

# --- 改进的验证函数 ---
is_valid_port() {
    local port=$1
    [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]
}

# 新增：检查端口是否被占用
is_port_in_use() {
    local port=$1
    # 使用多种方法检查端口占用
    if command -v ss &>/dev/null; then
        ss -tuln 2>/dev/null | grep -q ":$port "
    elif command -v netstat &>/dev/null; then
        netstat -tuln 2>/dev/null | grep -q ":$port "
    elif command -v lsof &>/dev/null; then
        lsof -i ":$port" &>/dev/null
    else
        # 如果没有可用工具，尝试连接测试
        timeout 1 bash -c "</dev/tcp/127.0.0.1/$port" 2>/dev/null
    fi
}

# 增强的UUID验证函数
is_valid_uuid() {
    local uuid=$1
    # 标准UUID格式验证：8-4-4-4-12 位十六进制数字
    [[ "$uuid" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]
}

is_valid_domain() {
    local domain=$1
    [[ "$domain" =~ ^[a-zA-Z0-9-]{1,63}(\.[a-zA-Z0-9-]{1,63})+$ ]] && [[ "$domain" != *--* ]]
}

# --- 改进的系统兼容性检查 ---
check_system_compatibility() {
    local os_release_file="/etc/os-release"
    local debian_version_file="/etc/debian_version"
    local lsb_release_file="/etc/lsb-release"
    
    # 检查是否为Linux系统
    if [[ "$(uname -s)" != "Linux" ]]; then
        error "错误: 此脚本仅支持 Linux 系统。"
        return 1
    fi
    
    # 支持的发行版列表
    local supported_distros=("ubuntu" "debian" "kali" "raspbian" "deepin" "mint" "elementary")
    local distro_detected=false
    local distro_name=""
    local distro_version=""
    
    # 方法1: 检查 /etc/os-release (最标准的方法)
    if [[ -f "$os_release_file" ]]; then
        source "$os_release_file"
        distro_name=$(echo "$ID" | tr '[:upper:]' '[:lower:]')
        distro_version="$VERSION_ID"
        
        # 检查是否为支持的发行版
        for supported in "${supported_distros[@]}"; do
            if [[ "$distro_name" == "$supported" ]]; then
                distro_detected=true
                break
            fi
        done
        
        # 检查基于Debian的发行版
        if [[ "$distro_detected" == false && "$ID_LIKE" =~ debian|ubuntu ]]; then
            distro_detected=true
            distro_name="$ID_LIKE"
        fi
    fi
    
    # 方法2: 检查 /etc/debian_version (Debian系特有)
    if [[ "$distro_detected" == false && -f "$debian_version_file" ]]; then
        distro_detected=true
        distro_name="debian-based"
        distro_version=$(cat "$debian_version_file" 2>/dev/null || echo "unknown")
    fi
    
    # 方法3: 检查 /etc/lsb-release (备用方法)
    if [[ "$distro_detected" == false && -f "$lsb_release_file" ]]; then
        source "$lsb_release_file"
        local lsb_id=$(echo "$DISTRIB_ID" | tr '[:upper:]' '[:lower:]')
        for supported in "${supported_distros[@]}"; do
            if [[ "$lsb_id" == "$supported" ]]; then
                distro_detected=true
                distro_name="$lsb_id"
                distro_version="$DISTRIB_RELEASE"
                break
            fi
        done
    fi
    
    # 方法4: 检查包管理器 (最后的检查)
    if [[ "$distro_detected" == false ]]; then
        if command -v apt &>/dev/null && command -v dpkg &>/dev/null; then
            distro_detected=true
            distro_name="debian-compatible"
            info "检测到基于APT的包管理系统，假定为Debian兼容系统。"
        fi
    fi
    
    if [[ "$distro_detected" == false ]]; then
        error "错误: 未检测到支持的Linux发行版。"
        error "支持的系统: Ubuntu, Debian, Kali Linux, Raspbian, Deepin, Linux Mint, elementary OS"
        error "当前系统信息: $(uname -a)"
        return 1
    fi
    
    # 输出检测结果
    if [[ "$is_quiet" == false ]]; then
        info "系统兼容性检查通过"
        info "检测到系统: ${distro_name} ${distro_version}"
    fi
    
    # 检查关键命令是否存在
    local required_commands=("systemctl" "awk" "grep" "sed")
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        error "错误: 缺少必要的系统命令: ${missing_commands[*]}"
        error "请确保系统完整安装后再运行此脚本。"
        return 1
    fi
    
    return 0
}

# 从 portslist.txt 中选择未被占用的端口对，可选匹配当前端口
choose_port_pair() {
    current_port="${1:-}"   # 可选参数，不传则为空
    list_file="./portslist.txt"
    [ ! -f "$list_file" ] && return 1
    
    # edit Windows \n \r diff with linux
    sed -i 's/\r$//' "$list_file"
    
    
    pairs=""
    count=0
    invalid=0
    matched_inner=""
    matched_outer=""

    while IFS=, read -r inner outer; do
        [ "$inner" = "inner" ] && continue

        # 检查是否为数字且在范围内
        case "$inner" in ''|*[!0-9]*) invalid=$((invalid+1)); continue ;; esac
        case "$outer" in ''|*[!0-9]*) invalid=$((invalid+1)); continue ;; esac
        if [ "$inner" -lt 1024 ] || [ "$inner" -gt 65535 ] || \
           [ "$outer" -lt 1024 ] || [ "$outer" -gt 65535 ]; then
            invalid=$((invalid+1))
            continue
        fi

        # 收集未占用端口对
        if ! is_port_in_use "$inner"; then
            pairs="${pairs}${inner},${outer}\n"
            count=$((count+1))
        fi

        # 匹配当前端口
        if [ -n "$current_port" ] && { [ "$inner" -eq "$current_port" ] || [ "$outer" -eq "$current_port" ]; }; then
            matched_inner="$inner"
            matched_outer="$outer"
        fi
    done < "$list_file"

    [ "$invalid" -gt 0 ] && echo -e "有${red}${invalid}${none}对格式错误端口被忽略。"

    # 匹配到当前端口
    if [ -n "$matched_inner" ] && [ -n "$matched_outer" ]; then
        rand_inner="$matched_inner"
        rand_outer="$matched_outer"
        default_port="$rand_inner"
        echo -e "匹配到当前端口配对，使用-->inner=${green}${rand_inner}${none}, outer=${green}${rand_outer}${none}"
        export rand_inner rand_outer default_port
        return 0
    fi

    # 随机选择未占用端口对
    if [ "$count" -eq 0 ]; then
        echo "未找到可用端口对，退回原有随机逻辑"
        return 1
    fi

    rand_line=$((RANDOM % count + 1))
    selected=$(echo -e "$pairs" | sed -n "${rand_line}p")
    rand_inner="${selected%,*}"
    rand_outer="${selected#*,}"
    default_port="$rand_inner"

    if [ -n "$current_port" ]; then
        echo -e "检测到 $count 对端口，随机选得默认为-->inner=${rand_inner}, outer=${rand_outer} (未匹配当前端口)"
    else
        echo -e "检测到 $count 对端口，随机选得默认为-->inner=${rand_inner}, outer=${rand_outer}"
    fi

    export rand_inner rand_outer default_port
}

# --- 预检查与环境设置 ---
pre_check() {
    [[ $(id -u) != 0 ]] && error "错误: 您必须以root用户身份运行此脚本" && exit 1
    
    # 使用改进的系统兼容性检查
    if ! check_system_compatibility; then
        exit 1
    fi

    if ! command -v jq &>/dev/null || ! command -v curl &>/dev/null; then
        info "检测到缺失的依赖 (jq/curl)，正在尝试自动安装..."
        (DEBIAN_FRONTEND=noninteractive apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y jq curl) &> /dev/null &
        spinner $!
        if ! command -v jq &>/dev/null || ! command -v curl &>/dev/null; then
            error "依赖 (jq/curl) 自动安装失败。请手动运行 'apt update && apt install -y jq curl' 后重试。"
            exit 1
        fi
        success "依赖已成功安装。"
    fi
}

check_xray_status() {
    if [[ ! -f "$xray_binary_path" ]]; then xray_status_info="  Xray 状态: ${red}未安装${none}"; return; fi
    local xray_version=$($xray_binary_path version 2>/dev/null | head -n 1 | awk '{print $2}' || echo "未知")
    local service_status
    if systemctl is-active --quiet xray 2>/dev/null; then service_status="${green}运行中${none}"; else service_status="${yellow}未运行${none}"; fi
    xray_status_info="  Xray 状态: ${green}已安装${none} | ${service_status} | 版本: ${cyan}${xray_version}${none}"
}

# --- 菜单功能函数 ---#

install_xray() {
    if [[ -f "$xray_binary_path" ]]; then
        info "检测到 Xray 已安装。继续操作将覆盖现有配置。"
        read -p "是否继续？[Y/n]: " confirm
        confirm=${confirm:-Y}
        if [[ ! $confirm =~ ^[yY]$ ]]; then info "操作已取消。"; return; fi
    fi
    
    info "开始配置 Xray..."
    local port uuid domain default_port rand_inner rand_outer
    
    # ------------随机默认端口--(更新: 支持 portslist.txt)------
    while true; do
        
        default_port="" # 确保每次循环重置
        
        # 尝试从 portslist.txt 中选择端口对。如果成功，rand_inner, rand_outer, default_port会被设置。
        choose_port_pair
        
        if [ -z "$default_port" ]; then
            # 如果 choose_port_pair 失败 (文件不存在或未找到可用端口对)，则使用原始随机逻辑
        while true; do
            default_port=$((RANDOM % (65535 - 25000 + 1) + 25000))
            if ! is_port_in_use "$default_port"; then
                    # 确保在未用 portslist 时，内部/外部端口也一致
                    rand_inner="$default_port"
                    rand_outer="$default_port"
                    info "未从 portslist.txt 中获取到可用端口，使用随机端口: ${cyan}${default_port}${none}"
                break
            fi
            
            # 如果被占用，循环继续，重新选择/生成端口。
        done
        fi
    
        # 提示用户输入端口
        read -p "$(echo -e "请输入端口 [1-65535] (默认: ${cyan}${default_port}${none}): ")" port
        [ -z "$port" ] && port=$default_port
    
        if ! is_valid_port "$port"; then
            error "端口无效，请输入一个1-65535之间的数字。"
            continue
        fi
        # 注意: choose_port_pair 已经保证其选出的 default_port 未被占用。
        # 这里仅需检查用户自定义输入的 $port 是否被占用。
        if [[ "$port" != "$default_port" ]] && is_port_in_use "$port"; then
            error "端口 $port 已被占用，请选择其他端口。"
            continue
        fi
        
        # 如果用户输入了自定义端口，则将 rand_inner/outer 设定为该值，确保后续配置使用该端口
        if [[ "$port" != "$default_port" ]]; then
            rand_inner="$port"
            rand_outer="$port"
        fi
        
        break
    done
    


    while true; do
        read -p "$(echo -e "请输入UUID (留空将默认生成随机UUID): ")" uuid
        if [[ -z "$uuid" ]]; then 
            uuid=$(cat /proc/sys/kernel/random/uuid)
            info "已为您生成随机UUID: ${cyan}${uuid}${none}"
            break
        elif is_valid_uuid "$uuid"; then
            break
        else
            error "UUID格式无效，请输入标准UUID格式 (如: 550e8400-e29b-41d4-a716-446655440000) 或留空自动生成。"
        fi
    done
        
    while true; do
        # 修改加入测试sni，返回top5供手选
        execute_sni_test || { error "SNI 测试失败，请检查网络"; continue; }
        read -p "$(echo -e "请输入SNI域名 (默认: ${cyan}learn.microsoft.com${none}): ")" domain
        [ -z "$domain" ] && domain="learn.microsoft.com"
        if is_valid_domain "$domain"; then break; else error "域名格式无效，请重新输入。"; fi
    done

    run_install "$port" "$uuid" "$domain"
}




# 检查选择合适的sni 
execute_sni_test() {
    local sni_script_url="https://raw.githubusercontent.com/lzy-Jolly/kai_ssh/refs/heads/main/test.sni.sh"
    local local_script="./test.sni.sh"

    # 如果本地不存在或者远程有更新，则下载覆盖
    if [[ ! -f "$local_script" ]]; then
        info "正在下载 test.sni.sh 脚本..."
        curl -fsSL "$sni_script_url" -o "$local_script" || { error "下载失败！"; return 1; }
        chmod +x "$local_script"
    else
        # 检查更新（可选）
        local remote_hash=$(curl -fsSL "$sni_script_url" | sha256sum | awk '{print $1}')
        local local_hash=$(sha256sum "$local_script" | awk '{print $1}')
        if [[ "$remote_hash" != "$local_hash" ]]; then
            info "检测到 test.sni.sh 有更新，正在下载..."
            curl -fsSL "$sni_script_url" -o "$local_script" || { error "更新失败！"; return 1; }
            chmod +x "$local_script"
        fi
    fi

    # 执行脚本
    info "正在执行 test.sni.sh 脚本..."
    "$local_script"
    return $?
}


update_xray() {
    if [[ ! -f "$xray_binary_path" ]]; then error "错误: Xray 未安装，无法执行更新。请先选择安装选项。" && return; fi
    info "正在检查最新版本..."
    local current_version=$($xray_binary_path version | head -n 1 | awk '{print $2}')
    local latest_version=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | jq -r '.tag_name' | sed 's/v//' || echo "")
    if [[ -z "$latest_version" ]]; then error "获取最新版本号失败，请检查网络或稍后再试。" && return; fi
    info "当前版本: ${cyan}${current_version}${none}，最新版本: ${cyan}${latest_version}${none}"
    if [[ "$current_version" == "$latest_version" ]]; then success "您的 Xray 已是最新版本，无需更新。" && return; fi
    
    info "发现新版本，开始更新..."
    if ! execute_official_script "install"; then error "Xray 核心更新失败！" && return; fi
    info "正在更新 GeoIP 和 GeoSite 数据文件..."
    execute_official_script "install-geodata"

    if ! restart_xray; then return; fi
    success "Xray 更新成功！"
}

restart_xray() {
    if [[ ! -f "$xray_binary_path" ]]; then error "错误: Xray 未安装，无法重启。" && return 1; fi
    info "正在重启 Xray 服务..."
    if ! systemctl restart xray; then
        error "错误: Xray 服务重启失败, 请使用菜单 5 查看日志检查具体原因。"
        return 1
    fi
    sleep 1
    if ! systemctl is-active --quiet xray; then
        error "错误: Xray 服务启动失败, 请使用菜单 5 查看日志检查具体原因。"
        return 1
    fi
    success "Xray 服务已成功重启！"
}

uninstall_xray() {
    if [[ ! -f "$xray_binary_path" ]]; then error "错误: Xray 未安装，无需卸载。" && return; fi
    read -p "您确定要卸载 Xray 吗？这将删除所有相关文件。[Y/n]: " confirm
    if [[ "$confirm" =~ ^[nN]$ ]]; then
        info "卸载操作已取消。"
        return
    fi
    info "正在卸载 Xray..."
    if execute_official_script "remove --purge"; then
        rm -f ./xray_vless_reality_link.txt
        success "Xray 已成功卸载。"
    else
        error "Xray 卸载失败！"
        return 1
    fi
}

view_xray_log() {
    if [[ ! -f "$xray_binary_path" ]]; then error "错误: Xray 未安装，无法查看日志。" && return; fi
    info "正在显示 Xray 实时日志... 按 Ctrl+C 退出。"
    journalctl -u xray -f --no-pager
}

modify_config() {
    if [[ ! -f "$xray_config_path" ]]; then error "错误: Xray 未安装，无法修改配置。" && return; fi
    info "读取当前配置..."
    local current_port=$(jq -r '.inbounds[0].port' "$xray_config_path")
    local current_uuid=$(jq -r '.inbounds[0].settings.clients[0].id' "$xray_config_path")
    local current_domain=$(jq -r '.inbounds[0].streamSettings.realitySettings.serverNames[0]' "$xray_config_path")
    local private_key=$(jq -r '.inbounds[0].streamSettings.realitySettings.privateKey' "$xray_config_path")
    local public_key=$(jq -r '.inbounds[0].streamSettings.realitySettings.publicKey' "$xray_config_path")
    
    # 尝试匹配当前端口，如果成功，rand_inner/outer 会被设置
    # 这对于后续修改配置如果需要用到 outer 端口时非常关键。
    local rand_inner="$current_port"
    local rand_outer="$current_port"
    choose_port_pair "$current_port" # 传入当前端口进行匹配
    if [ "$?" -eq 0 ]; then
        # 成功匹配到端口对，rand_inner 和 rand_outer 已经被 choose_port_pair 导出并设置。
        info "当前端口 ${current_port} 在 portslist.txt 中匹配到的端口对是 inner=${rand_inner}, outer=${rand_outer}"
        # 此时 current_port 应该等于 rand_inner，这里只是为了确认
    fi

    info "请输入新配置，直接回车则保留当前值。"
    local port uuid domain
    
    while true; do
        read -p "$(echo -e "端口 (当前: ${cyan}${current_port}${none}): ")" port
        [ -z "$port" ] && port=$current_port
        
        if ! is_valid_port "$port"; then
            error "端口无效，请输入一个1-65535之间的数字。"
            continue
        fi
        
        # 如果端口没有变化，跳过占用检查
        if [[ "$port" != "$current_port" ]] && is_port_in_use "$port"; then
            error "端口 $port 已被占用，请选择其他端口。"
            continue
        fi
        
        # 如果用户输入了自定义端口，则更新 rand_inner/outer 确保写入配置时使用正确值
        if [[ "$port" != "$current_port" ]]; then
            rand_inner="$port"
            rand_outer="$port"
        fi
        
        break
    done
    
    while true; do
        read -p "$(echo -e "UUID (当前: ${cyan}${current_uuid}${none}): ")" uuid
        [ -z "$uuid" ] && uuid=$current_uuid
        if is_valid_uuid "$uuid"; then
            break
        else
            error "UUID格式无效，请输入标准UUID格式。"
        fi
    done
    
    while true; do
        read -p "$(echo -e "SNI域名 (当前: ${cyan}${current_domain}${none}): ")" domain
        [ -z "$domain" ] && domain=$current_domain
        if is_valid_domain "$domain"; then break; else error "域名格式无效，请重新输入。"; fi
    done

    write_config "$port" "$uuid" "$domain" "$private_key" "$public_key"
    
    if ! restart_xray; then return; fi

    success "配置修改成功！"
    view_subscription_info
}

view_subscription_info() {
    if [ ! -f "$xray_config_path" ]; then error "错误: 配置文件不存在, 请先安装。" && return; fi
    
    local ip
    if ! ip=$(get_public_ip); then return 1; fi

    local uuid=$(jq -r '.inbounds[0].settings.clients[0].id' "$xray_config_path")
    local port=$(jq -r '.inbounds[0].port' "$xray_config_path")
    local domain=$(jq -r '.inbounds[0].streamSettings.realitySettings.serverNames[0]' "$xray_config_path")
    local public_key=$(jq -r '.inbounds[0].streamSettings.realitySettings.publicKey' "$xray_config_path")
    local shortid=$(jq -r '.inbounds[0].streamSettings.realitySettings.shortIds[0]' "$xray_config_path")
    if [[ -z "$public_key" ]]; then error "配置文件中缺少公钥信息,可能是旧版配置,请重新安装以修复。" && return; fi

    local display_ip=$ip && [[ $ip =~ ":" ]] && display_ip="[$ip]"
    local link_name="$(hostname) X-reality"
    local link_name_encoded=$(echo "$link_name" | sed 's/ /%20/g')
    # local vless_url="vless://${uuid}@${display_ip}:${port}?flow=xtls-rprx-vision&encryption=none&type=tcp&security=reality&sni=${domain}&fp=chrome&pbk=${public_key}&sid=${shortid}#${link_name_encoded}"
    # 修改对应rand_outer
    local vless_url="vless://${uuid}@${display_ip}:${rand_outer}?flow=xtls-rprx-vision&encryption=none&type=tcp&security=reality&sni=${domain}&fp=chrome&pbk=${public_key}&sid=${shortid}#${link_name_encoded}"

    if [[ "$is_quiet" = true ]]; then
        echo "${vless_url}"
    else
        # echo "${vless_url}" > ~/xray_vless_reality_link.txt
        echo "${vless_url}" > ./xray_vless_reality_link.txt  # 修改至当前文件目录
        echo "----------------------------------------------------------------"
        echo -e "$green --- Xray VLESS-Reality 订阅信息 --- $none"
        echo -e "$yellow 名称: $cyan$link_name$none"
        echo -e "$yellow 地址: $cyan$ip$none"
        # echo -e "$yellow 端口:<-!注意开放端口!->>> $cyan$port$none "
        echo -e "$yellow 端口:inner:${yellow}${rand_inner}${none} <-!注意开放端口!-> outer:${yellow}${rand_outer}${none} ${cyan}${port}${none}"
        echo -e "$yellow UUID: $cyan$uuid$none"
        echo -e "$yellow 流控: $cyan"xtls-rprx-vision"$none"
        echo -e "$yellow 指纹: $cyan"chrome"$none"
        echo -e "$yellow SNI: $cyan$domain$none"
        echo -e "$yellow 公钥: $cyan$public_key$none"
        echo -e "$yellow ShortId: $cyan$shortid$none"
        echo "----------------------------------------------------------------"
        echo -e "${yellow}inner:${yellow}${rand_inner}${none} <-!注意开放端口!-> outer:${yellow}${rand_outer}${none} ${cyan}${port}${none}"
        echo -e "${green}订阅链接 (已保存到 ./xray_vless_reality_link.txt):${none}\n"
        echo -e "${cyan}${vless_url}${none}"
        echo "----------------------------------------------------------------"
    fi
}

# --- 核心逻辑函数 ---
write_config() {
    local port=$1 uuid=$2 domain=$3 private_key=$4 public_key=$5 # shortid="20220701"
    # 升级一下shortid 生成逻辑
    local shortid
    shortid=$(TZ=Asia/Shanghai date +%Y%m%d)

    jq -n \
        --argjson port "$port" \
        --arg uuid "$uuid" \
        --arg domain "$domain" \
        --arg private_key "$private_key" \
        --arg public_key "$public_key" \
        --arg shortid "$shortid" \
    '{
        "log": {"loglevel": "warning"},
        "inbounds": [{
            "listen": "0.0.0.0",
            "port": $port,
            "protocol": "vless",
            "settings": {
                "clients": [{"id": $uuid, "flow": "xtls-rprx-vision"}],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "tcp",
                "security": "reality",
                "realitySettings": {
                    "show": false,
                    "dest": ($domain + ":443"),
                    "xver": 0,
                    "serverNames": [$domain],
                    "privateKey": $private_key,
                    "publicKey": $public_key,
                    "shortIds": [$shortid]
                }
            },
            "sniffing": {
                "enabled": true,
                "destOverride": ["http", "tls", "quic"]
            }
        }],
        "outbounds": [{
            "protocol": "freedom",
            "settings": {
                "domainStrategy": "UseIPv4v6"
            }
        }]
    }' > "$xray_config_path"
}

run_install() {
    local port=$1 uuid=$2 domain=$3
    info "正在下载并安装 Xray 核心..."
    if ! execute_official_script "install"; then
        error "Xray 核心安装失败！请检查网络连接。"
        exit 1
    fi

    info "正在安装/更新 GeoIP 和 GeoSite 数据文件..."
    if ! execute_official_script "install-geodata"; then
        error "Geo-data 更新失败！"
        info "这通常不影响核心功能，您可以稍后通过更新选项(2)来重试。"
    fi

    info "正在生成 Reality 密钥对..."
    local key_pair=$($xray_binary_path x25519)
    local private_key=$(echo "$key_pair" | awk '/PrivateKey:/ {print $2}')
    local public_key=$(echo "$key_pair" | awk '/Password:/ {print $2}')
    if [[ -z "$private_key" || -z "$public_key" ]]; then
        error "生成 Reality 密钥对失败！请检查 Xray 核心是否正常。"
        exit 1
    fi

    info "正在写入 Xray 配置文件..."
    write_config "$port" "$uuid" "$domain" "$private_key" "$public_key"

    if ! restart_xray; then exit 1; fi

    success "Xray 安装/配置成功！"
    view_subscription_info
}

press_any_key_to_continue() {
    echo ""
    read -n 1 -s -r -p "按任意键返回主菜单..." || true
}

main_menu() {
    while true; do
        clear
        echo -e "$cyan Xray VLESS-Reality 一键安装管理脚本$none"
        echo "---------------------------------------------"
        check_xray_status
        echo -e "${xray_status_info}"
        echo "---------------------------------------------"
        printf "  ${green}%-2s${none} %-35s\n" "1." "安装/重装 Xray"
        printf "  ${cyan}%-2s${none} %-35s\n" "2." "更新 Xray"
        printf "  ${yellow}%-2s${none} %-35s\n" "3." "重启 Xray"
        printf "  ${red}%-2s${none} %-35s\n" "4." "卸载 Xray"
        printf "  ${magenta}%-2s${none} %-35s\n" "5." "查看 Xray 日志"
        printf "  ${cyan}%-2s${none} %-35s\n" "6." "修改节点配置"
        printf "  ${green}%-2s${none} %-35s\n" "7." "查看订阅信息"
        echo "---------------------------------------------"
        printf "  ${yellow}%-2s${none} %-35s\n" "0." "退出脚本"
        echo "---------------------------------------------"
        read -p "请输入选项 [0-7]: " choice

        local needs_pause=true
        case $choice in
            1) install_xray ;;
            2) update_xray ;;
            3) restart_xray ;;
            4) uninstall_xray ;;
            5) view_xray_log; needs_pause=false ;;
            6) modify_config ;;
            7) view_subscription_info ;;
            0) success "感谢使用！"; exit 0 ;;
            *) error "无效选项，请输入 0-7 之间的数字。" ;;
        esac

        if [ "$needs_pause" = true ]; then
            press_any_key_to_continue
        fi
    done
}

# --- 脚本主入口 ---
main() {
    pre_check
    if [[ $# -gt 0 && "$1" == "install" ]]; then
        shift
        local port="" uuid="" domain=""
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --port) port="$2"; shift 2 ;;
                --uuid) uuid="$2"; shift 2 ;;
                --sni) domain="$2"; shift 2 ;;
                --quiet|-q) is_quiet=true; shift ;;
                *) error "未知参数: $1"; exit 1 ;;
            esac
        done
        [[ -z "$port" ]] && port=443
        [[ -z "$uuid" ]] && uuid=$(cat /proc/sys/kernel/random/uuid)
        [[ -z "$domain" ]] && domain="learn.microsoft.com"
        if ! is_valid_port "$port" || ! is_valid_domain "$domain"; then
            error "参数无效。请检查端口或SNI域名格式。" && exit 1
        fi
        if [[ -n "$uuid" ]] && ! is_valid_uuid "$uuid"; then
            error "UUID格式无效。请提供标准UUID格式或留空自动生成。" && exit 1
        fi
        if is_port_in_use "$port"; then
            error "端口 $port 已被占用，请选择其他端口。" && exit 1
        fi
        run_install "$port" "$uuid" "$domain"
    else
        main_menu
    fi
}

main "$@"
