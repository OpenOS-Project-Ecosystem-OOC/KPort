#!/usr/bin/env bash
# KPort pacscript — community-32bit/lxqt/lximage-qt
#
# LXQt image viewer. Supports common formats via Qt's image plugins,
# basic editing (rotate, flip, crop), slideshow, and screenshot capture.

pkgname="lximage-qt"
pkgver="1.4.0"
pkgdesc="LXQt image viewer (Qt5)"
url="https://github.com/lxqt/lximage-qt"
license=("GPL-2.0-or-later")

source=(
  "https://github.com/lxqt/lximage-qt/releases/download/${pkgver}/lximage-qt-${pkgver}.tar.xz"
)
sha256sums=(
  "SKIP"
)

depends=(
  "libfm-qt"
  "liblxqt"
  "libqt5core5a"
  "libqt5dbus5"
  "libqt5gui5"
  "libqt5widgets5"
  "libqt5x11extras5"
  "libqt5svg5"
  "libexif12"
)

makedepends=(
  "cmake"
  "ninja-build"
  "lxqt-build-tools"
  "qtbase5-dev"
  "libqt5x11extras5-dev"
  "libqt5svg5-dev"
  "libexif-dev"
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
