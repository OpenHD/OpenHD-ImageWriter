# Maintainer: Luka Panio <lukapanio@gmail.com>
pkgname=openhdimagewriter
pkgver=2.0.4.3.g8f4d376
pkgrel=1
pkgdesc="OpenHD Image Writer Graphical user-interface to write disk images and format SD cards"
arch=('x86_64' 'aarch64')
url="https://www.openhdfpv.org/"
license=('Apache' 'LGPL3' 'MIT' 'BSD' 'ZLIB' 'custom:PublicDomain' 'custom:libcurl')
depends=(
  'qt6-base'
  'qt6-declarative'
  'qt6-svg'
  'qt6-tools'
  'qt6-quickcontrols2'
  'qt6-quickeffects'
  'dosfstools'
  'util-linux'
)
makedepends=('cmake' 'git' 'libarchive' 'curl' 'qt6-base' 'qt6-tools')
optdepends=('udisks2: for device management support')

pkgver() {
  git describe --tags --long | sed 's/^v//;s/-/./g'
}

build() {
  cd src
  cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_POLICY_VERSION_MINIMUM=3.5 .
  make
}

package() {
  cd src
  make DESTDIR="$pkgdir" install
}
