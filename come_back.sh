#!/bin/bash

# 检查输入参数是否为1个
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 backup_folder"
    exit 1
fi

# 定义备份文件夹
backup_folder="$1"

# 判断备份文件夹是否存在
if [ ! -d "$backup_folder" ]; then
    echo "Backup folder $backup_folder not found!"
    exit 1
fi

# 确定恢复的目标文件夹名称
target_folder="${backup_folder%.b}"

# 复制备份文件到原目录
cp -r "$backup_folder"/* "$target_folder"
echo "Restored $target_folder from $backup_folder"
