# Maintainer: greyltc
# Maintainer: txtsd <aur.archlinux@ihavea.quest>

pkgname=python-pox
_pkgname="${pkgname#python-}"
pkgver=0.3.7
pkgrel=1
pkgdesc='Utilities for filesystem exploration and automated builds'
url='https://github.com/uqfoundation/pox'
arch=(any)
license=('BSD-3-Clause')
depends=('python>=3.8')
makedepends=(
  'python-setuptools>=42.0'
  python-build
  python-installer
  python-wheel
)
_src_name="${_pkgname/-/_}-${pkgver}"
source=("${url}/releases/download/${pkgver}/${_pkgname}-${pkgver}.tar.gz")
sha256sums=('0652f6f2103fe6d4ba638beb6fa8d3e8a68fd44bcb63315c614118515bcc3afb')

build() {
  cd "${_src_name}"
  python -m build --wheel --no-isolation
}

package() {
  cd "${_src_name}"
  python -m installer --destdir="${pkgdir}" dist/*.whl
  install -Dm644 LICENSE -t "${pkgdir}/usr/share/licenses/${pkgname}"
}
