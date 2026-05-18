#!/usr/bin/env bash
# KPort pacscript — frameworks/tier2/kf6-kstatusnotifieritem
# Promoted from generated/ — review and test before merging to main
#
# Implementation of Status Notifier Items

# ── Standard Pacstall variables ───────────────────────────────────────────────

pkgname="kf6-kstatusnotifieritem"
pkgver="6.26.0"
pkgdesc="Implementation of Status Notifier Items"
url="https://invent.kde.org/frameworks/kstatusnotifieritem"
license=("LGPL-2.0-or-later")

source=(
  "https://download.kde.org/stable/frameworks/6.26/kstatusnotifieritem-6.26.0.tar.xz"
)
sha256sums=(
  "898914c94820f99889d879f33cabbb5fbe7b9f4e24a6a1d9a9b4439489bc3266"
)

depends=(
  "python3-pyside6.qtcore"
)

makedepends=(
  "bison"
  "cmake"
  "dh-python"
  "dh-sequence-python3"
  "doxygen"
  "flex"
  "graphviz"
  "kf6-extra-cmake-modules"
  "kf6-kwindowsystem-dev"
  "libclang-dev"
  "libpyside6-dev"
  "libpython3-dev"
  "libshiboken6-dev"
  "python3-dev"
  "python3-build"
  "pyside6-tools"
  "qt6-base-dev"
  "qt6-tools-dev"
  "xauth"
  "xvfb"
)

# ── KPort extensions ──────────────────────────────────────────────────────────

KSLOT="6"
KCATEGORY="frameworks/tier2"
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
