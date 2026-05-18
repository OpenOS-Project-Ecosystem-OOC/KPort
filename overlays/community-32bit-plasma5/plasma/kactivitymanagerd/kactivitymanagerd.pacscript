#!/usr/bin/env bash
# KPort pacscript — community-32bit-plasma5/plasma/kactivitymanagerd
#
# Activities daemon: tracks which windows/documents belong to which activity,
# stores activity metadata, and provides the D-Bus API used by plasma-workspace.

pkgname="kactivitymanagerd"
pkgver="5.27.12"
pkgdesc="KDE Activities manager daemon (Qt5/KF5, i686)"
url="https://kde.org/plasma-desktop/"
license=("GPL-2.0-or-later" "LGPL-2.1-or-later")

source=(
  "https://download.kde.org/stable/plasma/${pkgver}/kactivitymanagerd-${pkgver}.tar.xz"
)
sha256sums=(
  "SKIP"
)

depends=(
  "libkf5activities5"
  "libkf5config5"
  "libkf5coreaddons5"
  "libkf5i18n5"
  "libkf5windowsystem5"
  "libqt5core5a"
  "libqt5dbus5"
  "libqt5sql5"
  "libqt5sql5-sqlite"
)

makedepends=(
  "cmake"
  "ninja-build"
  "extra-cmake-modules"
  "qtbase5-dev"
  "libkf5activities-dev"
  "libkf5config-dev"
  "libkf5coreaddons-dev"
  "libkf5i18n-dev"
  "libkf5windowsystem-dev"
  "pkg-config"
)

# ── KPort extensions ──────────────────────────────────────────────────────────

KSLOT="5"
KCATEGORY="plasma"
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
    -DBUILD_TESTING=$(use_flag test ON OFF 2>/dev/null || echo OFF)

  cmake --build build --parallel "$(nproc)"
}

# ── Package ───────────────────────────────────────────────────────────────────

package() {
  DESTDIR="$pkgdir" cmake --install build
}
