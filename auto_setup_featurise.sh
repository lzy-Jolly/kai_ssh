#!/bin/bash

# Function to print time taken in human-readable format (HH:MM:SS)
function print_time_taken() {
    local start_time=$1
    local end_time=$2
    local step_name=$3
    local elapsed_time=$(echo "$end_time - $start_time" | bc)
    local hours=$(printf "%02d" $(echo "$elapsed_time/3600" | bc))
    local minutes=$(printf "%02d" $(echo "($elapsed_time%3600)/60" | bc))
    local seconds=$(printf "%02d" $(echo "$elapsed_time%60" | bc))
    echo "步骤 $step_name 执行耗时: ${hours}:${minutes}:${seconds}" | tee -a auto_featurize.log
}

# 开始记录日志
echo "开始执行自动化任务" > auto_featurize.log

# A: 创建目录并安装软件
start_time=$(date +%s.%N)
echo "A: 正在创建目录并安装所需软件..." | tee -a auto_featurize.log
sudo mkdir -p ~/data/nuscenes/v1.0-trainval
sudo apt update && sudo apt install -y nvtop tree pigz pv
end_time=$(date +%s.%N)
print_time_taken $start_time $end_time "A"

# B: 进入目录并逐行执行 featurize 操作，记录每次操作的时间
cd ~/data/nuscenes/v1.0-trainval
echo "B: 进入目录并逐行执行 featurize 操作..." | tee -a auto_featurize.log

declare -a featurize_commands=(
    "sudo featurize dataset extract 4ec7e5bb-e900-448c-a286-42a1039cb7ac"
    "sudo featurize dataset extract 8dfff36b-e9da-46fb-9386-3cb6d2b00fdd"
    "sudo featurize dataset extract f9b75b02-d3b0-4ea2-987a-e7b133ed3780"
    "sudo featurize dataset extract 636f14f1-a045-4fef-8b67-ef4e0f6fabf7"
    "sudo featurize dataset extract e0f18708-b871-42ed-9659-140077b94983"
)

for i in "${!featurize_commands[@]}"; do
    start_time=$(date +%s.%N)
    echo "B${i+1}: 执行 ${featurize_commands[$i]}..." | tee -a auto_featurize.log
    ${featurize_commands[$i]}
    end_time=$(date +%s.%N)
    print_time_taken $start_time $end_time "B${i+1}"
done

# C: 进入工作目录并加载镜像
start_time=$(date +%s.%N)
echo "C: 进入工作目录并加载 Docker 镜像..." | tee -a auto_featurize.log
cd ~/work
sudo docker load -i pcd.yes.tar
cp -r ~/work/nuscenes_loaded_pkl ~/data/
end_time=$(date +%s.%N)
print_time_taken $start_time $end_time "C"

# D: 运行 Docker 容器，并在容器中执行 Python 脚本
start_time=$(date +%s.%N)
echo "D: 正在运行 Docker 容器并执行 Python 脚本..." | tee -a auto_featurize.log
docker run \
--name cu115 \
--restart unless-stopped \
-e SDL_VIDEODRIVER=x11 \
-e DISPLAY=$DISPLAY \
--env='DISPLAY' \
--gpus all \
--ipc host \
--privileged \
-v /tmp/.X11-unix:/tmp/.X11-unix:rw \
-v /media/its:/mnt/data \
-v /home/featurize/data:/root/dataset \
lzyjolly/pcd_u20c11:1.6.yes \
/bin/bash -c "
    cd /root/pc-corrector && \
    python -m pcdet.datasets.nuscenes.nuscenes_dataset --func create_nuscenes_infos \
    --cfg_file tools/cfgs/dataset_configs/nuscenes_dataset.yaml \
    --version v1.0-trainval
"
# 不记录进入容器后的时间，因为可能无法获取
echo "进入 Docker 容器后执行了 Python 脚本。" | tee -a auto_featurize.log

echo "所有步骤已完成！" | tee -a auto_featurize.log




## -------------------------------------------------------------------------------
# #!/bin/bash

# # Function to print time taken
# function print_time_taken() {
#     local start_time=$1
#     local end_time=$2
#     local step_name=$3
#     local elapsed_time=$(echo "$end_time - $start_time" | bc)
#     echo "Step $step_name took: $elapsed_time seconds"
# }

# # A: 创建目录并安装软件
# start_time=$(date +%s.%N)
# mkdir -p ~/data/nuscenes/v1.0-trainval
# sudo apt update && sudo apt install -y nvtop tree pigz pv
# end_time=$(date +%s.%N)
# print_time_taken $start_time $end_time "A"

# # B: 进入目录并逐行执行 featurize 操作，记录每次操作的时间
# cd ~/data/nuscenes/v1.0-trainval

# declare -a featurize_commands=(
#     "featurize dataset extract 4ec7e5bb-e900-448c-a286-42a1039cb7ac"
#     "featurize dataset extract 8dfff36b-e9da-46fb-9386-3cb6d2b00fdd"
#     "featurize dataset extract f9b75b02-d3b0-4ea2-987a-e7b133ed3780"
#     "featurize dataset extract 636f14f1-a045-4fef-8b67-ef4e0f6fabf7"
#     "featurize dataset extract e0f18708-b871-42ed-9659-140077b94983"
# )

# for i in "${!featurize_commands[@]}"; do
#     start_time=$(date +%s.%N)
#     ${featurize_commands[$i]}
#     end_time=$(date +%s.%N)
#     print_time_taken $start_time $end_time "B${i+1}"
# done

# # C: 进入工作目录并加载镜像
# start_time=$(date +%s.%N)
# cd ~/work
# sudo docker load -i pcd.yes.tar
# cp -r ~/work/nuscenes_loaded_pkl ~/data/
# end_time=$(date +%s.%N)
# print_time_taken $start_time $end_time "C"

# # D: 运行 Docker 容器
# start_time=$(date +%s.%N)
# docker run -it \
# --name cu115 \
# --restart unless-stopped \
# -e SDL_VIDEODRIVER=x11 \
# -e DISPLAY=$DISPLAY \
# --env='DISPLAY' \
# --gpus all \
# --ipc host \
# --privileged \
# -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
# -v /media/its:/mnt/data \
# -v /home/featurize/data:/root/dataset \
# lzyjolly/pcd_u20c11:1.6.yes \
# /bin/bash
# end_time=$(date +%s.%N)
# print_time_taken $start_time $end_time "D"

# # E: 执行 Python 脚本创建 nuscenes 信息
# start_time=$(date +%s.%N)
# cd /root/pc-corrector
# python -m pcdet.datasets.nuscenes.nuscenes_dataset --func create_nuscenes_infos \
#     --cfg_file tools/cfgs/dataset_configs/nuscenes_dataset.yaml \
#     --version v1.0-trainval
# end_time=$(date +%s.%N)
# print_time_taken $start_time $end_time "E"

# echo "All steps completed!"
