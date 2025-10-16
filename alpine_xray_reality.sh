#!/bin/bash

# ==============================================================================
# Xray VLESS-Reality 一键安装管理脚本 (Alpine Linux Edition)
# 版本: V-Final-2.1-Alpine
# 基于 V-Final-2.1 修改以适配 Alpine Linux
# ==============================================================================

# --- Shell 严格模式 ---
set -euo pipefail

# --- 全局常量 ---
readonly SCRIPT_VERSION="V-Final-2.1-Alpine"
readonly xray_config_path="/usr/local/etc/xray/config.json"
readonly xray_binary_path="/usr/local/bin/xray"
# MODIFIED FOR ALPINE: Updated URL to the Alpine-specific installation script
readonly xray_install_script_url="https://github.com/XTLS/Xray-install/raw/main/alpinelinux/install-release.sh"
readonly xray_local_install_script="install-release.sh"

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
    local action="$1" # 'install', 'install-geodata', or 'remove'
    
    action="$1"  # install | install-geodata | remove

    info "正在下载 Xray Alpine 安装脚本..."
    if ! curl -L -o "$xray_local_install_script" "$xray_install_script_url"; then
        error "下载 Xray Alpine 安装脚本失败！请检查网络连接。"
        return 1
    fi
    chmod +x "$xray_local_install_script"

    cmd_args=""
    case "$action" in
        install)
            info "正在执行安装/更新..."
            ;;
        install-geodata)
            info "正在更新 GeoIP/GeoSite..."
            cmd_args="--geodata"
            ;;
        remove)
            info "正在执行卸载..."
            cmd_args="--remove"
            ;;
        *)
            error "未知操作: $action"
            return 1
            ;;
    esac

    info "开始执行 Xray 安装脚本..."
    # 官方建议在 Alpine 下用 ash 执行
    ash "./$xray_local_install_script"  $cmd_args >> /tmp/xray_install.log 2>&1
    # result=$?

    # 等待安装完成：检测 /usr/local/bin/xray 是否存在
    if [ "$action" = "install" ]; then
        count=0
        while [ ! -f /usr/local/bin/xray ] && [ $count -lt 20 ]; do
            sleep 1
            count=$((count + 1))
        done

        if [ -f /usr/local/bin/xray ]; then
            info "检测到 Xray 安装完成，正在注册开机启动..."
            rc-update add xray default >/dev/null 2>&1 || true
        else
            warn "未检测到完整安装结果，请查看日志 /tmp/xray_install.log"
        fi
    fi

    # ====== 检查执行结果 ======
    if [ ${PIPESTATUS[0]:-0} -ne 0 ]; then
        error "Xray 安装失败，请检查网络或手动运行 ./install-release.sh"
        echo "-------------"
        echo "./install-release.sh"
        return 1
    fi
}



# --- 验证函数 (No changes needed) ---
is_valid_port() {
    local port=$1
    [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]
}

is_port_in_use() {
    local port=$1
    # MODIFIED FOR ALPINE: netstat is in 'net-tools' which may not be installed. Using `ss` from `iproute2` is better.
    if command -v ss &>/dev/null; then
        ss -tuln 2>/dev/null | grep -q ":$port "
    elif command -v netstat &>/dev/null; then
        netstat -tuln 2>/dev/null | grep -q ":$port "
    else
        info "无法找到 ss 或 netstat 命令来检查端口。请考虑安装 'iproute2-ss' 或 'net-tools'。"
        return 1 # Fail safely
    fi
}

