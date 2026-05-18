#!/usr/bin/env bash
# KPort pacscript — community-32bit-plasma5/plasma/kdecoration
#
# Window decoration plugin API used by KWin. Provides the C++ interface
# that decoration themes (Breeze, Aurorae, etc.) implement.

pkgname="kdecoration"
pkgver="5.27.12"
pkgdesc="KDE window decoration plugin API (Qt5/KF5, i686)"
url="https://kde.org/plasma-desktop/"
license=("LGPL-2.1-or-later")

source=(
  "https://download.kde.org/stable/plasma/${pkgver}/kdecoration-${pkgver}.tar.xz"
)
sha256sums=(
  "SKIP"
)

depends=(
  "libkf5i18n5"
  "libqt5core5a"
  "libqt5dbus5"
  "libqt5gui5"
)

makedepends=(
  "cmake"
  "ninja-build"
  "extra-cmake-modules"
  "qtbase5-dev"
  "libkf5i18n-dev"
  "pkg-config"
)

# ── KPort extensions ──────────────────────────────────────────────────────────

KSLOT="5"
KCATEGORY="plasma"
KNEON_CHANNEL="stable"
KCPU_MIN="i686-baseline"
KGPU_MIN="gpu-sw"

KUSE=(
  "-test"
)

# ── Build ─────────────────────────────────────────────────────────────────────

build() {
  _kport_lib="${KPORT_LIB_DIR:-/usr/lib/kport}/use-helpers.sh"
  [[ -f "$_kport_lib" ]] && source "$_kport_lib"

  cmake -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_C_FLAGS="${CFLAGS:--m32}" \
    -DCMAKE_CXX_FLAGS="${CXXFLAGS:--m32}" \
    -DBUILD_TESTING=$(use_flag test ON OFF 2>/dev/null || echo OFF)

  cmake --build build --parallel "$(nproc)"
}

# ── Package ───────────────────────────────────────────────────────────────────

package() {
  DESTDIR="$pkgdir" cmake --install build
}
