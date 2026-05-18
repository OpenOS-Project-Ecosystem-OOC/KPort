#!/usr/bin/env bash
# KPort pacscript — community-32bit/lxqt/lxqt-build-tools
#
# CMake modules and scripts shared by all LXQt components.
# Build-time only — nothing is installed to /usr/lib at runtime.
# This is the Qt5-based 0.13.0 release, the last before the Qt6 port
# (lxqt2-build-tools). Required by all other LXQt 1.4.x pacscripts.

pkgname="lxqt-build-tools"
pkgver="0.13.0"
pkgdesc="LXQt build tools and CMake modules (Qt5, i686-compatible)"
url="https://github.com/lxqt/lxqt-build-tools"
license=("LGPL-2.1-or-later")

source=(
  "https://github.com/lxqt/lxqt-build-tools/releases/download/${pkgver}/lxqt-build-tools-${pkgver}.tar.xz"
)
sha256sums=(
  "SKIP"
)

makedepends=(
  "cmake"
  "ninja-build"
  "qtbase5-dev"
  "pkg-config"
)

# ── KPort extensions ──────────────────────────────────────────────────────────

KSLOT="0"
KCATEGORY="lxqt"
KNEON_CHANNEL="stable"
KCPU_MIN="i686-baseline"
KGPU_MIN="gpu-sw"

# ── Build ─────────────────────────────────────────────────────────────────────

build() {
  cmake -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_C_FLAGS="${CFLAGS:--m32}" \
    -DCMAKE_CXX_FLAGS="${CXXFLAGS:--m32}"

  cmake --build build --parallel "$(nproc)"
}

# ── Package ───────────────────────────────────────────────────────────────────

package() {
  DESTDIR="$pkgdir" cmake --install build
}
