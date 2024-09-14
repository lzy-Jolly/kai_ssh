#!/bin/bash

# 显示操作选项
echo "请选择操作："
echo "0 - 同时开启 root SSH 登录并将当前 ubuntu 用户的密钥对添加到 root 用户的密钥对"
echo "1 - 单独修改开启 root SSH 登录"
echo "2 - 单独将当前 ubuntu 用户的密钥对添加到 root 用户的密钥对"
echo "4 - 还原 /etc/ssh/sshd_config.bak 文件"
read -p "输入操作编号: " operation

case $operation in
    0)
        echo "操作 0: 同时开启 root SSH 登录并将 ubuntu 用户的密钥对添加到 root 用户的密钥对"

        # 备份原始 sshd_config 文件
        cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

        # 修改 PermitRootLogin 行，去掉井号并设置为 PermitRootLogin yes
        sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

        # 修改 PasswordAuthentication 行，去掉井号并设置为 PasswordAuthentication yes
        sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

        # 将当前 ubuntu 用户的公钥添加到 root 的 authorized_keys 文件中
        if ! sudo grep -q "$(cat ~/.ssh/authorized_keys)" /root/.ssh/authorized_keys; then
            sudo cat ~/.ssh/authorized_keys >> /root/.ssh/authorized_keys
            echo "ubuntu 用户的公钥已成功添加到 root 的 authorized_keys 文件中。"
        else
            echo "ubuntu 用户的公钥已存在于 root 的 authorized_keys 文件中。"
        fi

        # 重启 SSH 服务以应用更改
        systemctl restart sshd
        echo "root SSH 登录已启用，并重启 SSH 服务。"
        ;;

    1)
        echo "操作 1: 单独修改开启 root SSH 登录"

        # 备份原始 sshd_config 文件
        cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

        # 修改 PermitRootLogin 行，去掉井号并设置为 PermitRootLogin yes
        sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

        # 修改 PasswordAuthentication 行，去掉井号并设置为 PasswordAuthentication yes
        sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

        # 重启 SSH 服务以应用更改
        systemctl restart sshd
        echo "root SSH 登录已启用，并重启 SSH 服务。"
        ;;

    2)
        echo "操作 2: 单独将 ubuntu 用户的公钥添加到 root 用户的密钥对"

        # 将当前 ubuntu 用户的公钥添加到 root 的 authorized_keys 文件中
        if ! sudo grep -q "$(cat ~/.ssh/authorized_keys)" /root/.ssh/authorized_keys; then
            sudo cat ~/.ssh/authorized_keys >> /root/.ssh/authorized_keys
            echo "ubuntu 用户的公钥已成功添加到 root 的 authorized_keys 文件中。"
        else
            echo "ubuntu 用户的公钥已存在于 root 的 authorized_keys 文件中。"
        fi
        ;;

    4)
        echo "操作 4: 还原 /etc/ssh/sshd_config.bak 文件"

        # 还原备份的 sshd_config 文件
        if [ -f /etc/ssh/sshd_config.bak ]; then
            cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
            echo "/etc/ssh/sshd_config 文件已还原。"
            # 重启 SSH 服务以应用更改
            systemctl restart sshd
            echo "SSH 服务已重启。"
        else
            echo "备份文件 /etc/ssh/sshd_config.bak 不存在，无法还原。"
        fi
        ;;

    *)
        echo "无效的操作编号，请输入 0, 1, 2 或 4。"
        ;;
esac
