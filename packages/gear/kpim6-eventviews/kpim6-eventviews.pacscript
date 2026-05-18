#!/usr/bin/env bash
# KPort pacscript — gear/kpim6-eventviews
# Promoted from generated/ — reviewed against KDE Neon Noble Numbat.
#
# KDE PIM event handling - library

pkgname="kpim6-eventviews"
pkgver="26.04.1"
pkgdesc="KDE PIM event handling - library"
url="https://invent.kde.org/pim/eventviews"
license=("GPL-2.0-or-later" "LGPL-2.0-or-later")

source=(
  "https://download.kde.org/stable/release-service/26.04.1/src/eventviews-26.04.1.tar.xz"
)
sha256sums=(
  "3b34ba8bbb40d97cebb63136e1efede3303ff4cb12e0a73d41b090e15760577b"
)

depends=(
  "kf6-kcalendarcore"
  "kf6-kcodecs"
  "kf6-kcolorscheme"
  "kf6-kcompletion"
  "kf6-kconfig"
  "kf6-kconfigwidgets"
  "kf6-kcontacts"
  "kf6-kcoreaddons"
  "kf6-kguiaddons"
  "kf6-kholidays"
  "kf6-ki18n"
  "kf6-kiconthemes"
  "kf6-kitemmodels"
  "kf6-kwidgetsaddons"
  "kpim6-akonadi-mime"
  "kpim6-akonadi-calendar"
  "kpim6-calendarsupport"
  "kpim6-kcalendarutils"
  "kpim6-libkdepim"
  "~apt:libkgantt6-3"
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
