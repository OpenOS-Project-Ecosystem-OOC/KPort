#!/usr/bin/env bash
# KPort pacscript — community-32bit/lxqt/libfm-qt
#
# Qt5 file management library used by PCManFM-Qt and the LXQt file dialog.
# Provides file operations, thumbnail generation, and the XDG file dialog.

pkgname="libfm-qt"
pkgver="1.4.0"
pkgdesc="Qt5 file management library"
url="https://github.com/lxqt/libfm-qt"
license=("LGPL-2.1-or-later")

source=(
  "https://github.com/lxqt/libfm-qt/releases/download/${pkgver}/libfm-qt-${pkgver}.tar.xz"
)
sha256sums=(
  "SKIP"
)

depends=(
  "libqtxdg"
  "liblxqt"
  "libqt5core5a"
  "libqt5dbus5"
  "libqt5gui5"
  "libqt5widgets5"
  "libqt5x11extras5"
  "libglib2.0-0"
  "libgio-qt0"
  "libexif12"
  "libmenu-cache3"
)

makedepends=(
  "cmake"
  "ninja-build"
  "lxqt-build-tools"
  "qtbase5-dev"
  "libqt5x11extras5-dev"
  "libglib2.0-dev"
  "libgio-qt-dev"
  "libexif-dev"
  "libmenu-cache-dev"
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