is_valid_uuid() {
    local uuid=$1
    [[ "$uuid" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]
}

is_valid_domain() {
    local domain=$1
    [[ "$domain" =~ ^[a-zA-Z0-9-]{1,63}(\.[a-zA-Z0-9-]{1,63})+$ ]] && [[ "$domain" != *--* ]]
}

# MODIFIED FOR ALPINE: Complete rewrite for Alpine Linux detection
check_system_compatibility() {
    if [[ ! -f /etc/alpine-release ]]; then
        error "错误: 此脚本已修改为仅支持 Alpine Linux。"
        error "在 /etc/alpine-release 未找到。"
        return 1
    fi
    
    info "系统兼容性检查通过: Alpine Linux"
    
    local required_commands=("rc-update" "rc-service" "awk" "grep" "sed")
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        error "错误: 缺少必要的系统命令: ${missing_commands[*]}"
        return 1
    fi
    
    return 0
}


# --- 预检查与环境设置 ---
pre_check() {
    # 必须使用 root 用户
    [[ $(id -u) != 0 ]] && error "错误: 您必须以 root 用户身份运行此脚本" && exit 1

    # ------------------ 系统兼容性检查 ------------------
    if [[ ! -f /etc/alpine-release ]]; then
        error "错误: 此脚本仅支持 Alpine 系统。"
        exit 1
    fi

    # ------------------ 依赖检查 ------------------
    if ! command -v jq &>/dev/null || ! command -v curl &>/dev/null; then
        info "检测到缺失的依赖 (jq / curl)，正在尝试自动安装..."
        apk update &>/dev/null
        apk add --no-cache jq curl &>/dev/null &
        # spinner $!
        if ! command -v jq &>/dev/null || ! command -v curl &>/dev/null; then
            error "依赖 (jq / curl) 自动安装失败，请手动运行："
            echo "  apk update && apk add --no-cache jq curl"
            exit 1
        fi
        success "依赖已成功安装。"
    fi
}



check_xray_status() {
    if [[ ! -f "$xray_binary_path" ]]; then xray_status_info="  Xray 状态: ${red}未安装${none}"; return; fi
    local xray_version=$($xray_binary_path version 2>/dev/null | head -n 1 | awk '{print $2}' || echo "未知")
    local service_status
    # MODIFIED FOR ALPINE: Use rc-service to check status
    if rc-service xray status &>/dev/null; then service_status="${green}运行中${none}"; else service_status="${yellow}未运行${none}"; fi
    xray_status_info="  Xray 状态: ${green}已安装${none} | ${service_status} | 版本: ${cyan}${xray_version}${none}"
}

# --- 菜单功能函数 (大部分逻辑不变, 仅调用修改后的核心函数) ---
install_xray() {
    # if [[ -f "$xray_binary_path" ]]; then
    #     info "检测到 Xray 已安装。继续操作将覆盖现有配置。"
    #     read -p "是否继续？[y/N]: " confirm
    #     if [[ ! $confirm =~ ^[yY]$ ]]; then info "操作已取消。"; return; fi
    # fi
    # 修改默认是y
    if [[ -f "$xray_binary_path" ]]; then
    info "检测到 Xray 已安装。继续操作将覆盖现有配置。"
    read -p "是否继续？[Y/n]: " confirm
    confirm=${confirm:-Y}  # 若用户直接回车，默认为 Y
    if [[ ! $confirm =~ ^[yY]$ ]]; then
        info "操作已取消。"
        return
    fi
fi

    info "开始配置 Xray..."
    local port uuid domain
    while true; do
        while true; do
            default_port=$((RANDOM % (65535 - 25000 + 1) + 25000))
            if ! is_port_in_use "$default_port"; then break; fi
        done
        read -p "$(echo -e "请输入端口 [1-65535] (默认随机为: ${cyan}${default_port}${none}): ")" port
        [ -z "$port" ] && port=$default_port
        if ! is_valid_port "$port"; then error "端口无效，请输入一个1-65535之间的数字。"; continue; fi
        if is_port_in_use "$port"; then error "端口 $port 已被占用，请选择其他端口。"; continue; fi
        break
    done

    while true; do
        read -p "$(echo -e "请输入UUID (留空将默认生成随机UUID): ")" uuid
        if [[ -z "$uuid" ]]; then 
            uuid=$(cat /proc/sys/kernel/random/uuid)
            info "已为您生成随机UUID: ${cyan}${uuid}${none}"
            break
        elif is_valid_uuid "$uuid"; then break;
        else error "UUID格式无效。"; fi
    done
    
    while true; do
        execute_sni_test || { error "SNI 测试失败，请检查网络"; continue; }
        read -p "$(echo -e "请输入SNI域名 (默认: ${cyan}learn.microsoft.com${none}): ")" domain
        [ -z "$domain" ] && domain="learn.microsoft.com"
        if is_valid_domain "$domain"; then break; else error "域名格式无效。"; fi
    done

    run_install "$port" "$uuid" "$domain"
}

execute_sni_test() {
    local sni_script_url="https://raw.githubusercontent.com/lzy-Jolly/kai_ssh/refs/heads/main/test.sni.sh"
    local local_script="./test.sni.sh"
    if [[ ! -f "$local_script" ]]; then
        info "正在下载 test.sni.sh 脚本..."
        curl -fsSL "$sni_script_url" -o "$local_script" || { error "下载失败！"; return 1; }
        chmod +x "$local_script"
    fi
    info "正在执行 test.sni.sh 脚本...请稍等选择一个合适的域名或者默认"
    bash "$local_script" # Ensure it runs with bash
    return $?
}

update_xray() {
    if [[ ! -f "$xray_binary_path" ]]; then error "错误: Xray 未安装，无法执行更新。" && return; fi
    info "正在检查最新版本..."
    local current_version=$($xray_binary_path version | head -n 1 | awk '{print $2}')
    local latest_version=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | jq -r '.tag_name' | sed 's/v//' || echo "")
    if [[ -z "$latest_version" ]]; then error "获取最新版本号失败。" && return; fi
    info "当前版本: ${cyan}${current_version}${none}，最新版本: ${cyan}${latest_version}${none}"
    if [[ "$current_version" == "$latest_version" ]]; then success "您的 Xray 已是最新版本。" && return; fi
    
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
    # MODIFIED FOR ALPINE: Use rc-service
    if ! rc-service xray restart; then
        error "错误: Xray 服务重启失败, 请使用菜单 5 查看日志检查具体原因。"
        return 1
    fi
    sleep 1
    if ! rc-service xray status &>/dev/null; then
        error "错误: Xray 服务启动失败, 请使用菜单 5 查看日志检查具体原因。"
        return 1
    fi
    success "Xray 服务已成功重启！"
}

