# Maintainer: Purofle <purofle@gmail.com>
# Contributor: Integral <luckys68@126.com>

pkgname=linuxqq
pkgver=3.2.7_240410
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
sha512sums_x86_64=('9062e437e8783929bc3fe7bf9373a2ef94c9c5b52b3568e57e0fa37d3f36d15cbf508647b19768d57ce80243caec0a04846dc5353053201b5cad94d394af8a4f')
sha512sums_aarch64=('bb68611da4f4c42cb64975c78f3158bed900c7f7523f5adbf55afe024e684e905f47218e1db82f0e8095ac18d07fc1e36098e0bdd1de7c8016a75cda4c594bd9')
sha512sums_loong64=('21b24ef1f1b4f5bf612b9c7a724ce1a341b761071413819417e2570e8689768f550e7fb28272084560ad5af07e5c82bf4abcfb302b93d0305ba794d1b77263c2')
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
