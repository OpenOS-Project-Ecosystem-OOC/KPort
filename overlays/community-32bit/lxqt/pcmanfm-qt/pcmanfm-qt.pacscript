#!/usr/bin/env bash
# KPort pacscript — community-32bit/lxqt/pcmanfm-qt
#
# LXQt file manager and desktop manager. Handles file browsing, desktop icons,
# wallpaper, and trash. Uses libfm-qt for all file operations.

pkgname="pcmanfm-qt"
pkgver="1.4.0"
pkgdesc="LXQt file manager (Qt5)"
url="https://github.com/lxqt/pcmanfm-qt"
license=("GPL-2.0-or-later")

source=(
  "https://github.com/lxqt/pcmanfm-qt/releases/download/${pkgver}/pcmanfm-qt-${pkgver}.tar.xz"
)
sha256sums=(
  "SKIP"
)

depends=(
  "libfm-qt"
  "liblxqt"
  "libqtxdg"
  "lxqt-menu-data"
  "libqt5core5a"
  "libqt5dbus5"
  "libqt5gui5"
  "libqt5widgets5"
  "libqt5x11extras5"
  "libxfixes3"
)

makedepends=(
  "cmake"
  "ninja-build"
  "lxqt-build-tools"
  "qtbase5-dev"
  "libqt5x11extras5-dev"
  "libxfixes-dev"
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
