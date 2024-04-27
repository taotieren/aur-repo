# Maintainer: Purofle <purofle@gmail.com>
# Contributor: Integral <integral@member.fsf.org>

pkgname=linuxqq
pkgver=3.2.7_240422
pkgrel=1
epoch=3
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
sha512sums=('f463c5cb3323b86d9ea312d75f1e53d064885dabde2d1d6a554e083e15b5ff7fc548a96670284e5e996456c7a2ce4a25e9acb80bf48459ea47a8813d62203cb4')
sha512sums_x86_64=('76837b2602cf1eee2994dc47e28cd26bb6ccb7a7c10f1da062badb2d1c7b6191b731f847845f386a924f462f1c71d578493a2f3dddc82a78745742cd796e5fc3')
sha512sums_aarch64=('038905c84eb4e5e700bd0aab9a17ef3319a5d088937590c45698c6158deb5e9f8487d7bb5cb6df7d72a1d084b5ab29c5bfab5dbd66601a3c99b2f28c2a86d013')
sha512sums_loong64=('6f6549bb70936a30c8bfc9149a90ef2a1df309fd12f658e17ff97737fb25caf02121b0a1f45463cef1fe5232062cd15bb1c69d39e113ca245f0cee74f4d814da')
options=('!strip')

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
