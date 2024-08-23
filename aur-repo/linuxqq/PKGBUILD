# Maintainer: Purofle <purofle@gmail.com>
# Contributor: Integral <integral@member.fsf.org>

pkgname=linuxqq
pkgver=3.2.12_240819
pkgrel=1
epoch=4
pkgdesc="New Linux QQ based on Electron"
arch=('x86_64' 'aarch64' 'loong64')
url="https://im.qq.com/${pkgname}"
license=('LicenseRef-QQ')
conflicts=("${pkgname}-nt-bwrap")
depends=('nss' 'alsa-lib' 'gtk3' 'gjs' 'at-spi2-core' 'libvips' 'openjpeg2' 'openslide')
optdepends=('libappindicator-gtk3: Allow QQ to extend a menu via Ayatana indicators in Unity, KDE or Systray (GTK+ 3 library).')
source_x86_64=("https://dldir1.qq.com/qqfile/qq/QQNT/Linux/QQ_${pkgver}_amd64_01.deb")
source_aarch64=("https://dldir1.qq.com/qqfile/qq/QQNT/Linux/QQ_${pkgver}_arm64_01.deb")
source_loong64=("https://dldir1.qq.com/qqfile/qq/QQNT/Linux/QQ_${pkgver}_loongarch64_01.deb")
source=("${pkgname}.sh")
sha512sums=('f463c5cb3323b86d9ea312d75f1e53d064885dabde2d1d6a554e083e15b5ff7fc548a96670284e5e996456c7a2ce4a25e9acb80bf48459ea47a8813d62203cb4')
sha512sums_x86_64=('1a171d33cbab2edfda600b8fb1923bb38ecdb2afadc3a2dffc11d4c0762e4a8b17ed1303dac67f183ea15ac689c7a4bbe75a8c8dfd457dfd8d0686b823e3ba0a')
sha512sums_aarch64=('970835669579bd1483a1ce9b2aea87732b099678ffe2d7975d9cf97c47735ebf0f8e772de0e9d397145b3cfd9eb00e0378b78cd077eded5de6c99153d291a548')
sha512sums_loong64=('c79380ed193703a5d2e3dec48375f183c9caa0e0b4f7ffc1ba4d1fb53e7998d8254c5bc234803233a90b2e806aeb15e9ece461d69c3a4aac4e61f8c1606d829c')
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
