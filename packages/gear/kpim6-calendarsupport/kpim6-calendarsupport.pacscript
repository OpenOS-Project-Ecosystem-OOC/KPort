#!/usr/bin/env bash
# KPort pacscript — gear/kpim6-calendarsupport
# Promoted from generated/ — reviewed against KDE Neon Noble Numbat.
#
# KDE PIM Calendar support - library

pkgname="kpim6-calendarsupport"
pkgver="26.04.1"
pkgdesc="KDE PIM Calendar support - library"
url="https://invent.kde.org/pim/calendarsupport"
license=("GPL-2.0-or-later" "LGPL-2.0-or-later")

source=(
  "https://download.kde.org/stable/release-service/26.04.1/src/calendarsupport-26.04.1.tar.xz"
)
sha256sums=(
  "33938e93ffe71f29d3fd274fce0b7d1e9571763bc99a73a8060f862ab3ccedb9"
)

depends=(
  "kf6-kcolorscheme"
  "kf6-kcalendarcore"
  "kf6-kcodecs"
  "kf6-kconfig"
  "kf6-kcoreaddons"
  "kf6-kguiaddons"
  "kf6-kholidays"
  "kf6-ki18n"
  "kf6-kio"
  "kf6-kservice"
  "kf6-kwidgetsaddons"
  "kpim6-akonadi-mime"
  "kpim6-akonadi-calendar"
  "kpim6-kcalendarutils"
  "kpim6-kidentitymanagement"
  "kpim6-kmime"
  "qt6-base"
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
