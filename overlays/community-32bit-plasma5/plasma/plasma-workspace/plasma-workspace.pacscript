#!/usr/bin/env bash
# KPort pacscript — community-32bit-plasma5/plasma/plasma-workspace
#
# The Plasma shell: plasmashell process, notifications, logout/shutdown
# dialog, screen locker integration, and the Plasma QML runtime.
# This is the central component that ties the desktop together.

pkgname="plasma-workspace"
pkgver="5.27.12"
pkgdesc="KDE Plasma workspace shell (Qt5/KF5, i686)"
url="https://kde.org/plasma-desktop/"
license=("GPL-2.0-or-later" "LGPL-2.1-or-later")

source=(
  "https://download.kde.org/stable/plasma/${pkgver}/plasma-workspace-${pkgver}.tar.xz"
)
sha256sums=(
  "SKIP"
)

depends=(
  "kwin"
  "plasma-framework"
  "kactivitymanagerd"
  "libkf5activities5"
  "libkf5config5"
  "libkf5coreaddons5"
  "libkf5crash5"
  "libkf5dbusaddons5"
  "libkf5declarative5"
  "libkf5globalaccel5"
  "libkf5i18n5"
  "libkf5idletime5"
  "libkf5jobwidgets5"
  "libkf5kio5"
  "libkf5newstuff5"
  "libkf5notifications5"
  "libkf5notifyconfig5"
  "libkf5people5"
  "libkf5plasma5"
  "libkf5runner5"
  "libkf5service5"
  "libkf5textwidgets5"
  "libkf5wayland5"
  "libkf5windowsystem5"
  "libkf5xmlgui5"
  "libksysguard5"
  "libqt5core5a"
  "libqt5dbus5"
  "libqt5gui5"
  "libqt5quick5"
  "libqt5widgets5"
  "libqt5x11extras5"
  "libxcb1"
  "libxcb-util1"
  "libxft2"
  "libxtst6"
  "libpam0g"
  "libfontconfig1"
  "libfreetype6"
  "libxrender1"
  "libxrandr2"
  "xorg-xrdb"
  "xorg-xsetroot"
  "xorg-xmessage"
  "xorg-xprop"
  "xorg-xwininfo"
  "milou"
  "kscreen"
)

makedepends=(
  "cmake"
  "ninja-build"
  "extra-cmake-modules"
  "qtbase5-dev"
  "qtdeclarative5-dev"
  "libqt5x11extras5-dev"
  "libkf5activities-dev"
  "libkf5config-dev"
  "libkf5coreaddons-dev"
  "libkf5crash-dev"
  "libkf5dbusaddons-dev"
  "libkf5declarative-dev"
  "libkf5globalaccel-dev"
  "libkf5i18n-dev"
  "libkf5idletime-dev"
  "libkf5jobwidgets-dev"
  "libkf5kio-dev"
  "libkf5newstuff-dev"
  "libkf5notifications-dev"
  "libkf5notifyconfig-dev"
  "libkf5people-dev"
  "libkf5plasma-dev"
  "libkf5runner-dev"
  "libkf5service-dev"
  "libkf5textwidgets-dev"
  "libkf5wayland-dev"
  "libkf5windowsystem-dev"
  "libkf5xmlgui-dev"
  "libksysguard-dev"
  "libxcb-util-dev"
  "libxft-dev"
  "libxtst-dev"
  "libpam0g-dev"
  "libfontconfig1-dev"
  "libfreetype-dev"
  "libxrender-dev"
  "libxrandr-dev"
  "pkg-config"
)

# ── KPort extensions ──────────────────────────────────────────────────────────

KSLOT="5"
KCATEGORY="plasma"
KNEON_CHANNEL="stable"
KCPU_MIN="i686-baseline"
KGPU_MIN="gpu-gl2"

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
