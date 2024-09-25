#!/bin/bash

alias cpl="rsync -avzP "
alias sdpcd="docker start pcd"
alias bspcd="docker exec -it pcd /bin/bash"
alias jy="tar -xvzf"

# 立即使修改生效
source ~/.bashrc
echo "All aliases added and bashrc reloaded!"
