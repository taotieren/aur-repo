#!/bin/bash

# 将仓库配置添加到 /etc/pacman.conf
echo "
[aur-repo]
# IPv4 & IPv6
Server = https://aur-repo.taotieren.com:3443/aur-repo/\$arch
Server = https://fun.ie8.pub:2443/aur-repo/\$arch
Server = http://fun.ie8.pub:2442/aur-repo/\$arch

# Only IPv4 (When https is enabled, http returns the https address.)
# Server = http://home.taotieren.com:12380/aur-repo/\$arch

# Only IPv6 (When https is enabled, http returns the https address.)
# Server = http://aur-repo.taotieren.com:12380/aur-repo/\$arch
" | sudo tee -a /etc/pacman.conf

# 添加并信任 GPG 密钥
sudo pacman-key --recv-keys FEB77F0A6AB274FB0F0E5947B327911EA9E522AC
sudo pacman-key --lsign-key FEB77F0A6AB274FB0F0E5947B327911EA9E522AC

# 安装 xwm-git 软件包
# sudo pacman -S xwm-git

# 切换到目录 "aur-repo/aur-repo/xwm-git"
# cd aur-repo/aur-repo/xwm-git

# 运行构建命令，可能用于构建软件包
# extra-x86_64-build

# 使用 yay 安装构建好的软件包
# -U 表示升级或替换指定的软件包
# xwm-git*.zst 匹配所有以 "xwm-git" 开头并以 ".zst" 结尾的文件名
# yay -U xwm-git*.zst
