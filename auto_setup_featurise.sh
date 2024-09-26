#!/bin/bash

# 定义函数记录时间
time_elapsed() {
    start=$1
    end=$2
    elapsed=$(( end - start ))
    echo "Elapsed time: $elapsed seconds"
}

# 记录第一个活动开始时间
start_time_activity_1=$(date +%s)

# 第一个活动: 复制除了 cuda_11.6.2.tar 以外的所有文件和文件夹从 /home/featurize/work 到 /home/featurize
rsync -avzP --exclude='cuda_11.6.2.tar' /home/featurize/work/ /home/featurize/

# 记录第一个活动结束时间并计算时间
end_time_activity_1=$(date +%s)
echo "Time for rsync activity:"
time_elapsed $start_time_activity_1 $end_time_activity_1

# 记录第二个活动开始时间
start_time_activity_2=$(date +%s)

# 第二个活动: 检查是否成功复制了 pcd.1.5.tar 并加载到 Docker
if [ -f "/home/featurize/pcd.1.5.tar" ]; then
    echo "pcd.1.5.tar found. Loading into Docker..."
    docker load -i /home/featurize/pcd.1.5.tar
    echo "Docker image loaded successfully."
else
    echo "Error: pcd.1.5.tar not found."
fi

# 记录第二个活动结束时间并计算时间
end_time_activity_2=$(date +%s)
echo "Time for Docker load activity:"
time_elapsed $start_time_activity_2 $end_time_activity_2
