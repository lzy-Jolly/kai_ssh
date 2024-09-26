#!/bin/bash

# 创建文件夹并进入
mkdir -p /home/featurize/data/tmp
cd /home/featurize/data/tmp

# 定义函数记录时间
time_elapsed() {
    start=$1
    end=$2
    elapsed=$(( end - start ))
    echo "Download and processing time: $elapsed seconds"
}

# 检查第一个数据集是否已经下载
if [ ! -d "/home/featurize/data/tmp/v1.0-trainval_meta" ]; then
    echo "Downloading first dataset..."
    start_time=$(date +%s)
    
    # 下载第一个数据集
    featurize dataset extract 35717cfd-336f-42d0-b2c2-850ca64bc2f2
    
    # 剪切文件到目标目录
    mv /home/featurize/data/tmp/v1.0-trainval_meta/* /home/featurize/data/nuscenes/v1.0-trainval/
    
    end_time=$(date +%s)
    time_elapsed $start_time $end_time
else
    echo "First dataset already downloaded, skipping..."
fi

# 检查第二个数据集是否已经下载
if [ ! -d "/home/featurize/data/tmp/nuscenes-full" ]; then
    echo "Downloading second dataset..."
    start_time=$(date +%s)
    
    # 下载第二个数据集
    featurize dataset extract 7c9beef0-b2e6-4582-96f6-d82b3db1e89f
    
    # 移动文件到目标目录
    mv /home/featurize/data/tmp/nuscenes-full/* /home/featurize/data/nuscenes/v1.0-trainval/
    
    end_time=$(date +%s)
    time_elapsed $start_time $end_time
else
    echo "Second dataset already downloaded, skipping..."
fi

# 提示下载完成
echo "Both datasets have been processed."
