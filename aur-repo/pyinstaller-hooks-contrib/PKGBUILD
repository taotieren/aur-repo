# Contributor: Mark Wagie <mark dot wagie at proton dot me>
# Contributor: Sam <dev at samarthj dot com>
pkgname=pyinstaller-hooks-contrib
pkgver=2024.7
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
source=("$pkgname-$pkgver.tar.gz::$url/archive/refs/tags/$pkgver.tar.gz")
sha256sums=('1d8ec7227f3ac1aeabd19c8bd71ad35eee07a0c202adb640164290971fdd752c')

build() {
  cd "$pkgname-$pkgver"
  python -m build --wheel --no-isolation
}

package() {
  cd "$pkgname-$pkgver"
  python -m installer --destdir="$pkgdir" dist/*.whl
}
