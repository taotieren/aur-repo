# NOT compatible with AUR helpers!
#
# To install:
# 	git clone https://aur.archlinux.org/ida-pro.git && cd ida-pro
# 	Download the `ida-pro_VERSION_x64linux.run` installer from the IDA download center at https://my.hex-rays.com/, and place it in the same directory
# 	makepkg -sicf

# Maintainer: patchouli

pkgver=9.1.0
pkgname="ida-pro"
pkgrel=1
pkgdesc="Hex-Rays IDA Pro"
url="https://www.hex-rays.com/products/ida/${pkgver}/index.shtml"
license=('custom')
makedepends=('fakechroot')
depends=('libgl'
	'libx11'
	'libxext'
	'libxrender'
	'glib2'
	'qt5-base'
	'python-rpyc'
	)
options=('!strip')

_installer='ida-pro_91_x64linux.run'

source=("file://${_installer}"
		"${pkgname}.desktop"
		"${pkgname}-teams.desktop")

sha256sums=('8ff08022be3a0ef693a9e3ea01010d1356b26cfdcbbe7fdd68d01b3c9700f9e2'
            '662478dbcb939db8a36f89170246c2187b1086bff840dd96bd4d8f72eac3cad5'
            '437fc36a8edd8dd6adadd773dd777966797640d93f499892bdd1217afaf1b636')

arch=('x86_64')

package() {
	install -d "${pkgdir}"/opt/${pkgname}
	install -d "${pkgdir}"/usr/bin
	install -d "${pkgdir}"/usr/share/{icons,applications,licenses/${pkgname}}
	install -d "${pkgdir}"/tmp

	# chroot is needed to prevent the installer from creating a single file outside of prefix
	# have to copy the installer due to chroot
	cp "${srcdir}"/${_installer} "${pkgdir}"/
	chmod +x "${pkgdir}"/${_installer}

	# IDA Pro 9.0 SP1 (and newer) installer now tries to copy the .desktop files to $HOME even if you specify a prefix. Very annoying.
	mkdir -p $pkgdir/$HOME/.local/share/applications
	fakechroot chroot "${pkgdir}" /${_installer} --mode unattended --prefix "/opt/${pkgname}"
	rm "${pkgdir}"/${_installer}
	rm -Rf "${pkgdir}"/{tmp,home}

	# the installer needlessly makes a lot of files executable
	find "${pkgdir}"/opt/${pkgname} -type f -exec chmod -x {} \;
	chmod +x "${pkgdir}"/opt/${pkgname}/{assistant,hv,hvui,ida,idapyswitch,idat,picture_decoder,qwingraph,upg32}

	rm "${pkgdir}"/opt/${pkgname}/{uninstall*,Uninstall*}

	install "${srcdir}"/${pkgname}*.desktop "${pkgdir}"/usr/share/applications
	ln -s /opt/${pkgname}/appico.png "${pkgdir}"/usr/share/icons/${pkgname}.png
	ln -s /opt/${pkgname}/hvui.png "${pkgdir}"/usr/share/icons/${pkgname}-teams.png
	ln -s /opt/${pkgname}/license.txt "${pkgdir}"/usr/share/licenses/${pkgname}/LICENSE
	ln -s /opt/${pkgname}/ida "${pkgdir}"/usr/bin/ida
}
