#!/bin/bash
# cp_same_file_and_back.sh -folderA -folderB -comm.txt
# 文件comm.txt中列出了一些列子文件，请在A中寻找并将其复制到B对应位置的，并将被覆盖的源文件保存末尾加上.b作为备份。
# 检查输入参数是否正确
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 -folderA -folderB -comm.txt"
    exit 1
fi

folderA=$1
folderB=$2
comm_file=$3

# 检查文件是否存在
if [ ! -d "$folderA" ] || [ ! -d "$folderB" ] || [ ! -f "$comm_file" ]; then
    echo "Folder or file does not exist!"
    exit 1
fi

# 读取 comm.txt 中的文件路径列表
while IFS= read -r file_path; do
    src_file="$folderA/$file_path"
    dest_file="$folderB/$file_path"

    # 检查源文件是否存在
    if [ -f "$src_file" ]; then
        # 创建目标目录
        mkdir -p "$(dirname "$dest_file")"

        # 如果目标文件存在，则进行备份
        if [ -f "$dest_file" ]; then
            cp "$dest_file" "$dest_file.b"
        fi

        # 复制源文件到目标文件
        cp "$src_file" "$dest_file"
        echo "Copied $src_file to $dest_file"
    else
        echo "Source file $src_file does not exist!"
    fi
done < "$comm_file"
