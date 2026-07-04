#!/bin/bash
#
# aur-repo & archlinuxcn 源管理脚本
# 智能管理 /etc/pacman.conf 中的 [archlinuxcn] 和 [aur-repo] 源配置
#
# 用法: sudo ./install.sh [命令]
#   install   安装所有源（archlinuxcn → aur-repo 依赖顺序）
#   remove    移除所有源
#   status    查看源状态
#   help      显示帮助
#

set -euo pipefail

# ==================== 全局配置 ====================

PACMAN_CONF="/etc/pacman.conf"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
section() { echo -e "\n${BOLD}${CYAN}══ $* ══${NC}"; }

# ==================== 通用工具函数 ====================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "请使用 sudo 运行此脚本"
        exit 1
    fi
}

confirm() {
    local prompt="$1"
    local default_yes="${2:-true}"
    if [[ "$default_yes" == "true" ]]; then
        echo -e "${CYAN}${prompt} [Y/n]${NC}"
    else
        echo -e "${CYAN}${prompt} [y/N]${NC}"
    fi
    read -r response
    response="${response,,}"
    if [[ "$default_yes" == "true" ]]; then
        [[ -z "$response" || "$response" == "y" || "$response" == "yes" ]]
    else
        [[ "$response" == "y" || "$response" == "yes" ]]
    fi
}

pkg_installed() {
    pacman -Qi "$1" &>/dev/null
}

gpg_key_trusted() {
    pacman-key --list-keys "$1" &>/dev/null
}

# 在 pacman.conf 中查找指定 repo section 的起始行号
find_repo_line() {
    local repo_name="$1"
    grep -n "^\[${repo_name}\]" "$PACMAN_CONF" 2>/dev/null | head -1 | cut -d: -f1
}

# 检查 repo 是否存在于 pacman.conf
repo_in_conf() {
    local repo_name="$1"
    grep -q "^\[${repo_name}\]" "$PACMAN_CONF" 2>/dev/null
}

