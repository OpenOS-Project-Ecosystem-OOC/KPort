#!/usr/bin/env bash
# KPort pacscript — community-32bit-plasma5/system/ksystemstats
#
# System statistics daemon: exposes CPU, memory, network, disk, and GPU
# metrics over D-Bus for the System Monitor applet and task manager.

pkgname="ksystemstats"
pkgver="5.27.12"
pkgdesc="KDE system statistics daemon (Qt5/KF5, i686)"
url="https://kde.org/plasma-desktop/"
license=("GPL-2.0-or-later" "LGPL-2.1-or-later")

source=(
  "https://download.kde.org/stable/plasma/${pkgver}/ksystemstats-${pkgver}.tar.xz"
)
sha256sums=(
  "SKIP"
)

depends=(
  "libksysguard"
  "libkf5config5"
  "libkf5coreaddons5"
  "libkf5dbusaddons5"
  "libkf5i18n5"
  "libkf5solid5"
  "libqt5core5a"
  "libqt5dbus5"
  "libqt5network5"
  "libnl-3-200"
  "libnl-route-3-200"
  "libudev1"
)

makedepends=(
  "cmake"
  "ninja-build"
  "extra-cmake-modules"
  "qtbase5-dev"
  "libkf5config-dev"
  "libkf5coreaddons-dev"
  "libkf5dbusaddons-dev"
  "libkf5i18n-dev"
  "libkf5solid-dev"
  "libnl-3-dev"
  "libnl-route-3-dev"
  "libudev-dev"
  "pkg-config"
)

# ── KPort extensions ──────────────────────────────────────────────────────────

KSLOT="5"
KCATEGORY="system"
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
