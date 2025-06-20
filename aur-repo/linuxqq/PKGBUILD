# Maintainer: Purofle <purofle@gmail.com>
# Contributor: Integral <integral@member.fsf.org>

pkgname=linuxqq
pkgver=3.2.18_36497
pkgrel=1
epoch=5
pkgdesc="New Linux QQ based on Electron"
arch=('x86_64' 'aarch64' 'loong64')
url="https://im.qq.com/${pkgname}"
license=('LicenseRef-QQ')
conflicts=("${pkgname}-nt-bwrap")
depends=('nss' 'alsa-lib' 'gtk3' 'gjs' 'at-spi2-core' 'libvips' 'openjpeg2' 'openslide')
optdepends=('libappindicator-gtk3: Allow QQ to extend a menu via Ayatana indicators in Unity, KDE or Systray (GTK+ 3 library).')
_md5_prefix=81e26a27
_src_prefix="${pkgname}_${pkgver/_/-}"
source_x86_64=("https://dldir1.qq.com/qqfile/qq/QQNT/${_md5_prefix}/${_src_prefix}_amd64.deb")
source_aarch64=("https://dldir1.qq.com/qqfile/qq/QQNT/${_md5_prefix}/${_src_prefix}_arm64.deb")
source_loong64=("https://dldir1.qq.com/qqfile/qq/QQNT/${_md5_prefix}/${_src_prefix}_loongarch64.deb")
source=("${pkgname}.sh")
sha512sums=('e06676ac2297cba5d20877ac82ef506a9596980bc66257952f37d45ef9810953aedb789655d004b3fd0ac548f2f085e1be406081d9c8d5321622567431c7b3da')
sha512sums_x86_64=('917b08c5898709577359cff47309d913455f6cd94d9a2ae6a53ce1454163885fc8ba6c5af5e16c78e58c5b638f678018bd8fa3ac5f536fe5132181e403ff13c6')
sha512sums_aarch64=('3f9927f0542078c368e7501288dce62196d7376053f77d5477a873dc786d6a9cfd7e4876bd5a1d812914964354822ab4730d7ba530b3952ace144341113e9c8f')
sha512sums_loong64=('365ecf09a3ff28e64a2328cb658aeb7f4ca12b8a2a026c2e88554ad22fbed5c952e9d06892ebc3f27ca9eb014f1ebf0b5b4524809de1260fdc03cae3ffcf5675')
options=('!strip' '!debug')

package() {
	echo "  -> Extracting the data.tar.xz..."
	bsdtar -xf data.tar.xz -C "${pkgdir}/"

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

	# Temporary Solution: Remove libvips and libssh2 which comes from package "linuxqq" itself
	rm -fv ${pkgdir}/opt/QQ/resources/app/{sharp-lib/libvips-cpp.so.42,{,avsdk/bugly/}libssh2.so.1}
}
