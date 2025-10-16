#!/bin/sh
# test.sni.sh - 自动兼容 Alpine / Debian
# 测试域名 443 延迟并输出前 5

# --- 系统检测 ---
if grep -qi "alpine" /etc/os-release 2>/dev/null; then
    OS_TYPE="alpine"
    apk add --no-cache openssl coreutils >/dev/null 2>&1
else
    OS_TYPE="debian"
    apt-get update -y >/dev/null 2>&1
    apt-get install -y openssl coreutils >/dev/null 2>&1
fi

# --- 时间函数 ---
if date +%s%3N >/dev/null 2>&1; then
    now_ms() { date +%s%3N; }
else
    now_ms() { echo "$(( $(date +%s) * 1000 ))"; }
fi

# --- 域名列表 ---
DOMAINS="
www.icloud.com
rum.hlx.page
ts4.tc.mm.bing.net
th.bing.com
download.amd.com
images.nvidia.com
d1.awsstatic.com
s0.awsstatic.com
vs.aws.amazon.com
azure.microsoft.com
go.microsoft.com
downloaddispatch.itunes.apple.com
apps.mzstatic.com
"

RESULTS=""

# --- 测试延迟 ---
for d in $DOMAINS; do
    t1=$(now_ms)
    if timeout 1 openssl s_client -connect "$d:443" -servername "$d" </dev/null >/dev/null 2>&1; then
        t2=$(now_ms)
        latency=$((t2 - t1))
        RESULTS="${RESULTS}${latency} ${d}\n"
    else
        RESULTS="${RESULTS}9999 ${d}\n"
    fi
done

# --- 输出结果 ---
echo "=== Top 5 延迟最短域名 ==="
printf "$RESULTS" | sort -n | head -n 5 | awk '{print $2 ": " $1 " ms"}'
