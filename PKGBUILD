# Maintainer: Luka Panio <lukapanio@gmail.com>
pkgname=openhdimagewriter
pkgver=2.0.4.3.g8f4d376
pkgrel=1
pkgdesc="OpenHD Image Writer Graphical user-interface to write disk images and format SD cards"
arch=('x86_64' 'aarch64')
url="https://www.openhdfpv.org/"
license=('Apache' 'LGPL3' 'MIT' 'BSD' 'ZLIB' 'custom:PublicDomain' 'custom:libcurl')
depends=(
  'qt5-base'
  'qt5-declarative'
  'qt5-svg'
  'qt5-tools'
  'qt5-quickcontrols2'
  'qt5-graphicaleffects'
  'dosfstools'
  'util-linux'
)
makedepends=('cmake' 'git' 'libarchive' 'curl' 'qt5-base' 'qt5-tools')
optdepends=('udisks2: for device management support')

pkgver() {
  git describe --tags --long | sed 's/^v//;s/-/./g'
}

build() {
  cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr .
  make
}

package() {
  make DESTDIR="$pkgdir" install
}
