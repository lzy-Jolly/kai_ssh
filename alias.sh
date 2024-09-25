#!/bin/bash

# 检查别名是否已经存在，避免重复添加
if ! grep -q "alias Cpl=" ~/.bashrc; then
    echo "alias Cpl='rsync -avzP'" >> ~/.bashrc
    echo "Added alias Cpl to ~/.bashrc"
fi

if ! grep -q "alias sdpcd=" ~/.bashrc; then
    echo "alias sdpcd='docker start pcd'" >> ~/.bashrc
    echo "Added alias sdpcd to ~/.bashrc"
fi

if ! grep -q "alias bspcd=" ~/.bashrc; then
    echo "alias bspcd='docker exec -it pcd /bin/bash'" >> ~/.bashrc
    echo "Added alias bspcd to ~/.bashrc"
fi

if ! grep -q "alias jy=" ~/.bashrc; then
    echo "alias jy='tar -xvzf'" >> ~/.bashrc
    echo "Added alias jy to ~/.bashrc"
fi

# 立即使修改生效
source ~/.bashrc
echo "All aliases added and bashrc reloaded!"
