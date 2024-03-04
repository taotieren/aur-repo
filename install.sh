#!/bin/bash

# Add repository configurations to /etc/pacman.conf
echo "
[aur-repo]
# Only IPv4
Server = http://home.taotieren.com:12380/$arch

# Only IPv6
Server = https://aur-repo.taotieren.com:12380/$arch
Server = http://aur-repo.taotieren.com:3443/$arch
" | sudo tee -a /etc/pacman.conf

# Add and trust GPG key
sudo pacman-key --recv-keys FEB77F0A6AB274FB0F0E5947B327911EA9E522AC
sudo pacman-key --lsign-key FEB77F0A6AB274FB0F0E5947B327911EA9E522AC

# Install xwm-git package
sudo pacman -S xwm-git
