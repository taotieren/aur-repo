# Maintainers: kobe-koto <admin[at]koto.cc>, Ketal_Q_ray <k[at]ketal.icu>
pkgname="liteloader-qqnt-bin"
_pkgname="LiteLoaderQQNT"
pkgver=1.1.2
pkgrel=2
pkgdesc="轻量, 简洁, 开源的 QQNT 插件加载器"
arch=('any')
url="https://github.com/LiteLoaderQQNT/LiteLoaderQQNT"
license=('MIT')
depends=("linuxqq")
conflicts=("linuxqq-appimage" "liteloader-qqnt")
provides=("liteloader-qqnt")
source=("${url}/releases/download/${pkgver}/${_pkgname}.zip"
		"liteloader-qqnt-depatch.hook"
		"liteloader-qqnt-patch.hook")

sha256sums=('6833511aa62228538be92d6346488a42197f138050ec5f0d84b98d519b8d5fbe'
            '4c1b129a28d1550c6b616b7a69868c0e9623257981fd2e2d2f04b274aeea4148'
            '89e6ae7eb8e6ac148adf3eaa9be0134cf10dde501753eced800bd9d0339d0c38')

package() {
	# prepare to copy files
	mkdir -p "${pkgdir}/opt/LiteLoader"
	mkdir -p "${pkgdir}/opt/QQ/resources/app/application"

	# copy files
	cp -rf "${srcdir}"/* "${pkgdir}/opt/LiteLoader/"
	cp -f "${srcdir}/src/preload.js" "${pkgdir}/opt/QQ/resources/app/application/preload.js"

	# modify premissions
	chmod -R 0777 "${pkgdir}/opt/LiteLoader"

	# clean up in target dir
	rm -f "${pkgdir}/opt/LiteLoader/LiteLoaderQQNT.zip"
	rm -f "${pkgdir}/opt/LiteLoader/liteloader-qqnt-patch.hook"
	rm -f "${pkgdir}/opt/LiteLoader/liteloader-qqnt-depatch.hook"

	# install hooks
	install -Dm644 "${srcdir}/liteloader-qqnt-patch.hook" "${pkgdir}/etc/pacman.d/hooks/liteloader-qqnt-patch.hook"
	install -Dm644 "${srcdir}/liteloader-qqnt-depatch.hook" "${pkgdir}/etc/pacman.d/hooks/liteloader-qqnt-depatch.hook"
}
