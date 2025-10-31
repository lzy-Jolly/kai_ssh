#!/bin/sh

# 进程内存平均占用测试脚本 (Resident Set Size - RSS)
# 针对 Alpine Linux (Ash/BusyBox shell) 环境优化

measure_memory() {
    local name="$1"
    
    # 优化后的 PID 定位逻辑:
    # 找到 VmRSS (实际物理内存) 最大的匹配进程的 PID。
    # 1. pgrep -f "$name" 找出所有匹配的 PID。
    # 2. xargs 遍历每个 PID，读取 VmRSS (以 KB 为单位)。
    # 3. sort -rn 按内存大小降序排序。
    # 4. awk 选取 VmRSS 最大的 PID。
    local pid=$(pgrep -f "$name" | xargs -r -I{} sh -c 'echo "$(awk "/VmRSS:/ {print \$2}" /proc/{}/status 2>/dev/null) {}"' | sort -rn | awk 'NR==1{print $2}')

    if [ -n "$pid" ]; then
        local total_rss=0
        # 获取系统总内存（以 KB 为单位）
        local mem_total=$(awk '/MemTotal:/ {print $2}' /proc/meminfo)
        
        echo "--> 正在测试进程: $name (PID: $pid)..."

        # 执行 10 次采样，计算平均 VmRSS
        for i in $(seq 1 10); do
            # VmRSS 是进程实际使用的物理内存大小，单位是 KB
            local rss=$(awk '/VmRSS:/ {print $2}' /proc/"$pid"/status 2>/dev/null)
            rss=${rss:-0}
            total_rss=$((total_rss + rss))
            
            # 简单的进度提示
            printf "." 
            
            sleep 1
        done
        
        # 计算平均 VmRSS (KB) -> MB
        # VmRSS 是 KB，所以除以 10 (平均值) / 1024 (转换为 MB)
        local avg_rss=$((total_rss / 10 / 1024))
        
        # 计算内存百分比 (使用 awk 进行浮点运算)
        # avg_rss_kb = total_rss / 10
        local avg_pct=$(awk -v total_rss=$total_rss -v mem=$mem_total 'BEGIN{printf "%.2f", (total_rss/10)/mem*100}')
        
        echo -e "\n✅ 进程: $name (PID: $pid) | 平均内存: ${avg_rss} MB | %MEM: ${avg_pct}%"
    else
        echo "❌ 进程: $name 未运行或命名错误"
    fi
}

# --- 主逻辑 ---

# 检查是否有输入参数
if [ -z "$1" ]; then
    # 如果没有参数，则使用默认进程列表。注意：这里使用字符串列表代替数组
    default_processes="xray tailscaled derper"
    # 将列表设置为位置参数，以便在 for 循环中遍历
    set -- $default_processes
fi

echo "--- 进程内存平均占用测试 (共采样10秒) ---"
echo "----------------------------------------"

# 遍历位置参数 (即传入的参数或默认进程列表)
for proc in "$@"; do
    measure_memory "$proc"
    echo "----------------------------------------"
done
