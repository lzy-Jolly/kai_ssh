#!/usr/bin/env bash
set -euo pipefail

# ===============================
# kissback.sh
# 从 GitHub 拉取/校验/解密并追加 root 公钥
# Fetch/Verify/Decrypt and append root public key from GitHub
# ===============================

RAW_URL="https://raw.githubusercontent.com/lzy-Jolly/kai_ssh/refs/heads/main/helloworld.sh"
GITHUB_COMMITS_API="https://api.github.com/repos/lzy-Jolly/kai_ssh/commits/main"
MAX_PULL_TRIES=2

# -------------------------------
# 仅 root 可运行
# Root only
# -------------------------------
[ "$EUID" -ne 0 ] && { echo "❌ 请以 root 运行 / Please run as root"; exit 1; }

# -------------------------------
# 检查依赖
# Check dependencies
# -------------------------------
check_and_install_deps() {
    local need=()
    for cmd in curl openssl md5sum sed grep awk tee; do
        command -v "$cmd" >/dev/null 2>&1 || need+=("$cmd")
    done
    [ ${#need[@]} -eq 0 ] && return 0
    
    echo "📦 缺少命令: ${need[*]}，尝试安装 / Missing commands: ${need[*]}, trying to install"
    if command -v apk >/dev/null; then
        apk add --no-cache ca-certificates curl openssl coreutils sed grep awk util-linux
    elif command -v apt-get >/dev/null; then
        apt-get update -y && apt-get install -y curl openssl coreutils sed grep awk
    elif command -v yum >/dev/null; then
        yum install -y curl openssl coreutils sed grep gawk
    elif command -v dnf >/dev/null; then
        dnf install -y curl openssl coreutils sed grep gawk
    else 
        echo "❌ 请手动安装: ${need[*]} / Please install manually: ${need[*]}"; exit 1
    fi
}

# -------------------------------
# 下载 helloworld 并提取 base
# Download helloworld and extract base
# -------------------------------
download_check_md5() {
    local try=1 tmpfile="helloworld.sh.tmp" file_md5 commit_md5 commit_msg ok=0
    
    while [ $try -le $MAX_PULL_TRIES ]; do
        echo "🌐 下载 helloworld.sh 第 $try/$MAX_PULL_TRIES 次... "
        echo "Downloading helloworld.sh attempt $try/$MAX_PULL_TRIES..."
        
        if ! curl -fsSL "$RAW_URL" -o "$tmpfile"; then
            echo "❌ 下载失败 / Download failed"
            ((try++)); sleep 1; continue
        fi
        
        file_md5=$(md5sum "$tmpfile" | awk '{print $1}')
        echo "下载文件 MD5: $file_md5 / Downloaded file MD5: $file_md5"
        
        commit_msg=$(curl -fsSL "$GITHUB_COMMITS_API" 2>/dev/null | grep '"message"' | head -1 | sed 's/.*"message": *"\([^"]*\)".*/\1/' || true)
        commit_md5=$(echo "$commit_msg" | grep -oE '[0-9a-f]{32}' | head -1 || true)
        
        if [ -n "$commit_md5" ] && [ "$commit_md5" != "$file_md5" ]; then
            echo "❌ MD5 不匹配: 提交=$commit_md5, 文件=$file_md5 / MD5 mismatch: commit=$commit_md5, file=$file_md5"
            ((try++)); sleep 1; continue
        fi
        
        mv "$tmpfile" helloworld.sh
        grep -E '^# [A-Za-z0-9+/=]+' helloworld.sh | head -1 | sed 's/^# //' > helloworld.base
        rm -f helloworld.sh
        echo "提取加密内容完成 / Encryption content extracted successfully"
        return 0
    done
    
    echo "下载失败，超过最大尝试次数 / Download failed, exceeded max attempts"
    rm -f "$tmpfile"
    exit 1
}

# -------------------------------
# 解密 helloworld.base 并追加 root 公钥
# Decrypt helloworld.base and append root public key
# -------------------------------
decode_and_root() {
    [ ! -f "helloworld.base" ] && { echo "helloworld.base 不存在 / helloworld.base not found"; exit 1; }
    
    local tries=0 max_tries=2 password
    
    while [ $tries -lt $max_tries ]; do
        echo -n "输入解密密码: / Enter decryption password: "
        read -s password
        echo
        
        if tr -d '\r\n' < helloworld.base | base64 -d | openssl enc -d -aes-256-cbc -pbkdf2 -pass pass:"$password" -out kissvps.pub 2>/dev/null; then
            if ! grep -q "ssh-" kissvps.pub; then
                echo "解密文件无效 / Decrypted file is invalid"
                rm -f kissvps.pub
                ((tries++))
                continue
            fi
            
            echo "解密成功 / Decryption successful"
            mkdir -p /root/.ssh
            chmod 700 /root/.ssh
            
            # 检查并清理旧公钥
            # Check and clean old public keys
            if [ -f /root/.ssh/authorized_keys ]; then
                local tmp_auth="/tmp/authorized_keys.tmp.$$"
                cp /root/.ssh/authorized_keys "$tmp_auth"
                local modified=0
                
                while IFS= read -r line; do
                    if echo "$line" | grep -q 'kiss@jolly'; then
                        local last20=$(echo "$line" | tail -c 20)
                        while true; do
                        	   echo "Found old key ending: $last20"
					    read -p "是否删除该行?(y/N): " del </dev/tty
                            del=${del:-N}
                            case "$del" in
                                y|Y)
                                    sed -i "\|$line|d" "$tmp_auth"
                                    echo "✅ 已删除该行 / Line deleted"
                                    modified=1
                                    break
                                    ;;
                                n|N)
                                    echo "ℹ️ 保留该行 / Line kept"
                                    break
                                    ;;
                                *)
                                    echo "❌ 输入错误，请输入 y 或 n "
                                    echo "Invalid input, please enter y or n"
                                    ;;
                            esac
                        done
                    fi
                done < /root/.ssh/authorized_keys
                
                [ $modified -eq 1 ] && mv "$tmp_auth" /root/.ssh/authorized_keys
                rm -f "$tmp_auth"
            fi
            # --- 临时修改 sshd_config 确保 PubkeyAuthentication yes ---

            SSHD_CONF="/etc/ssh/sshd_config"
            SSHD_CONF_BAK="/etc/ssh/sshd_config.bak_$(date +%s)"
            cp "$SSHD_CONF" "$SSHD_CONF_BAK"

            # 如果不存在该行，添加；存在则替换为 yes
            if grep -q '^PubkeyAuthentication' "$SSHD_CONF"; then
                sed -i 's/^PubkeyAuthentication.*/PubkeyAuthentication yes/' "$SSHD_CONF"
            else
                echo 'PubkeyAuthentication yes' >> "$SSHD_CONF"
            fi
            # 重启 sshd
            try_restart_sshd
            echo "Ensured PubkeyAuthentication yes"


            # 追加新公钥
            # Append new public key
            cat kissvps.pub | tee -a /root/.ssh/authorized_keys >/dev/null
            chmod 600 /root/.ssh/authorized_keys
            echo "公钥追加完成 / Public key appended"
            rm -f helloworld.base
            echo "已删除 helloworld.base / helloworld.base deleted"
            return 0
        else
            echo " 解密失败（密码错误）/ Decryption failed (wrong password)"
        fi
        
        ((tries++))
        [ $tries -lt $max_tries ] && echo "还有 $((max_tries - tries)) 次机会 / $((max_tries - tries)) attempts remaining"
    done
    
    echo "❌ 解密失败次数过多 / Too many decryption failures"
    exit 1
}

