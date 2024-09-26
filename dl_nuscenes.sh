#!/bin/bash

# 定义函数来显示时间差并转换为小时:分钟:秒格式
time_elapsed() {
    elapsed=$1
    hours=$(( elapsed / 3600 ))
    minutes=$(( (elapsed % 3600) / 60 ))
    seconds=$(( elapsed % 60 ))
    printf "Elapsed time: %02d:%02d:%02d\n" $hours $minutes $seconds
}

# 记录整个脚本的开始时间
total_start_time=$(date +%s)

# 创建目录并进入
mkdir -p /home/featurize/data/tmp
mkdir -p /home/featurize/data/tmp/v1.0-trainval_meta/
cd /home/featurize/data/tmp

start_time=$(date +%s)

# 下载第一个数据集v1.0-trainval_meta
featurize dataset extract 35717cfd-336f-42d0-b2c2-850ca64bc2f2

# 剪切文件到目标目录
mv /home/featurize/data/tmp/v1.0-trainval_meta/* /home/featurize/data/nuscenes/v1.0-trainval/

end_time=$(date +%s)
elapsed=$(( end_time - start_time ))
echo "Time for first dataset:"
time_elapsed $elapsed

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
elapsed=$(( end_time - start_time ))
echo "Time for second dataset:"
time_elapsed $elapsed

# ------------------------------------------------------------------------#
# 回到 tmp 目录
cd /home/featurize/data/tmp

start_time=$(date +%s)

# 下载第三个数据集
featurize dataset extract 7c9beef0-b2e6-4582-96f6-d82b3db1e89f

# 移动文件到目标目录
mv /home/featurize/data/tmp/nuscenes-full/* /home/featurize/data/nuscenes/v1.0-trainval/

end_time=$(date +%s)
elapsed=$(( end_time - start_time ))
echo "Time for third dataset:"
time_elapsed $elapsed

# ------------------------------------------------------------------------#
# 计算并输出总的运行时间
total_end_time=$(date +%s)
total_elapsed=$(( total_end_time - total_start_time ))

echo "Total time for all datasets:"
time_elapsed $total_elapsed

echo "All datasets have been processed."

# 重定向所有输出到 dl_nuscenes.log 文件
} | tee dl_nuscenes.log