# 从 pacman.conf 中移除指定 repo 的整个段落
remove_repo_from_conf() {
    local repo_name="$1"
    local start_line
    start_line=$(find_repo_line "$repo_name")

    if [[ -z "$start_line" ]]; then
        warn "pacman.conf 中未找到 [${repo_name}] 配置"
        return 0
    fi

    local total_lines
    total_lines=$(wc -l < "$PACMAN_CONF")
    local end_line=$total_lines

    # 找到段落结尾（下一个 [section] 之前）
    local i
    for ((i = start_line + 1; i <= total_lines; i++)); do
        local line
        line=$(sed -n "${i}p" "$PACMAN_CONF")
        if [[ "$line" =~ ^\[.+ ]]; then
            end_line=$((i - 1))
            break
        fi
    done

    # 清理尾部空行
    while ((end_line > start_line)); do
        local line
        line=$(sed -n "${end_line}p" "$PACMAN_CONF")
        [[ -z "$line" ]] && ((end_line--)) || break
    done

    # 清理前导空行
    local clean_start=$start_line
    while ((clean_start > 1)); do
        local prev_line
        prev_line=$(sed -n "$((clean_start - 1))p" "$PACMAN_CONF")
        [[ -z "$prev_line" ]] && ((clean_start--)) || break
    done

    sed -i "${clean_start},${end_line}d" "$PACMAN_CONF"
    info "已从 pacman.conf 移除 [${repo_name}] 配置"
}

# 向 pacman.conf 追加 repo 配置（Include 方式）
add_repo_to_conf() {
    local repo_name="$1"
    local mirrorlist_path="$2"

    if repo_in_conf "$repo_name"; then
        warn "pacman.conf 中已存在 [${repo_name}]，跳过添加"
        return 0
    fi

    # 确保文件末尾有换行分隔
    local last_char
    last_char=$(tail -c1 "$PACMAN_CONF" 2>/dev/null || true)
    if [[ -n "$last_char" ]]; then
        echo "" >> "$PACMAN_CONF"
    fi

    cat >> "$PACMAN_CONF" <<EOF

[${repo_name}]
Include = ${mirrorlist_path}
EOF
    info "已将 [${repo_name}] 添加到 pacman.conf"
}

# 获取 repo 段落中第一个非注释非空行的内容
get_repo_first_directive() {
    local repo_name="$1"
    local start_line
    start_line=$(find_repo_line "$repo_name")
    [[ -z "$start_line" ]] && return 1

    local total_lines
    total_lines=$(wc -l < "$PACMAN_CONF")
    local i
    for ((i = start_line + 1; i <= total_lines; i++)); do
        local line
        line=$(sed -n "${i}p" "$PACMAN_CONF")
        # 跳过空行和纯注释行
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        # 遇到新 section 停止
        [[ "$line" =~ ^\[.+ ]] && return 1
        echo "$line"
        return 0
    done
    return 1
}

# 检查 repo 是否使用 Include 方式配置
repo_uses_include() {
    local repo_name="$1"
    local mirrorlist_path="$2"
    local directive
    directive=$(get_repo_first_directive "$repo_name") || return 1
    [[ "$directive" == *"Include = ${mirrorlist_path}"* ]]
}

# ==================== 源定义（数据驱动） ====================

# 每个 keyring 包通过首次临时 Server 添加后安装
# 定义格式: repo_name|mirrorlist_path|mirrorlist_pkg|keyring_pkg|keyring_key|extra_pkgs

ARCHLINUXCN_REPO="archlinuxcn"
ARCHLINUXCN_MIRRORLIST="/etc/pacman.d/archlinuxcn-mirrorlist"
ARCHLINUXCN_MIRRORLIST_PKG="archlinuxcn-mirrorlist-git"
ARCHLINUXCN_KEYRING_PKG="archlinuxcn-keyring"
ARCHLINUXCN_EXTRA_PKGS=""

AUR_REPO="aur-repo"
AUR_MIRRORLIST="/etc/pacman.d/aur-repo-mirrorlist"
AUR_MIRRORLIST_PKG="aur-repo-mirrorlist-git"
AUR_KEYRING_KEY="FEB77F0A6AB274FB0F0E5947B327911EA9E522AC"
AUR_EXTRA_PKGS="devtools-aur-repo-git"

# ==================== archlinuxcn 源处理 ====================

# 创建 archlinuxcn 临时 mirrorlist（仅含主服务器，用于安装 keyring）
create_archlinuxcn_bootstrap_mirrorlist() {
    mkdir -p /etc/pacman.d
    if [[ -f "$ARCHLINUXCN_MIRRORLIST" ]]; then
        # 备份已有 mirrorlist
        cp "$ARCHLINUXCN_MIRRORLIST" "${ARCHLINUXCN_MIRRORLIST}.bak"
        info "已备份原有 mirrorlist → ${ARCHLINUXCN_MIRRORLIST}.bak"
    fi
    cat > "$ARCHLINUXCN_MIRRORLIST" <<'EOF'
# archlinuxcn mirrorlist (bootstrap)
# 安装 archlinuxcn-mirrorlist-git 包后将自动更新此文件

## Our main server (Amsterdam, the Netherlands) (ipv4, ipv6, http, https)
Server = https://repo.archlinuxcn.org/$arch
EOF
    info "已创建 archlinuxcn bootstrap mirrorlist"
}

# 创建 archlinuxcn 完整 mirrorlist（包含常用中国镜像）
create_archlinuxcn_full_mirrorlist() {
    mkdir -p /etc/pacman.d
    cat > "$ARCHLINUXCN_MIRRORLIST" <<'EOF'
# archlinuxcn mirrorlist
# 安装 archlinuxcn-mirrorlist-git 包可自动更新此文件
# 取消注释您偏好的镜像源

## Our main server (Amsterdam, the Netherlands) (ipv4, ipv6, http, https)
Server = https://repo.archlinuxcn.org/$arch

## CERNET (中国) (ipv4, ipv6, http, https) - 自动重定向到最近的教育网镜像
Server = https://mirrors.cernet.edu.cn/archlinuxcn/$arch

## 腾讯云 (Global CDN) (ipv4, ipv6, http, https)
#Server = https://mirrors.cloud.tencent.com/archlinuxcn/$arch

## 阿里云 (Global CDN) (ipv4, http, https)
#Server = https://mirrors.aliyun.com/archlinuxcn/$arch

## 清华大学 (北京) (ipv4, ipv6, http, https)
#Server = https://mirrors.tuna.tsinghua.edu.cn/archlinuxcn/$arch

## 中国科学技术大学 (安徽合肥) (ipv4, ipv6, http, https)
#Server = https://mirrors.ustc.edu.cn/archlinuxcn/$arch

## 北京外国语大学 (北京) (ipv4, ipv6, http, https)
#Server = https://mirrors.bfsu.edu.cn/archlinuxcn/$arch

## 北京大学 (北京) (ipv4, ipv6, http, https)
#Server = https://mirrors.pku.edu.cn/archlinuxcn/$arch

## 浙江大学 (浙江杭州) (ipv4, ipv6, http, https)
#Server = https://mirrors.zju.edu.cn/archlinuxcn/$arch

## 上海交通大学 (上海) (ipv4, ipv6, https)
#Server = https://mirror.sjtu.edu.cn/archlinux-cn/$arch

## 南京大学 (江苏南京) (ipv4, ipv6, http, https)
#Server = https://mirrors.nju.edu.cn/archlinuxcn/$arch

## 南方科技大学 (广东深圳) (ipv4, ipv6, http, https)
#Server = https://mirrors.sustech.edu.cn/archlinuxcn/$arch

## 哈尔滨工业大学 (黑龙江哈尔滨) (ipv4, ipv6, http, https)
#Server = https://mirrors.hit.edu.cn/archlinuxcn/$arch

## 华中科技大学 (湖北武汉) (ipv4, ipv6, http, https)
#Server = https://mirrors.hust.edu.cn/archlinuxcn/$arch

## 网易 (China CDN) (ipv4, http, https)
#Server = https://mirrors.163.com/archlinux-cn/$arch
EOF
    info "已创建 archlinuxcn 完整 mirrorlist"
}

setup_archlinuxcn() {
    section "配置 archlinuxcn 源"

    # 1. 检查并处理 pacman.conf 中的配置
    if repo_in_conf "$ARCHLINUXCN_REPO"; then
        if repo_uses_include "$ARCHLINUXCN_REPO" "$ARCHLINUXCN_MIRRORLIST"; then
            info "pacman.conf 已使用 Include 方式配置 [${ARCHLINUXCN_REPO}]，无需修改"
        else
            local directive
            directive=$(get_repo_first_directive "$ARCHLINUXCN_REPO") || true
            if [[ "$directive" == *"Server ="* ]]; then
                warn "检测到 [${ARCHLINUXCN_REPO}] 使用 Server 直连方式"
                if confirm "是否迁移到 Include 方式？"; then
                    # 提取当前 Server 并生成 mirrorlist
                    if [[ ! -f "$ARCHLINUXCN_MIRRORLIST" ]]; then
                        create_archlinuxcn_full_mirrorlist
                    fi
                    remove_repo_from_conf "$ARCHLINUXCN_REPO"
                    add_repo_to_conf "$ARCHLINUXCN_REPO" "$ARCHLINUXCN_MIRRORLIST"
                fi
            else
                warn "检测到 [${ARCHLINUXCN_REPO}] 使用 Include 方式但路径不同: ${directive}"
            fi
        fi
    else
        add_repo_to_conf "$ARCHLINUXCN_REPO" "$ARCHLINUXCN_MIRRORLIST"
    fi

    # 2. 确保 mirrorlist 存在
    if [[ ! -f "$ARCHLINUXCN_MIRRORLIST" ]]; then
        create_archlinuxcn_bootstrap_mirrorlist
    fi

    # 3. 刷新数据库并安装 keyring
    if ! pkg_installed "$ARCHLINUXCN_KEYRING_PKG"; then
        info "正在刷新 pacman 数据库以安装 ${ARCHLINUXCN_KEYRING_PKG}..."
        pacman -Sy --noconfirm "$ARCHLINUXCN_KEYRING_PKG"
        info "${ARCHLINUXCN_KEYRING_PKG} 安装完成"
    else
        info "${ARCHLINUXCN_KEYRING_PKG} 已安装"
    fi

    # 4. 安装 mirrorlist 包（覆盖 bootstrap mirrorlist）
    if ! pkg_installed "$ARCHLINUXCN_MIRRORLIST_PKG"; then
        info "正在安装 ${ARCHLINUXCN_MIRRORLIST_PKG}..."
        pacman -S --noconfirm "$ARCHLINUXCN_MIRRORLIST_PKG"
    else
        info "${ARCHLINUXCN_MIRRORLIST_PKG} 已安装"
    fi

    # 如果 mirrorlist 包安装后没有覆盖我们的 bootstrap 文件，
    # 且文件仍是 bootstrap 状态，则替换为完整版
    if grep -q "bootstrap" "$ARCHLINUXCN_MIRRORLIST" 2>/dev/null; then
        info "检测到 bootstrap mirrorlist，替换为完整镜像列表..."
        create_archlinuxcn_full_mirrorlist
    fi
}

remove_archlinuxcn() {
    section "移除 archlinuxcn 源"

    if repo_in_conf "$ARCHLINUXCN_REPO"; then
        if confirm "确认从 pacman.conf 移除 [${ARCHLINUXCN_REPO}] 配置？"; then
            remove_repo_from_conf "$ARCHLINUXCN_REPO"
        fi
    else
        warn "pacman.conf 中未找到 [${ARCHLINUXCN_REPO}]"
    fi

    if [[ -f "$ARCHLINUXCN_MIRRORLIST" ]]; then
        if confirm "是否删除 mirrorlist ${ARCHLINUXCN_MIRRORLIST}？"; then
            rm -f "$ARCHLINUXCN_MIRRORLIST" "${ARCHLINUXCN_MIRRORLIST}.bak"
            info "已删除 ${ARCHLINUXCN_MIRRORLIST}"
        fi
    fi

    local pkgs=()
    for pkg in "$ARCHLINUXCN_KEYRING_PKG" "$ARCHLINUXCN_MIRRORLIST_PKG"; do
        pkg_installed "$pkg" && pkgs+=("$pkg")
    done

    if [[ ${#pkgs[@]} -gt 0 ]]; then
        if confirm "是否卸载: ${pkgs[*]}？"; then
            pacman -Rns --noconfirm "${pkgs[@]}"
        fi
    fi
}

# ==================== aur-repo 源处理 ====================

create_aur_mirrorlist() {
    mkdir -p /etc/pacman.d
    cat > "$AUR_MIRRORLIST" <<'EOF'
# aur-repo mirrorlist
# 安装 aur-repo-mirrorlist-git 包可自动更新此文件

## China Telecom Network (200Mbps) (ipv4, http, https)
Server = https://rom.ie8.pub:2443/aur-repo/$arch

## China Telecom Network (100Mbps) (ipv4, ipv6, http, https)
Server = https://fun.ie8.pub:2443/aur-repo/$arch

## China Unicom Network (100Mbps) (ipv4, ipv6, http, https)
Server = https://atz-mirror.teamos.vip:60000/aur-repo/$arch

## CloudFlare Preferred CDN (ipv4, ipv6, http, https)
Server = https://mirrors.kicad.online/aur-repo/$arch

## CloudFlare Free CDN (ipv4, ipv6, http, https)
#Server = https://aur-repo.taotieren.com/aur-repo/$arch

## China Mobile Network (50Mbps) (ipv6, http, https)
#Server = https://aur-repo6.taotieren.com/aur-repo/$arch
EOF
    info "已创建 aur-repo mirrorlist: ${AUR_MIRRORLIST}"
}

setup_aur_repo() {
    section "配置 aur-repo 源"

    # 1. 处理 GPG 密钥
    if gpg_key_trusted "$AUR_KEYRING_KEY"; then
        info "GPG 密钥 ${AUR_KEYRING_KEY} 已信任"
    else
        info "正在添加 GPG 密钥 ${AUR_KEYRING_KEY}..."
        pacman-key --recv-keys "$AUR_KEYRING_KEY"
        pacman-key --lsign-key "$AUR_KEYRING_KEY"
        info "GPG 密钥已添加并信任"
    fi

    # 2. 处理 pacman.conf 配置
    if repo_in_conf "$AUR_REPO"; then
        if repo_uses_include "$AUR_REPO" "$AUR_MIRRORLIST"; then
            info "pacman.conf 已使用 Include 方式配置 [${AUR_REPO}]，无需修改"
        else
            local directive
            directive=$(get_repo_first_directive "$AUR_REPO") || true
            if [[ "$directive" == *"Server ="* ]]; then
                warn "检测到 [${AUR_REPO}] 使用 Server 直连方式"
                if confirm "是否迁移到 Include 方式？"; then
                    if [[ ! -f "$AUR_MIRRORLIST" ]]; then
                        create_aur_mirrorlist
                    fi
                    remove_repo_from_conf "$AUR_REPO"
                    add_repo_to_conf "$AUR_REPO" "$AUR_MIRRORLIST"
                fi
            else
                warn "检测到 [${AUR_REPO}] 使用 Include 方式但路径不同: ${directive}"
            fi
        fi
    else
        add_repo_to_conf "$AUR_REPO" "$AUR_MIRRORLIST"
    fi

    # 3. 确保 mirrorlist 存在
    if [[ ! -f "$AUR_MIRRORLIST" ]]; then
        create_aur_mirrorlist
    fi

    # 4. 安装相关软件包
    local pkgs=()
    if ! pkg_installed "$AUR_MIRRORLIST_PKG"; then
        pkgs+=("$AUR_MIRRORLIST_PKG")
    else
        info "${AUR_MIRRORLIST_PKG} 已安装"
    fi

    if [[ -n "$AUR_EXTRA_PKGS" ]]; then
        if ! pkg_installed "$AUR_EXTRA_PKGS"; then
            if confirm "是否安装 ${AUR_EXTRA_PKGS}？（aur-repo 的 devtools 支持）"; then
                pkgs+=("$AUR_EXTRA_PKGS")
            fi
        else
            info "${AUR_EXTRA_PKGS} 已安装"
        fi
    fi

    if [[ ${#pkgs[@]} -gt 0 ]]; then
        info "正在安装: ${pkgs[*]}"
        pacman -Syu --noconfirm "${pkgs[@]}"
    fi
}

remove_aur_repo() {
    section "移除 aur-repo 源"

    if repo_in_conf "$AUR_REPO"; then
        if confirm "确认从 pacman.conf 移除 [${AUR_REPO}] 配置？"; then
            remove_repo_from_conf "$AUR_REPO"
        fi
    else
        warn "pacman.conf 中未找到 [${AUR_REPO}]"
    fi

    if [[ -f "$AUR_MIRRORLIST" ]]; then
        if confirm "是否删除 mirrorlist ${AUR_MIRRORLIST}？"; then
            rm -f "$AUR_MIRRORLIST"
            info "已删除 ${AUR_MIRRORLIST}"
        fi
    fi

    if gpg_key_trusted "$AUR_KEYRING_KEY"; then
        if confirm "是否从 keyring 移除 GPG 密钥 ${AUR_KEYRING_KEY}？"; then
            pacman-key --delete "$AUR_KEYRING_KEY"
            info "已移除 GPG 密钥"
        fi
    fi

    local pkgs=()
    for pkg in "$AUR_MIRRORLIST_PKG" $AUR_EXTRA_PKGS; do
        pkg_installed "$pkg" && pkgs+=("$pkg")
    done

    if [[ ${#pkgs[@]} -gt 0 ]]; then
        if confirm "是否卸载: ${pkgs[*]}？"; then
            pacman -Rns --noconfirm "${pkgs[@]}"
        fi
    fi
}

# ==================== 主命令 ====================

do_install() {
    check_root

    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║   aur-repo & archlinuxcn 源安装    ║${NC}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════╝${NC}"

    # 先配置 archlinuxcn（aur-repo 依赖它）
    setup_archlinuxcn

    # 再配置 aur-repo
    setup_aur_repo

    # 最终刷新数据库
    info "正在刷新 pacman 数据库..."
    pacman -Sy

    echo ""
    echo -e "${GREEN}${BOLD}✓ 安装完成！${NC}"
    echo -e "  archlinuxcn 镜像列表: ${ARCHLINUXCN_MIRRORLIST}"
    echo -e "  aur-repo   镜像列表: ${AUR_MIRRORLIST}"
    echo -e "  使用 ${CYAN}pacman -S <package>${NC} 安装软件包"
}

do_remove() {
    check_root

    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║   aur-repo & archlinuxcn 源移除     ║${NC}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════╝${NC}"

    # 先移除 aur-repo（依赖方先移除）
    remove_aur_repo

    # 再移除 archlinuxcn
    remove_archlinuxcn

    echo ""
    echo -e "${GREEN}${BOLD}✓ 移除完成！${NC}"
}

do_status() {
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║        源配置状态检查                ║${NC}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════╝${NC}"

    # ---- archlinuxcn ----
    echo -e "\n${BOLD}[archlinuxcn]${NC}"

    if repo_in_conf "$ARCHLINUXCN_REPO"; then
        local line
        line=$(find_repo_line "$ARCHLINUXCN_REPO")
        echo -e "  pacman.conf:  ${GREEN}已配置${NC} (第 ${line} 行)"
        if repo_uses_include "$ARCHLINUXCN_REPO" "$ARCHLINUXCN_MIRRORLIST"; then
            echo -e "  配置方式:     ${GREEN}Include (推荐)${NC}"
        else
            local directive
            directive=$(get_repo_first_directive "$ARCHLINUXCN_REPO") || true
            echo -e "  配置方式:     ${YELLOW}非 Include (${directive})${NC}"
        fi
    else
        echo -e "  pacman.conf:  ${RED}未配置${NC}"
    fi

    if [[ -f "$ARCHLINUXCN_MIRRORLIST" ]]; then
        local cnt
        cnt=$(grep -c "^Server" "$ARCHLINUXCN_MIRRORLIST" 2>/dev/null || echo "0")
        echo -e "  mirrorlist:   ${GREEN}存在${NC} (启用 ${cnt} 个镜像)"
    else
        echo -e "  mirrorlist:   ${RED}不存在${NC}"
    fi

    for pkg in "$ARCHLINUXCN_KEYRING_PKG" "$ARCHLINUXCN_MIRRORLIST_PKG"; do
        if pkg_installed "$pkg"; then
            echo -e "  ${pkg}:  ${GREEN}已安装${NC}"
        else
            echo -e "  ${pkg}:  ${RED}未安装${NC}"
        fi
    done

    # ---- aur-repo ----
    echo -e "\n${BOLD}[aur-repo]${NC}"

    if repo_in_conf "$AUR_REPO"; then
        local line
        line=$(find_repo_line "$AUR_REPO")
        echo -e "  pacman.conf:  ${GREEN}已配置${NC} (第 ${line} 行)"
        if repo_uses_include "$AUR_REPO" "$AUR_MIRRORLIST"; then
            echo -e "  配置方式:     ${GREEN}Include (推荐)${NC}"
        else
            local directive
            directive=$(get_repo_first_directive "$AUR_REPO") || true
            echo -e "  配置方式:     ${YELLOW}非 Include (${directive})${NC}"
        fi
    else
        echo -e "  pacman.conf:  ${RED}未配置${NC}"
    fi

    if [[ -f "$AUR_MIRRORLIST" ]]; then
        local cnt
        cnt=$(grep -c "^Server" "$AUR_MIRRORLIST" 2>/dev/null || echo "0")
        echo -e "  mirrorlist:   ${GREEN}存在${NC} (启用 ${cnt} 个镜像)"
    else
        echo -e "  mirrorlist:   ${RED}不存在${NC}"
    fi

    if gpg_key_trusted "$AUR_KEYRING_KEY"; then
        echo -e "  GPG 密钥:     ${GREEN}已信任${NC} (${AUR_KEYRING_KEY})"
    else
        echo -e "  GPG 密钥:     ${RED}未信任${NC}"
    fi

    for pkg in "$AUR_MIRRORLIST_PKG" $AUR_EXTRA_PKGS; do
        if pkg_installed "$pkg"; then
            echo -e "  ${pkg}:  ${GREEN}已安装${NC}"
        else
            echo -e "  ${pkg}:  ${YELLOW}未安装${NC}"
        fi
    done

    # ---- 依赖关系提示 ----
    echo ""
    if repo_in_conf "$ARCHLINUXCN_REPO" && repo_in_conf "$AUR_REPO"; then
        echo -e "  ${GREEN}依赖关系: archlinuxcn → aur-repo ✓${NC}"
    elif repo_in_conf "$AUR_REPO" && ! repo_in_conf "$ARCHLINUXCN_REPO"; then
        echo -e "  ${YELLOW}⚠ aur-repo 依赖 archlinuxcn 源，但 archlinuxcn 未配置${NC}"
    fi
}

# ==================== 帮助 ====================

usage() {
    echo -e "${BOLD}aur-repo & archlinuxcn 源管理脚本${NC}"
    echo ""
    echo -e "${BOLD}用法:${NC} $(basename "$0") <命令>"
    echo ""
    echo -e "${BOLD}命令:${NC}"
    echo -e "  ${CYAN}install${NC}   安装 archlinuxcn + aur-repo 源（含 keyring、mirrorlist 包）"
    echo -e "  ${CYAN}remove${NC}    交互式移除所有源配置"
    echo -e "  ${CYAN}status${NC}    查看源配置状态（无需 root）"
    echo -e "  ${CYAN}help${NC}      显示此帮助信息"
    echo ""
    echo -e "${BOLD}说明:${NC}"
    echo -e "  aur-repo 中的包依赖 archlinuxcn 源，因此安装时按以下顺序处理："
    echo -e "    ${GREEN}1${NC}. archlinuxcn  → 先添加源，再安装 ${CYAN}archlinuxcn-keyring${NC}"
    echo -e "    ${GREEN}2${NC}. aur-repo     → 导入 GPG 密钥，安装 ${CYAN}aur-repo-mirrorlist-git${NC} 等"
    echo ""
    echo -e "  两个源均使用 ${BOLD}pacman.conf Include${NC} 规范："
    echo -e "    ${YELLOW}[archlinuxcn]${NC}"
    echo -e "    ${CYAN}Include = /etc/pacman.d/archlinuxcn-mirrorlist${NC}"
    echo ""
    echo -e "    ${YELLOW}[aur-repo]${NC}"
    echo -e "    ${CYAN}Include = /etc/pacman.d/aur-repo-mirrorlist${NC}"
    echo ""
    echo -e "${BOLD}示例:${NC}"
    echo -e "  sudo $(basename "$0") ${CYAN}install${NC}    # 一键安装所有源"
    echo -e "  sudo $(basename "$0") ${CYAN}remove${NC}     # 交互式移除"
    echo -e "  $(basename "$0") ${CYAN}status${NC}           # 查看状态"
}

# ==================== 入口 ====================

case "${1:-}" in
    install)  do_install  ;;
    remove)   do_remove   ;;
    status)   do_status   ;;
    help|--help|-h) usage ;;
    *)
        usage
        exit 1
        ;;
esac