uninstall_xray() {
    if [[ ! -f "$xray_binary_path" ]]; then error "错误: Xray 未安装，无需卸载。" && return; fi
    read -p "您确定要卸载 Xray 吗？这将删除所有相关文件。[Y/n]: " confirm
    if [[ "$confirm" =~ ^[nN]$ ]]; then info "卸载操作已取消。"; return; fi
    
    info "正在停止并禁用 Xray 服务..."
    rc-service xray stop &>/dev/null
    rc-update del xray default &>/dev/null

    info "正在卸载 Xray..."
    # MODIFIED FOR ALPINE: Call script with --remove and manually purge config
    if execute_official_script "remove"; then
        info "正在清理配置文件和日志..."
        rm -rf /usr/local/etc/xray
        rm -rf /var/log/xray
        rm -f ./xray_vless_reality_link.txt
        rm -f "./$xray_local_install_script" # Clean up downloaded script
        success "Xray 已成功卸载。"
    else
        error "Xray 卸载失败！"
        return 1
    fi
}

view_xray_log() {
    if [[ ! -f "$xray_binary_path" ]]; then error "错误: Xray 未安装，无法查看日志。" && return; fi
    info "正在显示 Xray 实时日志... 按 Ctrl+C 退出。"
    # MODIFIED FOR ALPINE: Use tail instead of journalctl
    local log_file="/var/log/xray/error.log"
    if [[ ! -f "$log_file" ]]; then
        error "日志文件 $log_file 不存在。请确保 Xray 配置了日志输出。"
        return
    fi
    tail -f "$log_file"
}

modify_config() {
    if [[ ! -f "$xray_config_path" ]]; then error "错误: Xray 未安装，无法修改配置。" && return; fi
    info "读取当前配置..."
    local current_port=$(jq -r '.inbounds[0].port' "$xray_config_path")
    local current_uuid=$(jq -r '.inbounds[0].settings.clients[0].id' "$xray_config_path")
    local current_domain=$(jq -r '.inbounds[0].streamSettings.realitySettings.serverNames[0]' "$xray_config_path")
    local private_key=$(jq -r '.inbounds[0].streamSettings.realitySettings.privateKey' "$xray_config_path")
    local public_key=$(jq -r '.inbounds[0].streamSettings.realitySettings.publicKey' "$xray_config_path")

    info "请输入新配置，直接回车则保留当前值。"
    local port uuid domain
    
    while true; do
        read -p "$(echo -e "端口 (当前: ${cyan}${current_port}${none}): ")" port
        [ -z "$port" ] && port=$current_port
        if ! is_valid_port "$port"; then error "端口无效。"; continue; fi
        if [[ "$port" != "$current_port" ]] && is_port_in_use "$port"; then error "端口 $port 已被占用。"; continue; fi
        break
    done
    
    while true; do
        read -p "$(echo -e "UUID (当前: ${cyan}${current_uuid}${none}): ")" uuid
        [ -z "$uuid" ] && uuid=$current_uuid
        if is_valid_uuid "$uuid"; then break; else error "UUID格式无效。"; fi
    done
    
    while true; do
        read -p "$(echo -e "SNI域名 (当前: ${cyan}${current_domain}${none}): ")" domain
        [ -z "$domain" ] && domain=$current_domain
        if is_valid_domain "$domain"; then break; else error "域名格式无效。"; fi
    done

    write_config "$port" "$uuid" "$domain" "$private_key" "$public_key"
    if ! restart_xray; then return; fi

    success "配置修改成功！"
    view_subscription_info
}

