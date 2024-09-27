#!/bin/bash

# 检查输入参数是否为3个
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 folderA folderB comm.txt"
    exit 1
fi

# 定义输入的文件夹和文件，并去除末尾的斜杠
folderA=$(echo "$1" | sed 's:/*$::')
folderB=$(echo "$2" | sed 's:/*$::')
comm_file="$3"

# 创建 folderB 的备份文件夹 (去除斜杠后的名字)
backup_folder="${folderB}.b"

# 如果备份文件夹已经存在，则警告用户
if [ -d "$backup_folder" ]; then
    echo "Backup folder $backup_folder already exists. Aborting to avoid overwriting."
    exit 1
fi

# 复制 folderB 生成备份
cp -r "$folderB" "$backup_folder"

# 检查 comm.txt 是否存在
if [ ! -f "$comm_file" ]; then
    echo "File $comm_file not found!"
    exit 1
fi

# 遍历 comm.txt 中的所有文件路径
while IFS= read -r line || [[ -n "$line" ]]; do
    # 确定文件的相对路径
    src_file="$folderA/$line"
    dest_file="$folderB/$line"
    
    # 检查源文件是否存在
    if [ ! -f "$src_file" ]; then
        echo "Source file $src_file not found! Skipping."
        continue
    fi
    
    # 检查目标文件夹是否存在，不存在则创建
    dest_folder=$(dirname "$dest_file")
    if [ ! -d "$dest_folder" ]; then
        mkdir -p "$dest_folder"
    fi
    
    # 复制源文件到目标位置
    cp "$src_file" "$dest_file"
    echo "Copied $src_file to $dest_file"
done < "$comm_file"
