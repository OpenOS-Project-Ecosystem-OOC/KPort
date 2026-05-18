#!/usr/bin/env bash
# KPort pacscript — community-32bit-plasma5/system/libksysguard
#
# Process and resource monitoring library. Provides the backend for
# ksystemstats, the System Monitor applet, and the task manager.

pkgname="libksysguard"
pkgver="5.27.12"
pkgdesc="KDE process and resource monitoring library (Qt5/KF5, i686)"
url="https://kde.org/plasma-desktop/"
license=("GPL-2.0-or-later" "LGPL-2.1-or-later")

source=(
  "https://download.kde.org/stable/plasma/${pkgver}/libksysguard-${pkgver}.tar.xz"
)
sha256sums=(
  "SKIP"
)

depends=(
  "libkf5config5"
  "libkf5coreaddons5"
  "libkf5declarative5"
  "libkf5i18n5"
  "libkf5service5"
  "libkf5windowsystem5"
  "libqt5core5a"
  "libqt5dbus5"
  "libqt5gui5"
  "libqt5quick5"
  "libqt5widgets5"
  "libqt5x11extras5"
  "libpcap0.8"
  "libnl-3-200"
  "libnl-route-3-200"
)

makedepends=(
  "cmake"
  "ninja-build"
  "extra-cmake-modules"
  "qtbase5-dev"
  "qtdeclarative5-dev"
  "libqt5x11extras5-dev"
  "libkf5config-dev"
  "libkf5coreaddons-dev"
  "libkf5declarative-dev"
  "libkf5i18n-dev"
  "libkf5service-dev"
  "libkf5windowsystem-dev"
  "libpcap-dev"
  "libnl-3-dev"
  "libnl-route-3-dev"
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