# -------------------------------
# 禁止 root 密码登录（双重确认）
# Disable root password login (double confirmation)
# -------------------------------
change_pwd_login() {
    [ ! -f "kissvps.pub" ] && { echo "❌ 未找到 kissvps.pub / kissvps.pub not found"; exit 1; }
    
    echo
    echo "=== 双重确认：root password login==="
    echo "Enter y comfirm key can login as root"
    read -p "yes or no: " c1
    c1=${c1:-N}
    if ! echo "$c1" | grep -Eiq '^y'; then
        echo "请先确认 key 登录 / Please confirm key login first"
        exit 0
    fi
    
    echo "Enter N to disable root password login "
    read -p "yes or no (y/N):" c2
    c2=${c2:-N}
    if ! echo "$c2" | grep -Eiq '^n'; then
        echo "未修改 SSH 配置 / SSH config not modified"
        return 0
    fi
    
    # 备份并修改配置
    # Backup and modify config
    cp /etc/ssh/sshd_config "/etc/ssh/sshd_config.bak.$(date +%Y%m%d%H%M%S)"
    sed -i 's/^\s*PermitRootLogin\s\+.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
    grep -q '^PermitRootLogin' /etc/ssh/sshd_config || echo 'PermitRootLogin prohibit-password' >> /etc/ssh/sshd_config
    
    # 重启 SSH 服务
    try_restart_sshd
    
    rm -f kissvps.pub
#    echo "✅ kissvps.pub 已删除，root 密码登录已禁止 "
    echo "kissvps.pub deleted, root password login disabled"
}

try_restart_sshd(){
        # 重启 SSH 服务
    # Restart SSH service
    if command -v systemctl >/dev/null; then
        systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || echo "⚠️ 请手动重启 SSH / Please restart SSH manually"
    elif command -v service >/dev/null; then
        service ssh restart 2>/dev/null || service sshd restart 2>/dev/null || echo "⚠️ 请手动重启 SSH / Please restart SSH manually"
    fi
}

# -------------------------------
# 主流程
# Main process
# -------------------------------
main() {
    echo "=== kissback.sh 开始 ==="
    echo "=== kissback.sh started ==="
    check_and_install_deps
    
    if [ -f "kissvps.pub" ]; then
        change_pwd_login
    elif [ -f "helloworld.base" ]; then
        decode_and_root
        change_pwd_login
    else
        download_check_md5
        decode_and_root
        change_pwd_login
    fi
    
    echo "=== 完成 / Completed ==="
}

main "$@"
