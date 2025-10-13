#!/bin/bash
# test.sni.sh
# 测试域名443端口连接延迟，并输出前5延迟最短的域名

# --- 域名列表 ---
DOMAINS=(
lpcdn.lpsnmedia.net
d2c.aws.amazon.com
c.s-microsoft.com
rum.hlx.page
ts4.tc.mm.bing.net
th.bing.com
download.amd.com
images.nvidia.com
d1.awsstatic.com
s0.awsstatic.com
)

RESULTS=()

# --- 测试延迟 ---
for d in "${DOMAINS[@]}"; do
    t1=$(date +%s%3N)
    # 超时1秒，尝试SSL连接
    if timeout 1 openssl s_client -connect "$d:443" -servername "$d" </dev/null &>/dev/null; then
        t2=$(date +%s%3N)
        latency=$((t2 - t1))
        RESULTS+=("$latency $d")
    else
        RESULTS+=("9999 $d")  # 超时的延迟设置为大数
    fi
done

# --- 排序输出前5延迟最短 ---
echo "=== Top 5 延迟最短域名 ==="
printf "%s\n" "${RESULTS[@]}" | sort -n | head -n 5 | awk '{print $2 ": " $1 " ms"}'

# --- 如果其他程序想获取前5域名列表，只需从排序结果中提取第二列 ---
# top5=$(printf "%s\n" "${RESULTS[@]}" | sort -n | head -n 5 | awk '{print $2}')
# echo "$top5"
