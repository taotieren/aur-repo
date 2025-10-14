# Maintainer: Purofle <purofle@gmail.com>
# Contributor: Integral <integral@member.fsf.org>

pkgname=linuxqq
pkgver=3.2.20_40768
pkgrel=1
epoch=5
pkgdesc="New Linux QQ based on Electron"
arch=('x86_64' 'aarch64' 'loong64')
url="https://im.qq.com/${pkgname}"
license=('LicenseRef-QQ')
conflicts=("${pkgname}-nt-bwrap")
depends=('nss' 'alsa-lib' 'gtk3' 'gjs' 'at-spi2-core' 'libvips' 'openjpeg2' 'openslide')
optdepends=('libappindicator-gtk3: Allow QQ to extend a menu via Ayatana indicators in Unity, KDE or Systray (GTK+ 3 library).')
_md5_prefix=ab90fdfa
_src_prefix="${pkgname}_${pkgver/_/-}"
source_x86_64=("https://dldir1.qq.com/qqfile/qq/QQNT/${_md5_prefix}/${_src_prefix}_amd64.deb")
source_aarch64=("https://dldir1.qq.com/qqfile/qq/QQNT/${_md5_prefix}/${_src_prefix}_arm64.deb")
source_loong64=("https://dldir1.qq.com/qqfile/qq/QQNT/${_md5_prefix}/${_src_prefix}_loongarch64.deb")
source=("${pkgname}.sh")
sha512sums=('e06676ac2297cba5d20877ac82ef506a9596980bc66257952f37d45ef9810953aedb789655d004b3fd0ac548f2f085e1be406081d9c8d5321622567431c7b3da')
sha512sums_x86_64=('2885637b2c2bb4d9b3704780cf12d41f8a9978b6d76fd40fe727ebd51a41cad10906fefd958fedf30ec498ad9ad00629ccee293f83605122a7e50cc4479a9030')
sha512sums_aarch64=('72700520483fcb70f6284eb98a4e31f218177e10e8680c7b7b343f9734af3636259547cb6e10e348ff72e1df4dbd31b77181210f57b31d353507e64801b20eea')
sha512sums_loong64=('95682adee3f72dcd346da0f7ecb721a5d9e04c1bfd41ae6b29152dd84c2399f648a8002a587cfa2c4a85a146ff2ee1ef4ea234aa44fd9d48c759452e2788b17c')
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
