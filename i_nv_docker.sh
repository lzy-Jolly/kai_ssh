#!/bin/bash
# update a script for ubuntu22 auto install docker
# 自动安装docker脚本，并安装nvidia-docker。
# 注意！需要有良好的外网环境，教程来自下列两个网址
# https://docs.docker.com/engine/install/ubuntu/
# https://blog.csdn.net/qq_41776453/article/details/129794608


# 移除已有的Docker相关软件包
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do 
    sudo apt remove -y $pkg
done

# 更新系统并安装必要的依赖
sudo apt update
sudo apt install -y ca-certificates curl

# 添加Docker官方的GPG密钥
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# 将Docker仓库添加到Apt源
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 更新Apt并安装Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 检查NVIDIA驱动
nvidia-smi
if [ $? -ne 0 ]; then
    echo "NVIDIA驱动未正确安装，请检查驱动安装。"
    exit 1
fi

# 显示NVIDIA驱动安装检查信息和倒计时
echo "检查NVIDIA驱动安装是否正确，5秒后继续安装nvidia-docker"
countdown=5

# 处理ESC按键的操作
trap "echo '安装完成，跳过nvidia-docker安装'; sudo systemctl enable docker; sudo systemctl restart docker; exit 0" ESC

# 开始倒计时
while [ $countdown -gt 0 ]; do
    echo -n "倒计时 $countdown 秒... 按任意键暂停。"
    
    # 等待 1 秒，期间检测是否有键盘输入
    read -t 1 -n 1 input
    if [ $? -eq 0 ]; then
        echo -e "\n倒计时已暂停。按回车继续安装nvidia-docker，按ESC跳过并完成安装。"
        read -s -n 1 -r key  # 捕获按键，等待用户选择

        if [[ $key == $'\e' ]]; then
            echo "跳过nvidia-docker安装，完成Docker设置。"
            sudo systemctl enable docker
            sudo systemctl restart docker
            exit 0
        else
            echo "继续安装nvidia-docker..."
            break
        fi
    fi
    
    countdown=$((countdown - 1))
done

if [ $countdown -eq 0 ]; then
    echo "跳过nvidia-docker安装，完成Docker设置。"
    sudo systemctl enable docker
    sudo systemctl restart docker
    exit 0
fi

# 添加NVIDIA Docker GPG密钥及仓库
distribution=$(. /
