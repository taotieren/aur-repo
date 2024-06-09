# Maintainer: Purofle <purofle@gmail.com>
# Contributor: Integral <integral@member.fsf.org>

pkgname=linuxqq
pkgver=3.2.9_24568
pkgrel=1
epoch=4
pkgdesc='New Linux QQ based on Electron'
arch=('x86_64' 'aarch64' 'loong64')
url="https://im.qq.com/linuxqq/"
license=('LicenseRef-QQ')
conflicts=('linuxqq-nt-bwrap')
depends=('nss' 'alsa-lib' 'gtk3' 'gjs' 'at-spi2-core' 'libvips' 'openjpeg2')
optdepends=('libappindicator-gtk3: Allow QQ to extend a menu via Ayatana indicators in Unity, KDE or Systray (GTK+ 3 library).')
source_x86_64=("https://dldir1.qq.com/qqfile/qq/QQNT/a663aa83/${pkgname}_${pkgver/_/-}_amd64.deb")
source_aarch64=("https://dldir1.qq.com/qqfile/qq/QQNT/a663aa83/${pkgname}_${pkgver/_/-}_arm64.deb")
source_loong64=("https://dldir1.qq.com/qqfile/qq/QQNT/a663aa83/${pkgname}_${pkgver/_/-}_loongarch64.deb")
source=("linuxqq.sh")
sha512sums=('f463c5cb3323b86d9ea312d75f1e53d064885dabde2d1d6a554e083e15b5ff7fc548a96670284e5e996456c7a2ce4a25e9acb80bf48459ea47a8813d62203cb4')
sha512sums_x86_64=('193036fa7c0b07c11e0a7895fcc0994898be9132ffdb557238b319fc4c98b17ee4660ca8c8785fe363adc3a66ee0c4fa4f4f4efeac705ff38b9b89a8bc9a0a92')
sha512sums_aarch64=('930a190afac76da315385dde004ace0cb1982b5dc3d3729a17450fc11bc155b509d25ea517861662cb55cb726d61097b46ca17cf04b46868f60f66bbf442c622')
sha512sums_loong64=('477908ff6eaf032e01147c8bd3d09ab5713d36454e2c65e7c4ad5d94aaea235d63a040a19ad5d7be7efc17416aa4737e694a074683b6bd7aa221acbef0d37a48')
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
