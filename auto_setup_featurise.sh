#!/bin/bash

# 定义函数来记录执行时间
execute_and_time() {
    local start_time=$(date +%s)
    echo "开始执行: $1"
    eval "$1"
    local end_time=$(date +%s)
    local elapsed_time=$((end_time - start_time))
    echo "执行完成: $1, 耗时: $elapsed_time 秒"
}

# 执行A
cmd_A="mkdir -p ~/data/nuscenes/v1.0-trainval && sudo apt update && sudo apt install -y nvtop tree pigz pv"
execute_and_time "$cmd_A" &  # 使用 & 后台执行

# 执行B
cmd_B="cd ~/data/nuscenes/v1.0-trainval && featurize dataset extract 4ec7e5bb-e900-448c-a286-42a1039cb7ac && \
featurize dataset extract 8dfff36b-e9da-46fb-9386-3cb6d2b00fdd && \
featurize dataset extract f9b75b02-d3b0-4ea2-987a-e7b133ed3780 && \
featurize dataset extract 636f14f1-a045-4fef-8b67-ef4e0f6fabf7 && \
featurize dataset extract e0f18708-b871-42ed-9659-140077b94983"
execute_and_time "$cmd_B" &  # 使用 & 后台执行

# 执行C
cmd_C="cd ~/work && sudo docker load -i pcd.yes.tar && cp -r ~/work/nuscenes_loaded_pkl ~/data/"
execute_and_time "$cmd_C" &  # 使用 & 后台执行

# 等待A、B、C执行完
wait
echo "ABC全部执行完毕"

# # 执行D
# cmd_D="docker run -it --name cu115 --restart unless-stopped -e SDL_VIDEODRIVER=x11 -e DISPLAY=$DISPLAY \
# --env='DISPLAY' --gpus all --ipc host --privileged -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
# -v /media/its:/mnt/data -v /home/featurize/data:/root/dataset \
# lzyjolly/pcd_u20c11:1.6.yes /bin/bash"
# execute_and_time "$cmd_D"

# # 执行E
# cmd_E="cd /root/pc-corrector && python -m pcdet.datasets.nuscenes.nuscenes_dataset --func create_nuscenes_infos \
# --cfg_file tools/cfgs/dataset_configs/nuscenes_dataset.yaml --version v1.0-trainval"
# execute_and_time "$cmd_E"


cmd_D="docker run --name cu115 --restart unless-stopped -e SDL_VIDEODRIVER=x11 -e DISPLAY=$DISPLAY \
--env='DISPLAY' --gpus all --ipc host --privileged -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
-v /media/its:/mnt/data -v /home/featurize/data:/root/dataset \
lzyjolly/pcd_u20c11:1.6.yes /bin/bash -c 'echo Inside Docker && cd /root/pc-corrector && \
python -m pcdet.datasets.nuscenes.nuscenes_dataset --func create_nuscenes_infos \
--cfg_file tools/cfgs/dataset_configs/nuscenes_dataset.yaml --version v1.0-trainval && exit'"
execute_and_time "$cmd_D"

echo "所有步骤执行完毕"
