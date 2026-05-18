#!/usr/bin/env bash
# KPort pacscript — gear/kpim6-kmbox
# Promoted from generated/ — reviewed against KDE Neon Noble Numbat.
#
# library for handling mbox mailboxes

pkgname="kpim6-kmbox"
pkgver="26.04.1"
pkgdesc="library for handling mbox mailboxes"
url="https://invent.kde.org/pim/kmbox"
license=("GPL-2.0-or-later" "LGPL-2.0-or-later")

source=(
  "https://download.kde.org/stable/release-service/26.04.1/src/kmbox-26.04.1.tar.xz"
)
sha256sums=(
  "3f45c677859e15ec16be4c710811022931629cccf29999282ecf63583233bccc"
)

depends=(
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
