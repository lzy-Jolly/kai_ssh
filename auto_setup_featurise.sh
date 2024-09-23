
#!/bin/bash

# 复制所有文件从 /home/featurize/work 到 /home/featurize
cp -r /home/featurize/work/* /home/featurize/

# 检查是否成功复制了 pcd_jolly_1.1.tar
if [ -f "/home/featurize/pcd_jolly_1.1.tar" ]; then
    echo "pcd_jolly_1.1.tar found. Loading into Docker..."
    # 加载 pcd_jolly_1.1.tar 文件到 Docker
    docker load -i /home/featurize/pcd_jolly_1.1.tar
    echo "Docker image loaded successfully."
else
    echo "Error: pcd_jolly_1.1.tar not found."
fi
