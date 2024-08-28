# Maintainers: kobe-koto <admin[at]koto[dot]cc>, Ketal_Q_ray <k[at]ketal[dot]icu>, Kevin_Liu <we123445[at]outlook[dot]com>
pkgname="liteloader-qqnt-bin"
_pkgname="LiteLoaderQQNT"
pkgver=1.2.1
pkgrel=2
pkgdesc="轻量, 简洁, 开源的 QQNT 插件加载器"
arch=('any')
url="https://github.com/LiteLoaderQQNT/LiteLoaderQQNT"
license=('MIT')
depends=("linuxqq" "bubblewrap")
conflicts=("linuxqq-appimage" "liteloader-qqnt")
provides=("liteloader-qqnt")
source=("LiteLoaderQQNT-${pkgver}.zip::${url}/releases/download/${pkgver}/${_pkgname}.zip"
		"liteloader-qqnt-depatch.hook"
		"liteloader-qqnt-patch.hook"
		"gen_preload.js"
		"index.js"
		"patch_liteloader_bwarp.sh"
		)

sha256sums=('affbd02573900d4f5743e33386d41b38adaac6ed9a130d57e7c8c75f8dc68838'
            '19c14e36baeffd1b385de2757cdaa8a68766ddea0480bbeec04efb7dcc2bc2d3'
            '3cacd5aa344eba037f45279b1cb4c2e56fe01057b3fa9acc32474957c97f9be0'
			'34647dd074b6cbcc0ab7e7b1178de6c92064703f6d219b422baee42fbe729949'
			'da197eee75d92d5d79861d3531e59afc1caf091446b4ba2d0a8916e0a9c87b0b'
			'6c81d269959110b38495e72b51ebd51021f6feb837cac6bedc46a697eaa67462'
			)

package() {
	# prepare to copy files
	mkdir -p "${pkgdir}/opt/LiteLoaderQQNT"
	# mkdir -p "${pkgdir}/opt/QQ/resources/app/application"

	# copy files
	cp -rf "${srcdir}"/* "${pkgdir}/opt/LiteLoaderQQNT/"
	# cp -f "${srcdir}/src/preload.js" "${pkgdir}/opt/QQ/resources/app/application/preload.js"

	# clean up in target dir
	rm -f "${pkgdir}/opt/LiteLoaderQQNT/LiteLoaderQQNT-${pkgver}.zip"
	rm -f "${pkgdir}/opt/LiteLoaderQQNT/liteloader-qqnt-patch.hook"
	rm -f "${pkgdir}/opt/LiteLoaderQQNT/liteloader-qqnt-depatch.hook"

	# copying patching files
	mkdir -p "${pkgdir}/opt/LiteLoaderQQNT/patching"
	cp "${pkgdir}/opt/LiteLoaderQQNT/gen_preload.js" "${pkgdir}/opt/LiteLoaderQQNT/patching/gen_preload.js"
	cp "${pkgdir}/opt/LiteLoaderQQNT/index.js" "${pkgdir}/opt/LiteLoaderQQNT/patching/index.js"
	cp "${pkgdir}/opt/LiteLoaderQQNT/patch_liteloader_bwarp.sh" "${pkgdir}/opt/LiteLoaderQQNT/patching/patch_liteloader_bwarp.sh"
	rm -f "${pkgdir}/opt/LiteLoaderQQNT/gen_preload.js"
	rm -f "${pkgdir}/opt/LiteLoaderQQNT/index.js"
	rm -f "${pkgdir}/opt/LiteLoaderQQNT/patch_liteloader_bwarp.sh"

	# install hooks
	install -Dm644 "${srcdir}/liteloader-qqnt-patch.hook" "${pkgdir}/etc/pacman.d/hooks/liteloader-qqnt-patch.hook"
	install -Dm644 "${srcdir}/liteloader-qqnt-depatch.hook" "${pkgdir}/etc/pacman.d/hooks/liteloader-qqnt-depatch.hook"
}
