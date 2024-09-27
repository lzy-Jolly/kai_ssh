#!/bin/bash
# cp_same_file_and_back.sh -folderA -folderB -comm.txt
# 检查输入参数
if [[ $# -ne 3 ]]; then
  echo "Usage: $0 -folderA -folderB -comm.txt"
  exit 1
fi

folderA=$1
folderB=$2
commFile=$3

# 检查文件和文件夹是否存在
if [[ ! -d "$folderA" ]]; then
  echo "Error: Folder A ($folderA) does not exist!"
  exit 1
fi

if [[ ! -d "$folderB" ]]; then
  echo "Error: Folder B ($folderB) does not exist!"
  exit 1
fi

if [[ ! -f "$commFile" ]]; then
  echo "Error: Comm file ($commFile) does not exist!"
  exit 1
fi

# 创建备份文件夹并备份folderB
backupFolder="$folderB.b"
if [[ -d "$backupFolder" ]]; then
  echo "Warning: Backup folder ($backupFolder) already exists. Overwriting."
else
  cp -r "$folderB" "$backupFolder"
  echo "Backup folder ($backupFolder) created."
fi

# 读取 comm.txt 文件中的路径，并进行覆盖
while IFS= read -r line; do
  if [[ -f "$folderA/$line" ]]; then
    # 创建目标文件所在的文件夹路径
    targetDir=$(dirname "$folderB/$line")
    mkdir -p "$targetDir"

    # 将 A 文件夹中的文件复制到 B 中覆盖对应文件
    cp "$folderA/$line" "$folderB/$line"
    echo "Copied $folderA/$line to $folderB/$line"
  else
    echo "Warning: File $folderA/$line does not exist. Skipping."
  fi
done < "$commFile"

echo "All specified files have been copied from $folderA to $folderB."
