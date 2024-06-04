#!/bin/bash
# Source: https://alampy.com/2024/05/15/fix-mac-for-linux-qq/

trap 'kill $(jobs -p)' EXIT

echo $$ > "${INFO_FILE}"
echo "PID written."

# wait for the file to be deleted
while [ -f "${INFO_FILE}" ]; do
    sleep 0.01
done
# clear proxy settings
unset http_proxy
unset https_proxy
unset ftp_proxy
unset all_proxy
socat tcp-listen:94301,reuseaddr,fork tcp:127.0.0.1:4301 &
socat tcp-listen:94310,reuseaddr,fork tcp:127.0.0.1:4310 &
/opt/QQ/electron --no-proxy-server "$@"

# 移除无用崩溃报告和日志
# 如果需要向腾讯反馈 bug，请注释掉如下几行
rm -rf ${QQ_APP_DIR}/crash_files
touch ${QQ_APP_DIR}/crash_files
if [ -d "${QQ_APP_DIR}/log" ]; then
    rm -rf "${QQ_APP_DIR}/log"
fi
for nt_qq_userdata in "${QQ_APP_DIR}/nt_qq_"*; do
    if [ -d "${nt_qq_userdata}/log" ]; then
        rm -rf "${nt_qq_userdata}/log"
    fi
    if [ -d "${nt_qq_userdata}/log-cache" ]; then
        rm -rf "${nt_qq_userdata}/log-cache"
    fi
done
if [ -d "${QQ_APP_DIR}/Crashpad" ]; then
    rm -rf "${QQ_APP_DIR}/Crashpad"
fi

exit $?
