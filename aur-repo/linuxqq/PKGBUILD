# Maintainer: Purofle <purofle@gmail.com>
# Contributor: Integral <integral@member.fsf.org>

pkgname=linuxqq
pkgver=3.2.13_28788
pkgrel=1
epoch=5
pkgdesc="New Linux QQ based on Electron"
arch=('x86_64' 'aarch64' 'loong64')
url="https://im.qq.com/${pkgname}"
license=('LicenseRef-QQ')
conflicts=("${pkgname}-nt-bwrap")
depends=('nss' 'alsa-lib' 'gtk3' 'gjs' 'at-spi2-core' 'libvips' 'openjpeg2' 'openslide')
optdepends=('libappindicator-gtk3: Allow QQ to extend a menu via Ayatana indicators in Unity, KDE or Systray (GTK+ 3 library).')
source_x86_64=("https://dldir1.qq.com/qqfile/qq/QQNT/55fb6434/linuxqq_${pkgver/_/-}_amd64.deb")
source_aarch64=("https://dldir1.qq.com/qqfile/qq/QQNT/55fb6434/linuxqq_${pkgver/_/-}_arm64.deb")
source_loong64=("https://dldir1.qq.com/qqfile/qq/QQNT/55fb6434/linuxqq_${pkgver/_/-}_loongarch64.deb")
source=("${pkgname}.sh")
sha512sums=('f463c5cb3323b86d9ea312d75f1e53d064885dabde2d1d6a554e083e15b5ff7fc548a96670284e5e996456c7a2ce4a25e9acb80bf48459ea47a8813d62203cb4')
sha512sums_x86_64=('d02616b9775a51337845d3b9cb904748cf25bdc1b5144fb7aab974a5830d7c925934d19e1dd55d07f06abf65a1f476cc03b17739aa80f32a0daa967c8d685e82')
sha512sums_aarch64=('8aa9af4b9e0f0a121a5646264ad5965b144ab6d248ef13ac0756b07d2c219ede59795f7bc67af48ddf2e910fb948029831ccaada182fb71701e62d5fe6775200')
sha512sums_loong64=('f018b5c32031372822c3adb640193bdd7e2e3c72b5c8394c79d3968af32977e06ddf856b96728cf7449417b6824137c0c30b5f203ef7accf5a7315b5ecb642ca')
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
