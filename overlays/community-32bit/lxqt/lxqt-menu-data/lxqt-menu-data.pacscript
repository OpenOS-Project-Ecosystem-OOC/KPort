#!/usr/bin/env bash
# KPort pacscript — community-32bit/lxqt/lxqt-menu-data
#
# XDG menu definitions for LXQt. Pure data package — no compiled output.
# Replaces the older lxmenu-data package used by LXQt 1.3.x and earlier.

pkgname="lxqt-menu-data"
pkgver="1.4.0"
pkgdesc="XDG menu definitions for LXQt"
url="https://github.com/lxqt/lxqt-menu-data"
license=("LGPL-2.1-or-later")

source=(
  "https://github.com/lxqt/lxqt-menu-data/releases/download/${pkgver}/lxqt-menu-data-${pkgver}.tar.xz"
)
sha256sums=(
  "SKIP"
)

makedepends=(
  "cmake"
  "ninja-build"
  "lxqt-build-tools"
)

# ── KPort extensions ──────────────────────────────────────────────────────────

KSLOT="0"
KCATEGORY="lxqt"
KNEON_CHANNEL="stable"
# Pure data — no KCPU_MIN, installs on any arch
KGPU_MIN="gpu-sw"

# ── Build ─────────────────────────────────────────────────────────────────────

build() {
  cmake -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr

  cmake --build build --parallel "$(nproc)"
}

# ── Package ───────────────────────────────────────────────────────────────────

package() {
  DESTDIR="$pkgdir" cmake --install build
}
