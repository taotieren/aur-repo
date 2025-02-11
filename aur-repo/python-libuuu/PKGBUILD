# Maintainer: Maud Spierings <maud_spierings@hotmail.com>

pkgname=python-libuuu
pkgver=1.5.201
pkgrel=1
pkgdesc='A python wrapper for libuuu'
arch=('x86_64' 'aarch64')
url='https://github.com/nxp-imx/mfgtools'
license=(BSD-3-Clause)
depends=('bzip2' 'zlib' 'libusb' 'libzip' 'openssl' 'tinyxml2' 'python-setuptools-scm')
makedepends=('meson' 'git' 'cmake' 'python-build' 'python-installer' 'python-wheel' 'zip' 'unzip')
changelog=History.md
source=(
	"git+$url#commit=727fc2b782156419a167ebfc8d9a4204ad2eedbf" # 1.5.201
	"git+https://github.com/microsoft/vcpkg.git"
)
sha256sums=('88ab7f5858a0fb84c6949f13062b4253f306e0788847b19be9483e52c059e9ee'
            'SKIP')

build() {
	export VCPKG_FORCE_SYSTEM_BINARIES=1
	cd "${srcdir}"

	export VCPKG_ROOT="${srcdir}/vcpkg"
	$VCPKG_ROOT/bootstrap-vcpkg.sh -disableMetrics

	cd mfgtools/wrapper
	cmake \
		--preset unix \
		-B build \
		-DCMAKE_TOOLCHAIN_FILE="${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake"
	cmake --build build
	mkdir -p libuuu/lib
	cp build/libuuu.so libuuu/lib
	python -m build --wheel --no-isolation
}

package() {
	cd "${srcdir}/mfgtools/wrapper"
	python -m installer --destdir="${pkgdir}" dist/libuuu-${pkgver}-py3-none-any.whl
	install -Dm644 LICENSE -t "${pkgdir}/usr/share/licenses/${pkgname}/"
}

