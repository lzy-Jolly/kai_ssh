# kai_ssh
open ssh for many online service

修改AWS的登录密码，可以直接复制下列代码在lightsail的ssh 终端执行，执行完成后输入'sudo -i' 登录超级管理员 再输入passwd可以直接登录文件
AWS

```sh
curl -fsSL https://raw.githubusercontent.com/lzy-Jolly/kai_ssh/main/AWS_lightsail_open_ssh.sh | sudo bash

```
也可以，打开"AWS_lightsail_open_ssh.sh"

用Root登入，用官方的ubuntu密钥对--暂时有bug不行，

```sh
curl -fsSL https://github.com/lzy-Jolly/kai_ssh/blob/main/AWS_lightsail_root_key_login.sh | sudo bash
```

```sh
curl -fsSL https://raw.githubusercontent.com/lzy-Jolly/kai_ssh/blob/main/AWS_lightsail_root_key_login.sh | sudo bash

```
### 下载安装docker，以及nvidia-docker
```sh
curl -fsSL https://raw.githubusercontent.com/lzy-Jolly/kai_ssh/refs/heads/main/istall_nvidia_docker.sh | sudo bash
```
### 用docker 部署alist
```sh
curl -fsSL https://raw.githubusercontent.com/lzy-Jolly/kai_ssh/refs/heads/main/docker-compose-alist.sh | sudo bash
```

### 国内clash下载地址
```sh
git clone https://gitee.com/lzy_jolly/script_repo.git
```
### jolly_ssh.sh
```sh
wget https://raw.githubusercontent.com/lzy-Jolly/kai_ssh/main/jolly_ssh.sh -O jolly_ssh.sh && sudo bash jolly_ssh.sh

```
```sh
curl -fsSL https://github.com/lzy-Jolly/kai_ssh/blob/main/main/jolly_ssh.sh | sudo bash
```

