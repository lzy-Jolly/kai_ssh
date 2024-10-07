#!/bin/bash

# 退出时，如果有任何命令失败，则退出脚本
set -e

# 检查是否安装了 conda
if ! command -v conda &> /dev/null
then
    echo "未找到 conda，请先安装 Anaconda 或 Miniconda。"
    exit
fi

# 创建 conda 环境 cu116
echo "正在创建 conda 环境 cu116..."
conda create -n cu116 python=3.8 -y

# 激活 conda 环境
echo "正在激活 conda 环境 cu116..."
source $(conda info --base)/etc/profile.d/conda.sh
conda activate cu116

# 更新 apt 并安装依赖项
echo "正在更新 apt 并安装依赖项..."
sudo apt-get update

sudo apt-get install -y \
    git zip unzip libssl-dev libcairo2-dev lsb-release libgoogle-glog-dev libgflags-dev libatlas-base-dev libeigen3-dev software-properties-common \
    build-essential cmake pkg-config libapr1-dev autoconf automake libtool curl libc6 libboost-all-dev debconf libomp5 libstdc++6 \
    libqt5core5a libqt5xml5 libqt5gui5 libqt5widgets5 libqt5concurrent5 libqt5opengl5 libcap2 libusb-1.0-0 libatk-adaptor neovim \
    python3-pip python3-tornado python3-dev python3-numpy python3-virtualenv libpcl-dev libsuitesparse-dev python3-pcl pcl-tools \
    libgtk2.0-dev libavcodec-dev libavformat-dev libswscale-dev libtbb2 libtbb-dev libjpeg-dev libpng-dev libtiff-dev libdc1394-22-dev \
    xfce4-terminal tmux tree rsync

sudo rm -rf /var/lib/apt/lists/*

# 设置 pip 使用国内镜像源（清华大学）
echo "正在配置 pip 使用清华大学镜像源..."
mkdir -p ~/.pip
echo "[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
" > ~/.pip/pip.conf

# 构建并安装带 CUDA 支持的 OpenCV
echo "正在构建并安装带 CUDA 支持的 OpenCV..."
mkdir ~/opencv_build && cd ~/opencv_build

# 克隆 OpenCV 4.2.0 和 opencv_contrib
git clone https://github.com/opencv/opencv.git -b 4.2.0
git clone https://github.com/opencv/opencv_contrib.git -b 4.2.0

# 应用修复以确保 CUDA 支持
mkdir opencvfix && cd opencvfix
git clone https://github.com/opencv/opencv.git -b 4.5.2
cd opencv/cmake
cp -r FindCUDA ~/opencv_build/opencv/cmake/
cp FindCUDA.cmake ~/opencv_build/opencv/cmake/
cp FindCUDNN.cmake ~/opencv_build/opencv/cmake/
cp OpenCVDetectCUDA.cmake ~/opencv_build/opencv/cmake/

# 创建构建目录并进入
cd ~/opencv_build/opencv
mkdir build && cd build

# 获取 Python 路径
PYTHON3_EXECUTABLE=$(which python)
PYTHON3_INCLUDE_DIR=$(python -c "from distutils.sysconfig import get_python_inc(); print(get_python_inc())")
PYTHON3_PACKAGES_PATH=$(python -c "from distutils.sysconfig import get_python_lib(); print(get_python_lib())")

# 运行 cmake
cmake -D CMAKE_BUILD_TYPE=RELEASE \
    -D CMAKE_INSTALL_PREFIX=/usr/local \
    -D OPENCV_GENERATE_PKGCONFIG=ON \
    -D BUILD_EXAMPLES=OFF \
    -D INSTALL_PYTHON_EXAMPLES=OFF \
    -D INSTALL_C_EXAMPLES=OFF \
    -D PYTHON3_EXECUTABLE=$PYTHON3_EXECUTABLE \
    -D PYTHON3_INCLUDE_DIR=$PYTHON3_INCLUDE_DIR \
    -D PYTHON3_PACKAGES_PATH=$PYTHON3_PACKAGES_PATH \
    -D BUILD_opencv_python3=ON \
    -D OPENCV_EXTRA_MODULES_PATH=../../opencv_contrib/modules/ \
    -D WITH_GSTREAMER=ON \
    -D WITH_CUDA=ON \
    -D ENABLE_PRECOMPILED_HEADERS=OFF \
    ..

# 编译并安装 OpenCV
make -j$(nproc)
sudo make install
sudo ldconfig

# 清理
cd ~
rm -rf ~/opencv_build

# 设置 OpenCV_DIR 环境变量
export OpenCV_DIR=/usr/local/share/OpenCV

# 安装 PyTorch（CUDA 11.6）
echo "正在安装 PyTorch 1.13.1+cu116..."
pip install torch==1.13.1+cu116 torchvision==0.14.1+cu116 torchaudio==0.13.1 --extra-index-url https://download.pytorch.org/whl/cu116

# 安装其他 Python 包
echo "正在安装其他 Python 包..."
pip install numpy==1.23.0 llvmlite numba tensorboardX easydict pyyaml scikit-image tqdm SharedArray open3d mayavi av2 kornia==0.6.5 pyquaternion

# 安装 spconv 和 nuscenes-devkit
pip install spconv-cu116 nuscenes-devkit==1.0.5

# 安装其他工具包
pip install python-git-info einops torchmetrics==0.9 torch_scatter

# 清理 pip 缓存
pip cache purge

# 克隆 OpenPCDet 并设置
echo "正在克隆并设置 OpenPCDet..."
git clone https://github.com/open-mmlab/OpenPCDet.git ~/OpenPCDet

cd ~/OpenPCDet

# 安装 OpenPCDet
python setup.py develop

# 创建 python 链接（如果需要）
sudo ln -s /usr/bin/python3 /usr/bin/python || true

# 设置环境变量
export NVIDIA_VISIBLE_DEVICES="all"
export NVIDIA_DRIVER_CAPABILITIES="video,compute,utility,graphics"
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/lib:/usr/lib:/usr/local/lib
export QT_GRAPHICSSYSTEM="native"

echo "环境安装完成！"

