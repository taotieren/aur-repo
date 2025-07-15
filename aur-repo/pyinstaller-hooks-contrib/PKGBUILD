# Maintainer: envolution
# Contributor: Mark Wagie <mark dot wagie at proton dot me>
# Contributor: Sam <dev at samarthj dot com>
pkgname=pyinstaller-hooks-contrib
pkgver=2025.6
pkgrel=1
pkgdesc="Community maintained hooks for PyInstaller"
arch=('any')
url="https://github.com/pyinstaller/pyinstaller-hooks-contrib"
license=('Apache-2.0 OR GPL-2.0-or-later')
depends=(
  'python'
)
makedepends=(
  'python-build'
  'python-installer'
  'python-wheel'
  'python-setuptools'
)
source=("$pkgname-$pkgver.tar.gz::$url/archive/refs/tags/v$pkgver.tar.gz")
sha256sums=('08ad3fd63bee08e0c3255d0d9af53ca7f175fe36fc49b17c4cd561e40732dcc3')

build() {
  cd "$pkgname-$pkgver"
  python -m build --wheel --no-isolation
}

package() {
  cd "$pkgname-$pkgver"
  python -m installer --destdir="$pkgdir" dist/*.whl
}

# vim: ts=2 sw=2 et:
