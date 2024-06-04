#!/bin/bash

QQ_HOTUPDATE_VERSION="__CURRENT_VER__"

function command_exists() {
    local command="$1"
    command -v "${command}" >/dev/null 2>&1
}

function show_error_dialog() {
    title="linuxqq-nt-bwrap"
    if command_exists kdialog; then
        kdialog --error "$1" --title "$title" --icon qq
    elif command_exists zenity; then
        zenity --error --title "$title" --icon-name qq --text "$1"
    else
        all_off="$(tput sgr0)"
        bold="${all_off}$(tput bold)"
        blue="${bold}$(tput setaf 4)"
        yellow="${bold}$(tput setaf 3)"
        printf "${blue}==>${yellow} ${bold} $1${all_off}\n"
    fi
}

# 进行必要文件的检查
if [ ! -e "/etc/localtime" ]; then
    show_error_dialog "/etc/localtime 未找到。\n请先设置系统时区。"
    exit 1
fi

USER_RUN_DIR="/run/user/$(id -u)"
XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
FONTCONFIG_HOME="${XDG_CONFIG_HOME}/fontconfig"
QQ_APP_DIR="${XDG_CONFIG_HOME}/QQ"
if [ -z "${QQ_DOWNLOAD_DIR}" ]; then
    if [ -z "${XDG_DOWNLOAD_DIR}" ]; then
        XDG_DOWNLOAD_DIR="$(xdg-user-dir DOWNLOAD)"
    fi
    QQ_DOWNLOAD_DIR="${XDG_DOWNLOAD_DIR:-$HOME/Downloads}"
fi

# 从 flags 文件中加载参数

set -euo pipefail

electron_flags_file="${XDG_CONFIG_HOME}/qq-electron-flags.conf"
declare -a electron_flags
if [[ -f "${electron_flags_file}" ]]; then
    mapfile -t ELECTRON_FLAGS_MAPFILE <"${electron_flags_file}"
