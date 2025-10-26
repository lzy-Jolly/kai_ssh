#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# kissback.sh
# 从 GitHub 拉取、校验、解密并追加 root pub
# Fetch, verify, decrypt, and append root public key from GitHub
# ============================================================

RAW_URL="https://raw.githubusercontent.com/lzy-Jolly/kai_ssh/refs/heads/main/helloworld.sh"
GITHUB_COMMITS_API="https://api.github.com/repos/lzy-Jolly/kai_ssh/commits/main"
MAX_PULL_TRIES=2

# -------------------------------
# 仅 root 可运行 / Root only
# -------------------------------
[ "$EUID" -ne 0 ] && { echo "❌ 请以 root 运行 / Please run as root"; exit 1; }

# -------------------------------
# 检查依赖并自动安装
# Check dependencies and auto-install missing packages
# -------------------------------
check_and_install_deps() {
    local need=()
    for cmd in curl openssl md5sum sed grep tee ssh-keygen; do
        command -v "$cmd" >/dev/null 2>&1 || need+=("$cmd")
    done
    [ ${#need[@]} -eq 0 ] && return 0

    echo "📦 缺少命令: ${need[*]}，尝试安装 / Missing commands: ${need[*]}, trying to install"

    # 检测包管理器并安装最小依赖
    if command -v apk >/dev/null 2>&1; then
        # Alpine - busybox 自带 awk/md5sum/head/sed/grep，无需安装 awk
        local packages="ca-certificates curl openssl coreutils util-linux grep sed"
        # openssh-client 在 Alpine 中提供 ssh/scp/ssh-keygen
        apk add --no-cache $packages openssh-client >/dev/null

    elif command -v apt-get >/dev/null 2>&1; then
        # Debian / Ubuntu
        apt-get update -y >/dev/null
        apt-get install -y curl openssl coreutils sed grep gawk openssh-client >/dev/null

    elif command -v yum >/dev/null 2>&1; then
        # CentOS / RHEL
        yum install -y curl openssl coreutils sed grep gawk openssh-clients >/dev/null

    elif command -v dnf >/dev/null 2>&1; then
        # Fedora / RHEL 8+
        dnf install -y curl openssl coreutils sed grep gawk openssh-clients >/dev/null

    else
        echo "❌ 未识别的包管理器，请手动安装以下依赖: ${need[*]}"
        echo "Unrecognized package manager. Please manually install: ${need[*]}"
        exit 1
    fi
}

# -------------------------------
# 下载并校验 helloworld.sh
# Download helloworld.sh and verify MD5 from latest commit message
# -------------------------------
download_check_md5() {
    local try=1 tmpfile="helloworld.sh.tmp" file_md5 commit_md5 commit_msg

    while [ $try -le $MAX_PULL_TRIES ]; do
        echo "🌐 下载 helloworld.sh 第 $try/$MAX_PULL_TRIES 次 / Attempt $try/$MAX_PULL_TRIES..."
        if ! curl -fsSL "$RAW_URL" -o "$tmpfile"; then
            echo "❌ 下载失败 / Download failed"
            ((try++)); sleep 1; continue
        fi

        file_md5=$(md5sum "$tmpfile" | awk '{print $1}')
        echo "📄 下载文件 MD5: $file_md5 / Downloaded file MD5: $file_md5"

        commit_msg=$(curl -fsSL "$GITHUB_COMMITS_API" 2>/dev/null | grep '"message"' | head -1 | sed 's/.*"message": *"\([^"]*\)".*/\1/' || true)
        commit_md5=$(echo "$commit_msg" | grep -oE '[0-9a-f]{32}' | head -1 || true)

        if [ -n "$commit_md5" ] && [ "$commit_md5" != "$file_md5" ]; then
            echo "❌ MD5 不匹配: 提交=$commit_md5, 文件=$file_md5 / MD5 mismatch"
            ((try++)); sleep 1; continue
        fi

        mv "$tmpfile" helloworld.sh
        grep -E '^# [A-Za-z0-9+/=]+' helloworld.sh | head -1 | sed 's/^# //' > helloworld.base
        rm -f helloworld.sh
        echo "✅ 加密内容提取完成 / Encrypted content extracted successfully"
        return 0
    done

    echo "❌ 下载失败，超过最大尝试次数 / Download failed, exceeded max attempts"
    rm -f "$tmpfile"
    exit 1
}

# -------------------------------
# 解密 base 内容并追加 root pub
# Decrypt base content and append root public key
# -------------------------------
decode_and_root() {
    [ ! -f "helloworld.base" ] && { echo "❌ helloworld.base 不存在 / helloworld.base not found"; exit 1; }

    local tries=0 max_tries=2 password

    while [ $tries -lt $max_tries ]; do
        echo -n "🔐 输入解密密码: / Enter decryption password: "
        read -s password; echo

        if tr -d '\r\n' < helloworld.base | base64 -d | \
           openssl enc -d -aes-256-cbc -pbkdf2 -pass pass:"$password" -out kissvps.pub 2>/dev/null; then

            if ! grep -q "ssh-" kissvps.pub; then
                echo "❌ 解密文件无效 / Decrypted file invalid"
                rm -f kissvps.pub; ((tries++)); continue
            fi

            echo "✅ 解密成功 / Decryption successful"
            mkdir -p /root/.ssh && chmod 700 /root/.ssh

            # 检查并清理旧pub
            if [ -f /root/.ssh/authorized_keys ]; then
                local tmp="/tmp/authorized_keys.$$"
                cp /root/.ssh/authorized_keys "$tmp"
                local modified=0
                while IFS= read -r line; do
                    if echo "$line" | grep -q 'kiss@jolly'; then
                        local last20=$(echo "$line" | tail -c 20)
                        echo "⚙️ 发现旧pub末尾: $last20 / Found old key ending: $last20"
                        read -p "是否删除该行?(y/N): " del </dev/tty
                        case "${del:-N}" in
                            y|Y) sed -i "\|$line|d" "$tmp"; modified=1; echo "✅ 已删除 / Deleted" ;;
                            n|N) echo "ℹ️ 保留 / Kept" ;;
                            *) echo "❌ 输入错误，请输入 y 或 n / Invalid input" ;;
                        esac
                    fi
                done < /root/.ssh/authorized_keys
                [ $modified -eq 1 ] && mv "$tmp" /root/.ssh/authorized_keys
                rm -f "$tmp"
            fi

            # 确保 sshd_config 启用pub认证
            SSHD_CONF="/etc/ssh/sshd_config"
            [ -f "$SSHD_CONF" ] || { echo "⚠️ 未找到 $SSHD_CONF"; return 1; }
            cp "$SSHD_CONF" "/etc/ssh/sshd_config.bak_$(date +%s)"
            if grep -q '^PubkeyAuthentication' "$SSHD_CONF"; then
                sed -i 's/^PubkeyAuthentication.*/PubkeyAuthentication yes/' "$SSHD_CONF"
            else
                echo 'PubkeyAuthentication yes' >> "$SSHD_CONF"
            fi
            try_restart_sshd

            # 追加新pub
            cat kissvps.pub >> /root/.ssh/authorized_keys
            chmod 600 /root/.ssh/authorized_keys
            echo "🔑 pub追加完成 / Public key appended"

            rm -f helloworld.base
            echo "🗑️ 已删除 helloworld.base / helloworld.base deleted"
            return 0
        else
            echo "❌ 解密失败（密码错误）/ Decryption failed (wrong password)"
        fi
        ((tries++))
        [ $tries -lt $max_tries ] && echo "还有 $((max_tries - tries)) 次机会 / $((max_tries - tries)) attempts remaining"
    done
    echo "❌ 解密失败次数过多 / Too many decryption failures"
    exit 1
}

