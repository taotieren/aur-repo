#!/bin/bash
URI_TO_OPEN="$1"

# snapd-xdg-open 和 flatpak-xdg-open 在此处都有使用
# 一个是为了打开链接，一个是为了使用本地图片查看器打开本地图片
# 请不要因为你认为依赖重复就把软件包标记为过期

# 2024.04.13 Update: 现在 flatpak-xdg-open 可以打开链接了
# 但是反应极其迟缓，点击链接之后需要等待大概半分钟才能打开
# 因此，snapd-xdg-open 依赖仍然保留

if ! [ "${URI_TO_OPEN:0:8}" == "jsbridge" ]; then
    if [ "${URI_TO_OPEN:0:4}" == "http" ]; then
        /snapd-xdg-open "$URI_TO_OPEN"
    else
        /flatpak-xdg-open "$URI_TO_OPEN"
    fi
fi
