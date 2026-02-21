# Maintainer: taotieren <admin@taotieren.com>

pkgname=moltis
pkgver=0.9.8
pkgrel=1
pkgdesc="A personal AI gateway written in Rust. One binary, no runtime, no npm."
arch=($CARCH)
url="https://github.com/moltis-org/moltis"
license=('MIT')
provides=(
    ${pkgname}
)
conflicts=(
    ${pkgname}
)
replaces=()
depends=(
    gcc-libs
    glibc
    openssl
    systemd-libs)
makedepends=(
    clang
    cargo
    cmake
    cuda
    git
)
backup=()
options=(!lto !debug)
install=
source=("${pkgname}::git+${url}.git#tag=v${pkgver}")
sha256sums=('2795b009a7b7433ce18ceecb4a8c1034023ed36be77da1055ada5371d569022e')

prepare() {
    cd "${srcdir}/${pkgname}"
    export RUSTUP_TOOLCHAIN=stable
    cargo fetch --locked --target "$(rustc -vV | sed -n 's/host: //p')"
    cargo fetch --target "$CARCH-unknown-linux-gnu"
}

build() {
    cd "${srcdir}/${pkgname}/"

    export RUSTUP_TOOLCHAIN=stable
    export CARGO_TARGET_DIR=target
    cargo build --release --all-features

}

# check() {
#     cd "${srcdir}/${pkgname}/"
#
#     export RUSTUP_TOOLCHAIN=stable
#     cargo test --all-features
# }

package() {
    cd "${srcdir}/${pkgname}/"

    export RUSTUP_TOOLCHAIN=stable
    #     cargo install --no-track --all-features --root "$pkgdir/usr/" --path .
    install -Dm0644 README.md -t "${pkgdir}/usr/share/doc/${pkgname}"
    install -Dm0644 LICENSE.md -t ${pkgdir}/usr/share/licenses/${pkgname}/

    find target/release \
        -maxdepth 1 \
        -executable \
        -type f \
        -exec install -Dm0755 -t "$pkgdir/usr/bin/" {} +
}
