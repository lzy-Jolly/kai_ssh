#!/bin/bash
# come_back.sh folderB.b
# 检查输入参数
if [[ $# -ne 1 ]]; then
  echo "Usage: $0 -folderB.b"
  exit 1
fi

backupFolder=$1

# 检查备份文件夹是否存在
if [[ ! -d "$backupFolder" ]]; then
  echo "Error: Backup folder ($backupFolder) does not exist!"
  exit 1
fi

# 提取原始文件夹路径
originalFolder="${backupFolder%.b}"

# 从备份文件夹中恢复文件
cp -r "$backupFolder/." "$originalFolder"
echo "Restored files from $backupFolder to $originalFolder."
