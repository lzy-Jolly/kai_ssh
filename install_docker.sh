#!/bin/bash

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

# 启用并重启Docker服务
sudo systemctl enable docker
sudo systemctl restart docker

echo "Docker安装完成。"
