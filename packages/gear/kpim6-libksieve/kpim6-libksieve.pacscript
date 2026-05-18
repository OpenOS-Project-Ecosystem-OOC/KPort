#!/usr/bin/env bash
# KPort pacscript — gear/kpim6-libksieve
# Promoted from generated/ — reviewed against KDE Neon Noble Numbat.
#
# Sieve mail filtering language support for kdepim, development files

pkgname="kpim6-libksieve"
pkgver="26.04.1"
pkgdesc="Sieve mail filtering language support for kdepim, development files"
url="https://invent.kde.org/pim/libksieve"
license=("GPL-2.0-or-later" "LGPL-2.0-or-later")

source=(
  "https://download.kde.org/stable/release-service/26.04.1/src/libksieve-26.04.1.tar.xz"
)
sha256sums=(
  "63619eaa7df0a2aba8bf206e89c9fea8fa000fd404f80732abfd1c75fc87ef25"
)

depends=(
  "qt6-base"
  "kf6-kcolorscheme"
  "kf6-kcompletion"
  "kf6-kconfig"
  "kf6-kcoreaddons"
  "kf6-ki18n"
  "kf6-kiconthemes"
  "kf6-kio"
  "kf6-ktextaddons"
  "kf6-kwidgetsaddons"
  "kf6-sonnet"
  "kf6-syntax-highlighting"
  "kpim6-kidentitymanagement"
  "kpim6-kmime"
  "kpim6-libkdepim"
  "kpim6-pimcommon"
  "~apt:libsasl2-2"
  "qt6-webengine"
)

makedepends=()

KCATEGORY="gear"
KSLOT="6"

build() {
  cmake -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DBUILD_TESTING=OFF

  cmake --build build --parallel "$(nproc)"
}

package() {
  DESTDIR="$pkgdir" cmake --install build
}
