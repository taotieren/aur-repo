# Maintainer: Boyang Yan <yanboyang713@gmail.com>
# Contributor: Emanuel Couto <unit73e at gmail dot com>
# Contributor: Renato Garcia <fgarcia.renato@gmail.com>
# Contributor: Simon Conseil <contact+aur at saimon dot org>
# Contributor: Misaka13514 <Misaka13514 at gmail dot com>

pkgname=python-sexpdata
_name=${pkgname#python-}
pkgver=1.0.2
pkgrel=3
pkgdesc="S-expression parser for Python"
arch=('any')
url="https://github.com/jd-boyd/sexpdata"
license=('BSD-2-Clause')
depends=('python')
makedepends=('python-build' 'python-installer' 'python-wheel' 'python-setuptools')
source=("$pkgname-$pkgver.tar.gz::$url/archive/v$pkgver.tar.gz")
sha256sums=('a36c99143e778718b33d06db46d8f842736296f44358504c48fc8732663943a8')

build() {
    cd "$_name-$pkgver"
    python -m build --wheel --no-isolation
}

package() {
    cd "$_name-$pkgver"
    python -m installer --destdir="$pkgdir" dist/*.whl
    install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
