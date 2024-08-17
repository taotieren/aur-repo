# Maintainer: Purofle <purofle@gmail.com>
# Contributor: Integral <integral@member.fsf.org>

pkgname=linuxqq
pkgver=3.2.12_27187
pkgrel=1
epoch=4
pkgdesc="New Linux QQ based on Electron"
arch=('x86_64' 'aarch64' 'loong64')
url="https://im.qq.com/${pkgname}"
license=('LicenseRef-QQ')
conflicts=("${pkgname}-nt-bwrap")
depends=('nss' 'alsa-lib' 'gtk3' 'gjs' 'at-spi2-core' 'libvips' 'openjpeg2' 'openslide')
optdepends=('libappindicator-gtk3: Allow QQ to extend a menu via Ayatana indicators in Unity, KDE or Systray (GTK+ 3 library).')
source_x86_64=("https://dldir1.qq.com/qqfile/qq/QQNT/08c52833/${pkgname}_${pkgver/_/-}_amd64.deb")
source_aarch64=("https://dldir1.qq.com/qqfile/qq/QQNT/08c52833/${pkgname}_${pkgver/_/-}_arm64.deb")
source_loong64=("https://dldir1.qq.com/qqfile/qq/QQNT/08c52833/${pkgname}_${pkgver/_/-}_loongarch64.deb")
source=("${pkgname}.sh")
sha512sums=('f463c5cb3323b86d9ea312d75f1e53d064885dabde2d1d6a554e083e15b5ff7fc548a96670284e5e996456c7a2ce4a25e9acb80bf48459ea47a8813d62203cb4')
sha512sums_x86_64=('25634f4b96f01fa91d02c16b92cad8ff868ce69b4a13a51a228968ac8f45a2bf14de9fb13e2e701e88874c41de68634349ab4eb32dde6b3ec1916a1bcabfabdb')
sha512sums_aarch64=('ebc5ffc00d7f3ddc080d931f479cc868fefdc21b78fe842f67f656b63247f9f9014d5dffb6bb8457eb42f94a8512de22478e886116a1d3c8e2ea277ae888cbc9')
sha512sums_loong64=('b80b8affaf6597bbb474334559469dbc622dff1885a7e5fae349dde3e8a50a1641065fe0b464fe67622b32517e1941829020be23f1d95b236c8eb08e03c25a50')
options=('!strip' '!debug')

package() {
	echo "  -> Extracting the data.tar.xz..."
	bsdtar -xf data.tar.xz -C "${pkgdir}/"
	rm -f "${pkgdir}/opt/QQ/resources/app/libssh2.so.1" # Temporary Fix

	echo "  -> Installing..."
	# Launcher
	install -Dm755 "${pkgname}.sh" "${pkgdir}/usr/bin/${pkgname}"

	# Launcher Fix
	sed -i '3s!/opt/QQ/qq!linuxqq!' "${pkgdir}/usr/share/applications/qq.desktop"

	# Icon Fix
	sed -i '6s!/usr/share/icons/hicolor/512x512/apps/qq.png!qq!' "${pkgdir}/usr/share/applications/qq.desktop"

	# License
	install -Dm644 "${pkgdir}/opt/QQ/LICENSE.electron.txt" -t "${pkgdir}/usr/share/licenses/${pkgname}/"
	install -Dm644 "${pkgdir}/opt/QQ/LICENSES.chromium.html" -t "${pkgdir}/usr/share/licenses/${pkgname}/"

	# Temporary Solution: Remove libvips which comes from package "linuxqq" itself
	rm -f "${pkgdir}/opt/QQ/resources/app/sharp-lib/libvips-cpp.so.42"
}