fi
for line in "${ELECTRON_FLAGS_MAPFILE[@]}"; do
    if [[ ! "${line}" =~ ^[[:space:]]*#.* ]]; then
        electron_flags+=("${line}")
    fi
done

bwrap_flags_file="${XDG_CONFIG_HOME}/qq-bwrap-flags.conf"
declare -a bwrap_flags
if [[ -f "${bwrap_flags_file}" ]]; then
    while IFS= read -r line; do
        if [[ ! "${line}" =~ ^[[:space:]]*# ]] && [[ -n "${line}" ]]; then
            eval "expanded_line=\"$line\""
            read -ra parts <<< "$expanded_line"
            for part in "${parts[@]}"; do
                bwrap_flags+=("$part")
            done
        fi
    done < "${bwrap_flags_file}"
fi


# read the mac address from .qq_mac, if not exist, generate a random one
if [ -f "${QQ_APP_DIR}/.qq_mac" ]; then
    qq_mac=$(cat "${QQ_APP_DIR}/.qq_mac")
else
    qq_mac=00\:$(hexdump -n5 -e '/1 ":%02X"' /dev/random | sed s/^://g)
    echo $qq_mac > "${QQ_APP_DIR}/.qq_mac"
fi

QQ_HOTUPDATE_DIR="${QQ_APP_DIR}/versions"

# 在「下载」目录不存在的时候，自动使用 ~/Downloads
# 避免挂载整个 home
if [ "${QQ_DOWNLOAD_DIR%*/}" == "${HOME}" ]; then
    QQ_DOWNLOAD_DIR="${HOME}/Downloads"
fi

# 安装当前版本
HOTUPDATE_VERSION_DIR="${QQ_HOTUPDATE_DIR}/${QQ_HOTUPDATE_VERSION}"
install -d "${QQ_HOTUPDATE_DIR}"
if [ ! -d "${HOTUPDATE_VERSION_DIR}" ] && [ ! -L "${HOTUPDATE_VERSION_DIR}" ]; then
    ln -sfd "/opt/QQ/resources/app" "${HOTUPDATE_VERSION_DIR}"
fi

# 处理旧版本
rm -rf "${QQ_HOTUPDATE_DIR}/"**".zip"
is_hotupdated_version=0 # 正在运行的版本是否经过热更新？

find "${QQ_HOTUPDATE_DIR}/"*[-_]* -maxdepth 1 -type "d,l" | while read path; do
    this_version="$(basename "$path")"
    if [ "$(vercmp "${this_version}" "${QQ_HOTUPDATE_VERSION//_/-}")" -lt "0" ]; then
        # 这个版本小于当前版本，删除之
        echo "rm $this_version"
        rm -rf "$path"
    else
        is_hotupdated_version=1
    fi
done

if [ "$is_hotupdated_version" == "0" ]; then
    cp "/opt/QQ/workarounds/config.json" "${QQ_HOTUPDATE_DIR}/config.json"
fi

INFO_DIR=$(mktemp -d)
INFO_FILE=$INFO_DIR/info

bwrap --new-session --unshare-user-try --unshare-cgroup-try \
    --unshare-user \
    --uid "$(id -u)" --gid "$(id -g)" \
    --unshare-net \
    --cap-add CAP_NET_ADMIN,CAP_NET_RAW,CAP_SYS_ADMIN \
    --symlink usr/lib /lib \
    --symlink usr/lib64 /lib64 \
    --symlink usr/bin /bin \
    --ro-bind /usr /usr \
    --ro-bind /opt /opt \
    --ro-bind /opt/QQ/workarounds/xdg-open.sh /usr/bin/xdg-open \
    --ro-bind /usr/lib/snapd-xdg-open/xdg-open /snapd-xdg-open \
    --ro-bind /usr/lib/flatpak-xdg-utils/xdg-open /flatpak-xdg-open \
    --ro-bind /etc/machine-id /etc/machine-id \
    --dev-bind /dev /dev \
    --ro-bind /sys /sys \
    --ro-bind /etc/passwd /etc/passwd \
    --ro-bind /etc/nsswitch.conf /etc/nsswitch.conf \
    --ro-bind-try /run/systemd/userdb /run/systemd/userdb \
    --ro-bind /opt/QQ/workarounds/resolv.conf /etc/resolv.conf \
    --ro-bind /etc/localtime /etc/localtime \
    --proc /proc \
    --tmpfs "/sys/devices/virtual" \
    --dev-bind /run/dbus /run/dbus \
    --bind "${USER_RUN_DIR}" "${USER_RUN_DIR}" \
    --ro-bind-try /etc/fonts /etc/fonts \
    --dev-bind /tmp /tmp \
    --bind-try "${HOME}/.pki" "${HOME}/.pki" \
    --ro-bind-try "${XAUTHORITY}" "${XAUTHORITY}" \
    --bind-try "${QQ_DOWNLOAD_DIR}" "${QQ_DOWNLOAD_DIR}" \
    --setenv QQ_APP_DIR "${QQ_APP_DIR}" \
    --bind "${QQ_APP_DIR}" "${QQ_APP_DIR}" \
    --ro-bind-try "${FONTCONFIG_HOME}" "${FONTCONFIG_HOME}" \
    --ro-bind-try "${HOME}/.icons" "${HOME}/.icons" \
    --ro-bind-try "${HOME}/.local/share/.icons" "${HOME}/.local/share/.icons" \
    --ro-bind-try "${XDG_CONFIG_HOME}/gtk-3.0" "${XDG_CONFIG_HOME}/gtk-3.0" \
    --ro-bind-try "${XDG_CONFIG_HOME}/dconf" "${XDG_CONFIG_HOME}/dconf" \
    --ro-bind /etc/nsswitch.conf /etc/nsswitch.conf \
    --ro-bind /run/systemd/userdb/ /run/systemd/userdb/ \
    --setenv IBUS_USE_PORTAL 1 \
    --setenv QQNTIM_HOME "${QQ_APP_DIR}/QQNTim" \
    --setenv LITELOADERQQNT_PROFILE "${QQ_APP_DIR}/LiteLoaderQQNT" \
    --bind "${INFO_DIR}" "${INFO_DIR}" \
    --setenv INFO_FILE "${INFO_FILE}" \
    "${bwrap_flags[@]}" \
    /opt/QQ/start_inner.sh "${electron_flags[@]}" "$@" /opt/QQ/resources/app &

if [ "$?" -ne 0 ]; then
    rm "$INFO_FILE"
    echo "bwrap failed"
    exit 1
fi
while [ ! -s "$INFO_FILE" ]; do
    sleep 0.01
done

PID="$(cat "$INFO_FILE")"
echo "SubProcess PID: $PID"

SLIRP_API_SOCKET=$INFO_DIR/slirp.sock
slirp4netns --configure --mtu=65520 --disable-host-loopback --enable-ipv6 "$PID" eth0 --macaddress "$qq_mac" --api-socket "$SLIRP_API_SOCKET" &
SLIRP_PID=$!

while [ ! -S "$SLIRP_API_SOCKET" ]; do
    sleep 0.01
done

if [ "$?" -ne 0 ]; then
    echo "slirp4netns failed"
    kill "$PID"
    rm -rf "${INFO_DIR:?}"
    exit 1
fi
add_hostfwd() {
    local proto=$1
    local guest_port=$2
    shift 2
    local ports=("$@")
    for port in "${ports[@]}"; do
        result=$(echo -n "{\"execute\": \"add_hostfwd\", \"arguments\": {\"proto\": \"$proto\", \"host_addr\": \"127.0.0.1\", \"host_port\": $port, \"guest_port\": $guest_port}}" | socat UNIX-CONNECT:$SLIRP_API_SOCKET -)
        if [[ $result != *"error"* ]]; then
            echo "$proto forwarding setup on port $port"
            return 0
        fi
    done
    echo "Failed to setup $proto forwarding."
    return 1
}
https_ports=(4301 4303 4305 4307 4309)
http_ports=(4310 4308 4306 4304 4302)
add_hostfwd "tcp" 94301 "${https_ports[@]}"
add_hostfwd "tcp" 94310 "${http_ports[@]}"
rm "$INFO_FILE"
# 启动步骤结束
tail --pid="$PID" -f /dev/null
echo "Cleaning up..."
set +e
kill -TERM "$SLIRP_PID"
wait "$SLIRP_PID"
rm -rf "${INFO_DIR:?}"
exit 0
