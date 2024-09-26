#!/bin/bash

# 创建文件夹并切换到该目录
mkdir -p /home/featurize/data/nuscenes/v1.0-trainval
cd /home/featurize/data/nuscenes/v1.0-trainval

# 下载第一个数据集并计时
echo "开始下载第一个数据集..."
start_time_1=$(date +%s)
featurize dataset extract 35717cfd-336f-42d0-b2c2-850ca64bc2f2
end_time_1=$(date +%s)

# 复制v1.0-trainval_meta文件夹内的文件
cp -r v1.0-trainval_meta/* /home/featurize/data/nuscenes/v1.0-trainval

# 切换回工作目录
cd /home/featurize/data/nuscenes/v1.0-trainval

# 下载第二个数据集并计时
echo "开始下载第二个数据集..."
start_time_2=$(date +%s)
featurize dataset extract 7c9beef0-b2e6-4582-96f6-d82b3db1e89f
end_time_2=$(date +%s)

# 复制nuscenes-full文件夹内的文件
cp -r nuscenes-full/* /home/featurize/data/nuscenes/v1.0-trainval

# 计算并输出下载时间
download_time_1=$((end_time_1 - start_time_1))
download_time_2=$((end_time_2 - start_time_2))

echo "第一个数据集下载并处理完成，耗时 ${download_time_1} 秒。"
echo "第二个数据集下载并处理完成，耗时 ${download_time_2} 秒。"
