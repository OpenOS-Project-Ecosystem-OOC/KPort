#!/usr/bin/env bash
# KPort pacscript — community-32bit/lxqt/lxqt-themes
#
# LXQt QSS stylesheets, wallpapers, and theme assets.
# Pure data — no compiled output, installs on any arch.

pkgname="lxqt-themes"
pkgver="1.4.0"
pkgdesc="LXQt themes, stylesheets, and wallpapers"
url="https://github.com/lxqt/lxqt-themes"
license=("LGPL-2.1-or-later")

source=(
  "https://github.com/lxqt/lxqt-themes/releases/download/${pkgver}/lxqt-themes-${pkgver}.tar.xz"
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
# Pure data — no KCPU_MIN
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
