#!/bin/bash

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

function command_exists() {
    local command="$1"
    command -v "${command}" >/dev/null 2>&1
}

function warning() {
    all_off="$(tput sgr0)"
    bold="${all_off}$(tput bold)"
    blue="${bold}$(tput setaf 4)"
    yellow="${bold}$(tput setaf 3)"
    printf "${blue}==>${yellow}WARNING:${bold} $1${all_off}\n"
}

if [ "${QQ_FIX_MAC}" != 1 ]; then
    if [ -s "${XDG_CONFIG_HOME}/qq-fix-mac.conf" ]; then
        export QQ_FIX_MAC=1
    else
        if ip link show | grep -q "docker"; then
            export QQ_FIX_MAC=1
        fi
        if [ -n "$(ip tuntap)" ]; then
            export QQ_FIX_MAC=1
        fi
    fi
fi


if [ "${QQ_FIX_MAC}" == 1 ]; then
    if ! command_exists slirp4netns; then
        warning "slirp4netns 命令未找到，不使用 MAC 地址修复。"
        /opt/QQ/start_normal.sh
    elif ! command_exists socat; then
        warning "socat 命令未找到，不使用 MAC 地址修复。"
        /opt/QQ/start_normal.sh
    else
        echo "Starting QQ in fix MAC mode..."
        /opt/QQ/start_mac_fix.sh
    fi
else
    /opt/QQ/start_normal.sh
fi
