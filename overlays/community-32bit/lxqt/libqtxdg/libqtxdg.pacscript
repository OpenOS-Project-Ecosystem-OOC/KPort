#!/usr/bin/env bash
# KPort pacscript — community-32bit/lxqt/libqtxdg
#
# Qt5 implementation of XDG standards (icon themes, desktop entries, MIME).
# Required by liblxqt and most LXQt components.
# Version 3.12.0 is the last Qt5 release; 4.x requires Qt 6.

pkgname="libqtxdg"
pkgver="3.12.0"
pkgdesc="Qt5 implementation of XDG standards"
url="https://github.com/lxqt/libqtxdg"
license=("LGPL-2.1-or-later")

source=(
  "https://github.com/lxqt/libqtxdg/releases/download/${pkgver}/libqtxdg-${pkgver}.tar.xz"
)
sha256sums=(
  "SKIP"
)

depends=(
  "libqt5core5a"
  "libqt5gui5"
  "libqt5svg5"
  "libqt5xml5"
  "libglib2.0-0"
)

makedepends=(
  "cmake"
  "ninja-build"
  "lxqt-build-tools"
  "qtbase5-dev"
  "libqt5svg5-dev"
  "libglib2.0-dev"
  "pkg-config"
)

# ── KPort extensions ──────────────────────────────────────────────────────────

KSLOT="0"
KCATEGORY="lxqt"
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
    -DBUILD_TESTS=$(use_flag test ON OFF 2>/dev/null || echo OFF)

  cmake --build build --parallel "$(nproc)"
}

# ── Package ───────────────────────────────────────────────────────────────────

package() {
  DESTDIR="$pkgdir" cmake --install build
}
