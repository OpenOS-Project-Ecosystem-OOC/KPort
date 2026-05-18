#!/usr/bin/env bash
# KPort pacscript — frameworks/tier1/kf6-kuserfeedback
# Promoted from generated/ — review and test before merging to main
#
# User feedback framework

# ── Standard Pacstall variables ───────────────────────────────────────────────

pkgname="kf6-kuserfeedback"
pkgver="6.26.0"
pkgdesc="User feedback framework"
url="https://invent.kde.org/libraries/kuserfeedback"
license=("LGPL-2.0-or-later")

source=(
  "https://download.kde.org/stable/frameworks/6.26/kuserfeedback-6.26.0.tar.xz"
)
sha256sums=(
  "6cc18dca65a24af2ac262cb9c8761991701c8081a7133487b4ec936003f3f864"
)

depends=(
  # No named runtime deps found in debian/control (only ${shlibs:Depends}).
  # Populate after a test build by inspecting ldd output or dpkg -I.
)

makedepends=(
  "bison"
  "cmake"
  "flex"
  "kf6-extra-cmake-modules"
  "phpunit"
  "qt6-base-dev"
  "qt6-charts-dev"
  "qt6-doc-dev"
  "qt6-declarative-dev"
  "qt6-svg-dev"
  "qt6-tools-dev"
  "xauth"
  "xvfb"
)

# ── KPort extensions ──────────────────────────────────────────────────────────

KSLOT="6"
KCATEGORY="frameworks/tier1"
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
