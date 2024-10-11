#!/bin/bash

# 定义远程服务器信息和本地路径
REMOTE_HOST="152.67.96.205"
REMOTE_USER="root"
REMOTE_KEY_PATH="/root/jolly/.sshkeys/remote1.pub"
LOCAL_KEY_DIR="/root/.jolly/.sshkeys"
LOCAL_KEY_FILE="$LOCAL_KEY_DIR/remote1.pub"

# 检查系统是否支持 sudo，如果支持则使用 sudo，否则使用普通权限
if command -v sudo &> /dev/null; then
  SUDO_CMD="sudo"
else
  SUDO_CMD=""
fi

# 创建本地密钥存储目录
echo "创建本地密钥存储目录：$LOCAL_KEY_DIR"
$SUDO_CMD mkdir -p "$LOCAL_KEY_DIR"

# 从远程服务器 SCP 公钥到本地
echo "从远程服务器 $REMOTE_HOST 获取公钥文件..."
# 使用 'StrictHostKeyChecking=no' 自动接受首次连接时的认证提示，并进行 SCP 传输
$SUDO_CMD scp -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST:$REMOTE_KEY_PATH" "$LOCAL_KEY_FILE"

# 检查 SCP 操作是否成功
if [ $? -ne 0 ]; then
  echo "SCP 失败，请检查远程服务器路径或网络连接。"
  exit 1
fi

# 设置正确的权限
echo "修改本地公钥文件权限..."
$SUDO_CMD chmod 700 "$LOCAL_KEY_DIR"
$SUDO_CMD chmod 600 "$LOCAL_KEY_FILE"

# 修改 SSH 配置文件 /etc/ssh/sshd_config
SSH_CONFIG="/etc/ssh/sshd_config"
echo "修改 SSH 配置文件：$SSH_CONFIG"

# 检查并更新 AuthorizedKeysFile 配置
if grep -q "^AuthorizedKeysFile" "$SSH_CONFIG"; then
  echo "在 SSH 配置中找到 AuthorizedKeysFile 选项，插入新的公钥路径..."
  # 只保留一行 AuthorizedKeysFile，并在最前面插入新的路径（确保只有一个空格分隔）
  $SUDO_CMD sed -i "s|^AuthorizedKeysFile.*|AuthorizedKeysFile $LOCAL_KEY_FILE &|g" "$SSH_CONFIG"
else
  echo "未找到 AuthorizedKeysFile 选项，添加新行..."
  echo "AuthorizedKeysFile $LOCAL_KEY_FILE" | $SUDO_CMD tee -a "$SSH_CONFIG"
fi

# 启用密钥认证
if grep -q "^PubkeyAuthentication" "$SSH_CONFIG"; then
  echo "在 SSH 配置中找到 PubkeyAuthentication 选项，确保启用..."
  $SUDO_CMD sed -i "s|^PubkeyAuthentication.*|PubkeyAuthentication yes|g" "$SSH_CONFIG"
else
  echo "未找到 PubkeyAuthentication 选项，添加新行..."
  echo "PubkeyAuthentication yes" | $SUDO_CMD tee -a "$SSH_CONFIG"
fi

# 重启 SSH 服务
echo "重启 SSH 服务以应用新配置..."

# 选择重启 SSH 服务的方式
if $SUDO_CMD systemctl restart ssh 2>/dev/null; then
  echo "使用 systemctl 重启 SSH 服务成功！"
elif $SUDO_CMD service ssh restart 2>/dev/null; then
  echo "使用 service 重启 SSH 服务成功！"
else
  echo "无法使用 systemctl 或 service 重启 SSH 服务，请手动检查 SSH 服务状态。"
fi

# 最终提示
echo "SSH 配置已更新，密钥认证方式已启用！"
echo "你现在可以尝试使用密钥登录服务器。"
