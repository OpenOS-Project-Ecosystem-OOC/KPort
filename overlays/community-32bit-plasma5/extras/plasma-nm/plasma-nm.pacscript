#!/usr/bin/env bash
# KPort pacscript — community-32bit-plasma5/extras/plasma-nm
#
# NetworkManager applet for the Plasma system tray. Manages Wi-Fi, Ethernet,
# VPN, and mobile broadband connections via NetworkManager D-Bus API.

pkgname="plasma-nm"
pkgver="5.27.12"
pkgdesc="KDE NetworkManager applet for Plasma (Qt5/KF5, i686)"
url="https://kde.org/plasma-desktop/"
license=("GPL-2.0-or-later" "LGPL-2.1-or-later")

source=(
  "https://download.kde.org/stable/plasma/${pkgver}/plasma-nm-${pkgver}.tar.xz"
)
sha256sums=(
  "SKIP"
)

depends=(
  "plasma-framework"
  "libkf5config5"
  "libkf5configwidgets5"
  "libkf5coreaddons5"
  "libkf5dbusaddons5"
  "libkf5declarative5"
  "libkf5i18n5"
  "libkf5iconthemes5"
  "libkf5kio5"
  "libkf5notifications5"
  "libkf5plasma5"
  "libkf5service5"
  "libkf5wallet5"
  "libkf5widgetsaddons5"
  "libkf5windowsystem5"
  "libqt5core5a"
  "libqt5dbus5"
  "libqt5gui5"
  "libqt5network5"
  "libqt5quick5"
  "libqt5widgets5"
  "network-manager"
  "libnm0"
  "modemmanager"
)

makedepends=(
  "cmake"
  "ninja-build"
  "extra-cmake-modules"
  "qtbase5-dev"
  "qtdeclarative5-dev"
  "libkf5config-dev"
  "libkf5configwidgets-dev"
  "libkf5coreaddons-dev"
  "libkf5dbusaddons-dev"
  "libkf5declarative-dev"
  "libkf5i18n-dev"
  "libkf5iconthemes-dev"
  "libkf5kio-dev"
  "libkf5notifications-dev"
  "libkf5plasma-dev"
  "libkf5service-dev"
  "libkf5wallet-dev"
  "libkf5widgetsaddons-dev"
  "libkf5windowsystem-dev"
  "libnm-dev"
  "libmm-glib-dev"
  "pkg-config"
)

# ── KPort extensions ──────────────────────────────────────────────────────────

KSLOT="5"
KCATEGORY="extras"
KNEON_CHANNEL="stable"
KCPU_MIN="i686-baseline"
KGPU_MIN="gpu-sw"

KUSE=(
  "-test"
  "-modemmanager"
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
    -DBUILD_TESTING=$(use_flag test ON OFF 2>/dev/null || echo OFF) \
    -DDISABLE_MODEMMANAGER_SUPPORT=$(use_flag modemmanager OFF ON 2>/dev/null || echo OFF)

  cmake --build build --parallel "$(nproc)"
}

# ── Package ───────────────────────────────────────────────────────────────────

package() {
  DESTDIR="$pkgdir" cmake --install build
}
