# Maintainer: taotieren <admin@taotieren.com>
# Co-Maintainer: Misaka13514 <Misaka13514 at gmail dot com>

pkgname=lceda-pro-bin
_pkgname=${pkgname%-bin}
pkgver=3.2.58
pkgrel=1
pkgdesc="免费、专业、强大的国产PCB设计工具"
arch=('x86_64' 'aarch64')
url="https://pro.lceda.cn/"
license=('LicenseRef-LCEDA-Proprietary')
provides=(${_pkgname})
conflicts=(${_pkgname} ${_pkgname}-git)
depends=('gtk3' 'nss' 'alsa-lib')
makedepends=('curl')
install=${pkgname}.install
source=("${pkgname}.install")
source_x86_64=("${_pkgname}-x86_64-${pkgver}.zip::https://image.lceda.cn/files/lceda-pro-linux-x64-${pkgver}.zip")
source_aarch64=("${_pkgname}-aarch64-${pkgver}.zip::https://image.lceda.cn/files/lceda-pro-linux-arm64-${pkgver}.zip")
# source_loong64=("${_pkgname}-loong64-${pkgver}.zip::https://image.lceda.cn/files/lceda-pro-linux-loong64-${pkgver}.zip")
sha256sums=('afba3c6712227a37c08783b3cc1a97ae71e90dc2f575409213d2773372220697')
sha256sums_x86_64=('6922d17bfa10dee09a35478f00ed7b24cb082ece6dccebc48d2409cac5824c24')
sha256sums_aarch64=('9d17cfb632a6d72df3a667340817e8cea606d7deb51e23f20063b7c267eaa0d8')
# sha256sums_loong64=('SKIP')

prepare() {
    # https://gitlab.archlinux.org/pacman/pacman-contrib/-/issues/119
    curl -sSfL -o "LICENSE-$pkgver.html" "https://lceda.cn/page/legal"
}

package() {
    export LC_CTYPE="zh_CN.UTF-8"
    install -dm0755 "${pkgdir}/opt/${_pkgname}/"

    cd "${srcdir}/${_pkgname}"
    mv * "${pkgdir}/opt/${_pkgname}/"

    cd "${pkgdir}/opt/${_pkgname}/"
    # icon
    local _icon
    for _icon in 16 32 64 128 256 512; do
        install -Dm0644 "icon/icon_${_icon}x${_icon}.png" \
                        "${pkgdir}/usr/share/icons/hicolor/${_icon}x${_icon}/apps/${_pkgname}.png"
    done
    if [ -f icon/icon_512x512@2x.png ]; then
        install -Dm0644 "icon/icon_512x512@2x.png" \
                       "${pkgdir}/usr/share/icons/hicolor/1024x1024/apps/${_pkgname}.png"
    fi
    rm -rf icon

    # desktop entry
    if [ -f lceda-pro.dkt ]; then
        install -Dm0644 lceda-pro.dkt \
                        "${pkgdir}/usr/share/applications/${_pkgname}.desktop"

        sed -i 's|/opt/lceda-pro/icon/icon_128x128.png|lceda-pro|g' \
            "${pkgdir}/usr/share/applications/${_pkgname}.desktop"
        sed -i 's|/opt/lceda-pro/||g' \
            "${pkgdir}/usr/share/applications/${_pkgname}.desktop"
        rm -rf lceda-pro.dkt
    else
        install -Dm644 /dev/stdin $pkgdir/usr/share/applications/$_pkgname.desktop << "EOF"
[Desktop Entry]
Categories=Development;Electronics;
Comment=免费、强大、易用的在线电路设计软件
Exec=lceda-pro %f
Keywords=PCB;LCEDA;嘉立创EDA;LC;EDA
GenericName=嘉立创EDA(专业版)
Icon=lceda-pro
Name=嘉立创EDA(专业版)
Type=Application
Name[en_US]=嘉立创EDA(专业版)
MimeType=application/eprj
EOF
    fi

    # fix permissions
    find "${pkgdir}/opt/${_pkgname}/" -type f -exec chmod 644 {} \;
    find "${pkgdir}/opt/${_pkgname}/" -type d -exec chmod 755 {} \;
    chmod 0755 "${pkgdir}/opt/${_pkgname}/${_pkgname}"
    chmod 0755 "${pkgdir}/opt/${_pkgname}/chrome_crashpad_handler"

    # soft link
    install -dm0755 "${pkgdir}/usr/bin/"
    ln -s "/opt/${_pkgname}/${_pkgname}" \
          "${pkgdir}/usr/bin/${_pkgname}"

    # LICENSE
    install -Dm0644 ${srcdir}/LICENSE-$pkgver.html ${pkgdir}/usr/share/licenses/${pkgname}/LICENSE.html
}
