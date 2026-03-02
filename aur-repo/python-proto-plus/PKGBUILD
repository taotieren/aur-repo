# Maintainer: Mario Finelli <mario at finel dot li>
# Contributor: Marco Rubin <marco.rubin@protonmail.com>
# Contributor: PumpkinCheshire <me at pumpkincheshire dot com>

_name=proto-plus
pkgname=python-$_name
pkgver=1.27.1
pkgrel=1
pkgdesc="A wrapper around protocol buffers"
arch=(any)
url=https://github.com/googleapis/proto-plus-python
license=(Apache-2.0)
depends=(python python-protobuf)
makedepends=(python-build python-installer python-setuptools python-wheel)
source=("$pkgname-$pkgver.tar.gz::$url/archive/v$pkgver.tar.gz")
sha256sums=('1fc65857bfdfbbce9de3dec21cb410ffc3eef539d359f9ab221f59bf8a556c6a')

build() {
  cd $_name-python-$pkgver
  python -m build --wheel --no-isolation
}

package() {
  cd $_name-python-$pkgver
  python -m installer --destdir="$pkgdir" dist/*.whl
}

# vim: set ts=2 sw=2 et:
