# Maintainer: Raphael Scholle <raphael@openhdfpv.org>
pkgname=openhdimagewriter-git
pkgver=r68.gbff5f64
pkgrel=1
pkgdesc='Graphical utility to write OpenHD disk images and format SD cards'
arch=('x86_64' 'aarch64')
url='https://github.com/OpenHD/OpenHD-ImageWriter'
license=('Apache-2.0')
depends=('qt5-base' 'qt5-declarative' 'qt5-svg' 'qt5-quickcontrols'
         'qt5-quickcontrols2' 'qt5-graphicaleffects' 'curl' 'libarchive'
         'openssl' 'zlib' 'xz' 'dosfstools' 'util-linux')
makedepends=('cmake' 'ninja' 'git' 'qt5-tools')
checkdepends=('nodejs')
optdepends=('udisks2: desktop authorization and device management')
provides=('openhdimagewriter')
conflicts=('openhdimagewriter')
source=('OpenHD-ImageWriter::git+https://github.com/OpenHD/OpenHD-ImageWriter.git#branch=dev-branch')
sha256sums=('SKIP')

pkgver() {
  cd "$srcdir/OpenHD-ImageWriter"
  printf 'r%s.g%s' "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
}

build() {
  cmake -S "$srcdir/OpenHD-ImageWriter/src" -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=None -DCMAKE_INSTALL_PREFIX=/usr \
    -DBUILD_TESTING=ON
  cmake --build build
}

check() {
  ctest --test-dir build --output-on-failure
}

package() {
  DESTDIR="$pkgdir" cmake --install build
  install -Dm644 "$srcdir/OpenHD-ImageWriter/license.txt" \
    "$pkgdir/usr/share/licenses/$pkgname/license.txt"
}
