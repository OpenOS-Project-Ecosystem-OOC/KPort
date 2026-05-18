#!/usr/bin/env bash
# KPort pacscript — community-32bit/lxqt/lxqt-panel
#
# LXQt desktop panel with taskbar, system tray, clock, launcher, and
# application menu plugins. Supports X11; Wayland support is partial in 1.4.x.

pkgname="lxqt-panel"
pkgver="1.4.0"
pkgdesc="LXQt desktop panel (Qt5)"
url="https://github.com/lxqt/lxqt-panel"
license=("LGPL-2.1-or-later")

source=(
  "https://github.com/lxqt/lxqt-panel/releases/download/${pkgver}/lxqt-panel-${pkgver}.tar.xz"
)
sha256sums=(
  "SKIP"
)

depends=(
  "liblxqt"
  "libqtxdg"
  "lxqt-menu-data"
  "libqt5core5a"
  "libqt5dbus5"
  "libqt5gui5"
  "libqt5widgets5"
  "libqt5x11extras5"
  "libqt5svg5"
  "libkf5windowsystem5"
  "libxcomposite1"
  "libxdamage1"
  "libxrender1"
  "libxrandr2"
  "libxkbcommon0"
  "solid-dev"
)

makedepends=(
  "cmake"
  "ninja-build"
  "lxqt-build-tools"
  "qtbase5-dev"
  "libqt5x11extras5-dev"
  "libqt5svg5-dev"
  "libkf5windowsystem-dev"
  "libkf5solid-dev"
  "libxcomposite-dev"
  "libxdamage-dev"
  "libxrender-dev"
  "libxrandr-dev"
  "libxkbcommon-dev"
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
