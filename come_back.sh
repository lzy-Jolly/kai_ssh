#!/bin/bash
# cp_same_file_and_back.sh -folderA -folderB -comm.txt
# 文件comm.txt中列出了一些列子文件，请在A中寻找并将其复制到B对应位置的，并将被覆盖的源文件保存末尾加上.b作为备份。

# come_back.sh -folderB -comm.txt 
# 将comm.txt列出的所有的子文件在B文件夹上述的.b文件还原去掉.b并覆盖原来的文件。
# 检查输入参数是否正确
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 -folderB -comm.txt"
    exit 1
fi

folderB=$1
comm_file=$2

# 检查文件是否存在
if [ ! -d "$folderB" ] || [ ! -f "$comm_file" ]; then
    echo "Folder or file does not exist!"
    exit 1
fi

# 读取 comm.txt 中的文件路径列表
while IFS= read -r file_path; do
    backup_file="$folderB/$file_path.b"
    dest_file="$folderB/$file_path"

    # 检查备份文件是否存在
    if [ -f "$backup_file" ]; then
        # 将备份文件还原并覆盖原文件
        mv "$backup_file" "$dest_file"
        echo "Restored $backup_file to $dest_file"
    else
        echo "Backup file $backup_file does not exist!"
    fi
done < "$comm_file"
