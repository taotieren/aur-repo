# Maintainer: zxp19821005 <zxp19821005 at 163 dot com>
pkgname=ttf-harmonyos-sans
_pkgname='HarmonyOS Sans 字体'
pkgver=2025.09.23
pkgrel=1
pkgdesc="HarmonyOS Sans Fonts.华为鸿蒙字体"
arch=("any")
url="https://developer.huawei.com/consumer/cn/design/resource/"
license=("LicenseRef-custom")
conflicts=("${pkgname//ttf-/}")
source=(
    "${pkgname}-${pkgver}.zip::https://alliance-communityfile-drcn.dbankcdn.com/FileServer/getFile/cmtyManage/011/111/111/0000000000011111111.20250923104318.11664078982054632530113858317517:50001231000000:2800:C0DB7AC2067D28B96607BC0D598A48EAF74CA1B7D936B819A36F67CB6E071F30.zip"
)
sha256sums=('0bb556d79c65f4778e33d9b5835e5133bce4ad9ee46f823a5a3dcda888610e78')
package() {
    export LC_CTYPE="zh_CN.UTF-8"
    find "${srcdir}/${_pkgname}" -type f -name "*.ttf" -exec install -Dm644 -t "${pkgdir}/usr/share/fonts/${pkgname//ttf-/}" {} +
    install -Dm644 "${srcdir}/${_pkgname}/LICENSE.txt" -t "${pkgdir}/usr/share/licenses/${pkgname}"
}