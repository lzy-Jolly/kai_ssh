#!/bin/bash

# 在当前目录创建或覆盖alist.yml文件，并写入内容
cat <<EOF > alist.yml
services:
    alist:
        image: 'xhofe/alist:latest'
        container_name: alist
        volumes:
            - '/etc/alist:/opt/alist/data'
            - '/root/jolly/dockerD/alist-data:/database' 
        ports:
            - '5233:5244'
        environment:
            - PUID=0
            - PGID=0
            - UMASK=022
        restart: unless-stopped
EOF

# 使用docker-compose启动alist服务
docker-compose -f alist.yml up -d

# 输出结果信息
echo "端口映射为 - '5233:5244'"
echo "卷映射 - '/root/jolly/dockerD/alist-data:/database'"