# --- 核心逻辑函数 (大部分不变) ---
view_subscription_info() {
    if [ ! -f "$xray_config_path" ]; then error "错误: 配置文件不存在, 请先安装。" && return; fi
    
    local ip
    if ! ip=$(get_public_ip); then return 1; fi

    local uuid=$(jq -r '.inbounds[0].settings.clients[0].id' "$xray_config_path")
    local port=$(jq -r '.inbounds[0].port' "$xray_config_path")
    local domain=$(jq -r '.inbounds[0].streamSettings.realitySettings.serverNames[0]' "$xray_config_path")
    local public_key=$(jq -r '.inbounds[0].streamSettings.realitySettings.publicKey' "$xray_config_path")
    local shortid=$(jq -r '.inbounds[0].streamSettings.realitySettings.shortIds[0]' "$xray_config_path")
    if [[ -z "$public_key" ]]; then error "配置文件中缺少公钥信息。" && return; fi

    local display_ip=$ip && [[ $ip =~ ":" ]] && display_ip="[$ip]"
    local link_name="$(hostname) X-reality"
    local link_name_encoded=$(echo "$link_name" | sed 's/ /%20/g')
    local vless_url="vless://${uuid}@${display_ip}:${port}?flow=xtls-rprx-vision&encryption=none&type=tcp&security=reality&sni=${domain}&fp=chrome&pbk=${public_key}&sid=${shortid}#${link_name_encoded}"

    if [[ "$is_quiet" = true ]]; then
        echo "${vless_url}"
    else
        echo "${vless_url}" > ./xray_vless_reality_link.txt
        echo "----------------------------------------------------------------"
        echo -e "$green --- Xray VLESS-Reality 订阅信息 --- $none"
        echo -e "$yellow 名称: $cyan$link_name$none"
        echo -e "$yellow 地址: $cyan$ip$none"
        echo -e "$yellow 端口:<-!！注意开放端口!->>> $cyan$port$none "
        echo -e "$yellow UUID: $cyan$uuid$none"
        echo -e "$yellow 流控: $cyan"xtls-rprx-vision"$none"
        echo -e "$yellow 指纹: $cyan"chrome"$none"
        echo -e "$yellow SNI: $cyan$domain$none"
        echo -e "$yellow 公钥: $cyan$public_key$none"
        echo -e "$yellow ShortId: $cyan$shortid$none"
        echo "----------------------------------------------------------------"
        echo -e "$yellow <-!！注意开放端口!->>> $cyan$port$none "
        echo -e "$green 订阅链接 (已保存到 ./xray_vless_reality_link.txt): $none\n"; echo -e "$cyan${vless_url}${none}"
        echo "----------------------------------------------------------------"
    fi
}

write_config() {
    local port=$1 uuid=$2 domain=$3 private_key=$4 public_key=$5 shortid="20220701"
    # MODIFIED FOR ALPINE: Point log file to /var/log/xray/error.log for `view_xray_log` to work
    jq -n \
        --argjson port "$port" \
        --arg uuid "$uuid" \
        --arg domain "$domain" \
        --arg private_key "$private_key" \
        --arg public_key "$public_key" \
        --arg shortid "$shortid" \
    '{
        "log": {
            "loglevel": "warning",
            "error": "/var/log/xray/error.log",
            "access": "/var/log/xray/access.log"
        },
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
        error "生成 Reality 密钥对失败！"
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
        echo -e "$cyan Xray VLESS-Reality 一键脚本 (Alpine Edition)$none"
        echo "---------------------------------------------"
        check_xray_status
        echo -e "${xray_status_info}"
        echo "重新进入请执行 ./alpine_xray_reality.sh"
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
            0) success "感谢使用！"; rm -f "./$xray_local_install_script"; exit 0 ;;
            *) error "无效选项。" ;;
        esac

        if [ "$needs_pause" = true ]; then
            press_any_key_to_continue
        fi
    done
}




# --- 脚本主入口 ---
main() {

    pre_check
    main_menu
}

main "$@"
