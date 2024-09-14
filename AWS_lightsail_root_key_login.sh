#!/bin/bash

# 文件路径
AUTHORIZED_KEYS="/root/.ssh/authorized_keys"
LIGHTSAIL_KEY="/etc/ssh/lightsail_instance_ca.pub"

# 读取 Lightsail 的密钥内容
KEY_B=$(cat "$LIGHTSAIL_KEY")

# 备份 authorized_keys 文件
cp "$AUTHORIZED_KEYS" "$AUTHORIZED_KEYS.bak"

# 查找 authorized_keys 文件的第一行并分离出 command 和第一串密钥A
FIRST_LINE=$(head -n 1 "$AUTHORIZED_KEYS")
COMMAND=$(echo "$FIRST_LINE" | grep -o 'command="[^"]*"')
KEY_A=$(echo "$FIRST_LINE" | sed -e "s/$COMMAND //")

# 将秘钥B插入到command和秘钥A之间
NEW_FIRST_LINE="$COMMAND $KEY_B $KEY_A"

# 用新行替换authorized_keys中的第一行
sed -i "1s/.*/$NEW_FIRST_LINE/" "$AUTHORIZED_KEYS"

echo "秘钥已成功插入到 authorized_keys 的第一行"
