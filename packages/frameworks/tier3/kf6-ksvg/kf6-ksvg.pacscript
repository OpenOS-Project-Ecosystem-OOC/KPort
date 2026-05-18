#!/usr/bin/env bash
# KPort pacscript — frameworks/tier3/kf6-ksvg
# Promoted from generated/ — review and test before merging to main
#
# A library for rendering SVG-based themes with stylesheet re-coloring and on-disk caching

# ── Standard Pacstall variables ───────────────────────────────────────────────

pkgname="kf6-ksvg"
pkgver="6.26.0"
pkgdesc="A library for rendering"
url="https://projects.kde.org/projects/frameworks/ksvg"
license=("LGPL-2.0-or-later")

source=(
  "https://download.kde.org/stable/frameworks/6.26/ksvg-6.26.0.tar.xz"
)
sha256sums=(
  "f3a7412e227d13b1cafec91c1b58dd3f86980abefc08b2535b46bef362b4c07e"
)

depends=(
  # No named runtime deps found in debian/control (only ${shlibs:Depends}).
  # Populate after a test build by inspecting ldd output or dpkg -I.
)

makedepends=(
  "cmake"
  "doxygen"
  "graphviz"
  "kf6-extra-cmake-modules"
  "kf6-karchive-dev"
  "kf6-kcolorscheme-dev"
  "kf6-kconfig-dev"
  "kf6-kcoreaddons-dev"
  "kf6-kguiaddons-dev"
  "kf6-kirigami2-dev"
  "qt6-base-dev"
  "qt6-tools-dev"
)

# ── KPort extensions ──────────────────────────────────────────────────────────

KSLOT="6"
KCATEGORY="frameworks/tier3"
KNEON_CHANNEL="unstable"
KCPU_MIN="x86-64-v1"
KGPU_MIN="gpu-sw"

KUSE=(
  "-docs"
  "-test"
)

# ── Build ─────────────────────────────────────────────────────────────────────

build() {
  _kport_lib="${KPORT_LIB_DIR:-/usr/lib/kport}/use-helpers.sh"
  [[ -f "$_kport_lib" ]] && source "$_kport_lib"

  cmake -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DBUILD_TESTING=$(use_flag test ON OFF 2>/dev/null || echo OFF) \
    -DBUILD_QCH=$(use_flag docs ON OFF 2>/dev/null || echo OFF)

  cmake --build build --parallel "$(nproc)"
}

# ── Package ───────────────────────────────────────────────────────────────────

package() {
  DESTDIR="$pkgdir" cmake --install build
}
