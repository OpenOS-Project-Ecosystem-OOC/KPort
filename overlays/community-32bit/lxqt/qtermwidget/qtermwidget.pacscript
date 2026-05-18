#!/usr/bin/env bash
# KPort pacscript — community-32bit/lxqt/qtermwidget
#
# Qt5 terminal emulator widget library used by QTerminal.
# Provides VTE-equivalent functionality: PTY handling, colour schemes,
# scrollback, and Unicode/bidi rendering.

pkgname="qtermwidget"
pkgver="1.4.0"
pkgdesc="Qt5 terminal emulator widget library"
url="https://github.com/lxqt/qtermwidget"
license=("GPL-2.0-or-later" "LGPL-2.0-or-later")

source=(
  "https://github.com/lxqt/qtermwidget/releases/download/${pkgver}/qtermwidget-${pkgver}.tar.xz"
)
sha256sums=(
  "SKIP"
)

depends=(
  "libqt5core5a"
  "libqt5gui5"
  "libqt5widgets5"
  "libutempter0"
)

makedepends=(
  "cmake"
  "ninja-build"
  "lxqt-build-tools"
  "qtbase5-dev"
  "libutempter-dev"
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
