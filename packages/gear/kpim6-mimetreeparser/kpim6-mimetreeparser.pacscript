#!/usr/bin/env bash
# KPort pacscript — gear/kpim6-mimetreeparser
# Promoted from generated/ — reviewed against KDE Neon Noble Numbat.
#
# library for handling MIME data

pkgname="kpim6-mimetreeparser"
pkgver="26.04.1"
pkgdesc="library for handling MIME data"
url="https://invent.kde.org/pim/mimetreeparser"
license=("GPL-2.0-or-later" "LGPL-2.0-or-later")

source=(
  "https://download.kde.org/stable/release-service/26.04.1/src/mimetreeparser-26.04.1.tar.xz"
)
sha256sums=(
  "5aeec9af9b3d589a948350d32f8724b142a8c82ad0c5465b4e934b6159f68219"
)

depends=(
  "kf6-kirigami"
  "kf6-kirigami-addons"
  "kpim6-itinerary"
  "~apt:qml6-module-qtwebengine"
  "kf6-kcalendarcore"
  "kf6-kcolorscheme"
  "kf6-ki18n"
  "kf6-kio"
  "kf6-kservice"
  "kf6-kwidgetsaddons"
  "kpim6-kmbox"
  "kpim6-kmime"
  "kpim6-libkleo"
  "~apt:libgpgmepp7"
  "~apt:libqgpgmeqt6-15"
  "qt6-base"
  "qt6-declarative"
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