# -------------------------------
# 禁用 root 密码登录（双重确认）
# Disable root password login with confirmation
# -------------------------------
change_pwd_login() {
    [ ! -f "kissvps.pub" ] && { echo "❌ 未找到 kissvps.pub / kissvps.pub not found"; exit 1; }

    echo -e "\n=== 双重确认：root 密码登录 / Double confirm root password login ==="
    read -p "enter y 确认pub登录成功? (y/N): " c1; c1=${c1:-N}
    if ! echo "$c1" | grep -Eiq '^y'; then
        echo "⚠️ 请先确认pub可登录 / Confirm key login first"; exit 0
    fi

    read -p "enter N 禁用 root 密码登录 (y/N): " c2; c2=${c2:-N}
    if ! echo "$c2" | grep -Eiq '^n'; then
        echo "ℹ️ 未修改 SSH 配置 / SSH config not modified"; return 0
    fi

    cp /etc/ssh/sshd_config "/etc/ssh/sshd_config.bak.$(date +%s)"
    sed -i 's/^\s*PermitRootLogin\s\+.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
    grep -q '^PermitRootLogin' /etc/ssh/sshd_config || echo 'PermitRootLogin prohibit-password' >> /etc/ssh/sshd_config

    try_restart_sshd
    rm -f kissvps.pub
    echo "✅ 已禁用 root 密码登录 / Root password login disabled"
}

# -------------------------------
# 尝试重启 SSH 服务
# Try restarting SSH service
# -------------------------------
try_restart_sshd() {
    if command -v systemctl >/dev/null 2>&1; then
        systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || echo "⚠️ 请手动重启 SSH / Restart SSH manually"
    elif command -v service >/dev/null 2>&1; then
        service ssh restart 2>/dev/null || service sshd restart 2>/dev/null || echo "⚠️ 请手动重启 SSH / Restart SSH manually"
    fi
}

# -------------------------------
# 主流程 / Main process
# -------------------------------
main() {
    echo "=== kissback.sh 开始 / Started ==="
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

    echo "=== ✅ 完成 / Completed ==="
}

main "$@"
