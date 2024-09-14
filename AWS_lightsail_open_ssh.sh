#!/bin/bash

# 备份原始 sshd_config 文件
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# 修改 PermitRootLogin 行，去掉井号并设置为 PermitRootLogin yes
sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

# 修改 PasswordAuthentication 行，去掉井号并设置为 PasswordAuthentication yes
sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# 重启 SSH 服务以应用更改
systemctl restart sshd

echo "sshd_config 文件已修改并重启 SSH 服务。"
