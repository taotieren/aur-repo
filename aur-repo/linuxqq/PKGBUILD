# Maintainer: Purofle <purofle@gmail.com>
# Contributor: Integral <luckys68@126.com>

pkgname=linuxqq
pkgver=3.2.7_240403
pkgrel=1
epoch=2
pkgdesc='New Linux QQ based on Electron'
arch=('x86_64' 'aarch64' 'loong64')
url="https://im.qq.com/linuxqq/"
license=('LicenseRef-QQ')
conflicts=('linuxqq-nt-bwrap')
depends=('nss' 'alsa-lib' 'gtk3' 'gjs' 'at-spi2-core' 'libvips' 'openjpeg2')
optdepends=('libappindicator-gtk3: Allow QQ to extend a menu via Ayatana indicators in Unity, KDE or Systray (GTK+ 3 library).')
source_x86_64=("https://dldir1.qq.com/qqfile/qq/QQNT/Linux/QQ_${pkgver}_amd64_01.deb")
source_aarch64=("https://dldir1.qq.com/qqfile/qq/QQNT/Linux/QQ_${pkgver}_arm64_01.deb")
source_loong64=("https://dldir1.qq.com/qqfile/qq/QQNT/Linux/QQ_${pkgver}_loongarch64_01.deb")
source=("linuxqq.sh")
sha512sums=('8c92a5dcc2651a4ffb73425abbd8a567c4f043ec5b0614505273511260560a25ce8db30c6848977378921d860dc0a73eca083299706a585461587a48949e175c')
sha512sums_x86_64=('825fc0d1195ff7a46d13e6fb547eedcacd3f3815c3f9cc6473ebec2e3c448d2ed55d41a20581db362aadb7228ba1d033a188ba1f22a37cdee670a9646fd0b796')
sha512sums_aarch64=('abc5fda93fcd185123d29ad6427e40e03e326a6e06d21ff071deed38fdbaa464645479611561f1bdcd4473d62240e9a9a474cabc537e13e97a91d09fa123643b')
sha512sums_loong64=('a61c3df105c22b798702120829e8fccf11066f9d1cf4c50707b978c399b882561c38254d1e9864d46b16f8f8c88f605ff44c1828fdb9d39777629795e113a5b8')

package() {
	echo "  -> Extracting the data.tar.xz..."
	bsdtar -xf data.tar.xz -C "${pkgdir}/"
	rm -f "${pkgdir}/opt/QQ/resources/app/libssh2.so.1" # Temporary Fix

	echo "  -> Installing..."
	# Launcher
	install -Dm755 "${srcdir}/linuxqq.sh" "${pkgdir}/usr/bin/${pkgname}"

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
