#!/bin/bash

# 备份原始 sshd_config 文件
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# 修改 PermitRootLogin 行，去掉井号并设置为 PermitRootLogin yes
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

# 修改 PasswordAuthentication 行，去掉井号并设置为 PasswordAuthentication yes
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# 查找 /etc/ssh/sshd_config.d 文件夹中以 cloudimg-settings.conf 结尾的文件，并修改 PasswordAuthentication no 为 PasswordAuthentication yes
for conf_file in /etc/ssh/sshd_config.d/*cloudimg-settings.conf; do
    if [ -f "$conf_file" ]; then
        sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' "$conf_file"
        echo "$conf_file 中的 PasswordAuthentication 已修改为 yes"
    fi
done

# 重启 SSH 服务以应用更改
systemctl restart sshd

echo "sshd_config 文件已修改并重启 SSH 服务。"
echo "请用  sudo -i 进入root账户"
echo "再用  passwd 重置密码"
