#!/usr/bin/env bash
# KPort pacscript — frameworks/tier4/kf6-frameworkintegration
# Promoted from generated/ — review and test before merging to main
#
# Workspace and cross-framework integration plugins

# ── Standard Pacstall variables ───────────────────────────────────────────────

pkgname="kf6-frameworkintegration"
pkgver="6.26.0"
pkgdesc="Workspace and cross-framework integration plugins"
url="https://projects.kde.org/projects/frameworks/frameworkintegration"
license=("LGPL-2.0-or-later")

source=(
  "https://download.kde.org/stable/frameworks/6.26/frameworkintegration-6.26.0.tar.xz"
)
sha256sums=(
  "84ebbad39b559e271bcec4817eba9124903ca660ad4f5c3f73f21a5f4a32062d"
)

depends=(
  # No named runtime deps found in debian/control (only ${shlibs:Depends}).
  # Populate after a test build by inspecting ldd output or dpkg -I.
)

makedepends=(
  "cmake"
  "dbus-x11"
  "kf6-attica-dev"
  "kf6-extra-cmake-modules"
  "kf6-kcolorscheme-dev"
  "kf6-kconfig-dev"
  "kf6-kconfigwidgets"
  "kf6-kcoreaddons-dev"
  "kf6-ki18n-dev"
  "kf6-kiconthemes-dev"
  "kf6-knewstuff-dev"
  "kf6-knotifications-dev"
  "kf6-kpackage-dev"
  "kf6-kwidgetsaddons-dev"
  "kf6-oxygen-icon-theme"
  "libappstreamqt-dev"
  "libpackagekitqt6-dev"
  "libxcursor-dev"
  "pkgconf"
  "qt6-base-dev"
  "qt6-tools-dev"
)

# ── KPort extensions ──────────────────────────────────────────────────────────

KSLOT="6"
KCATEGORY="frameworks/tier4"
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
