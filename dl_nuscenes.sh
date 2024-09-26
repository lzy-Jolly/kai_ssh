#!/bin/bash

# 定义函数记录时间
time_elapsed() {
    start=$1
    end=$2
    elapsed=$(( end - start ))
    echo "Elapsed time: $elapsed seconds"
}
# ------------------------------------------------------------------------#
# 创建目录并进入
mkdir -p /home/featurize/data/tmp
cd /home/featurize/data/tmp

    start_time=$(date +%s)
    
    # 下载第一个数据集v1.0-trainval_meta
    featurize dataset extract 35717cfd-336f-42d0-b2c2-850ca64bc2f2
    
    # 剪切文件到目标目录
    mv /home/featurize/data/tmp/v1.0-trainval_meta/* /home/featurize/data/nuscenes/v1.0-trainval/
    
    end_time=$(date +%s)
    echo "Time for first dataset:"
    time_elapsed $start_time $end_time

# ------------------------------------------------------------------------#
# 回到 tmp/nuscenes_test 目录
mkdir -p /home/featurize/data/tmp/nuscenes_test
cd /home/featurize/data/tmp/nuscenes_test

    start_time=$(date +%s)
    
    # 下载第二个数据集
    featurize dataset extract e0f18708-b871-42ed-9659-140077b94983
    
    # 剪切文件到目标目录
    mv /home/featurize/data/tmp/nuscenes_test/* /home/featurize/data/nuscenes_test/
    
    end_time=$(date +%s)
    echo "Time for second dataset:"
    time_elapsed $start_time $end_time

# ------------------------------------------------------------------------#
# 回到 tmp 目录
cd /home/featurize/data/tmp


    start_time=$(date +%s)
    
    # 下载第三个数据集
    featurize dataset extract 7c9beef0-b2e6-4582-96f6-d82b3db1e89f
    
    # 移动文件到目标目录
    mv /home/featurize/data/tmp/nuscenes-full/* /home/featurize/data/nuscenes/v1.0-trainval/
    
    end_time=$(date +%s)
    echo "Time for third dataset:"
    time_elapsed $start_time $end_time
# ------------------------------------------------------------------------#

echo "All datasets have been processed."
