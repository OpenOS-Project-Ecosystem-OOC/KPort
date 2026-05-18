#!/usr/bin/env bash
# KPort pacscript — community-32bit-plasma5/plasma/plasma-desktop
#
# Desktop containment, task manager, system tray, KRunner, virtual desktops,
# and the Plasma desktop shell QML components. The "desktop" part of Plasma.

pkgname="plasma-desktop"
pkgver="5.27.12"
pkgdesc="KDE Plasma desktop shell and containment (Qt5/KF5, i686)"
url="https://kde.org/plasma-desktop/"
license=("GPL-2.0-or-later" "LGPL-2.1-or-later")

source=(
  "https://download.kde.org/stable/plasma/${pkgver}/plasma-desktop-${pkgver}.tar.xz"
)
sha256sums=(
  "SKIP"
)

depends=(
  "plasma-workspace"
  "libkf5activities5"
  "libkf5config5"
  "libkf5configwidgets5"
  "libkf5coreaddons5"
  "libkf5dbusaddons5"
  "libkf5declarative5"
  "libkf5globalaccel5"
  "libkf5i18n5"
  "libkf5iconthemes5"
  "libkf5kio5"
  "libkf5newstuff5"
  "libkf5notifications5"
  "libkf5plasma5"
  "libkf5runner5"
  "libkf5service5"
  "libkf5solid5"
  "libkf5windowsystem5"
  "libkf5xmlgui5"
  "libqt5core5a"
  "libqt5dbus5"
  "libqt5gui5"
  "libqt5quick5"
  "libqt5widgets5"
  "libqt5x11extras5"
  "libxcb1"
  "libxcb-keysyms1"
  "libxcb-util1"
  "libxkbcommon0"
  "libxkbcommon-x11-0"
  "libxtst6"
  "libxft2"
  "libaccounts-qt5-1"
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
  "libkf5configwidgets-dev"
  "libkf5coreaddons-dev"
  "libkf5dbusaddons-dev"
  "libkf5declarative-dev"
  "libkf5globalaccel-dev"
  "libkf5i18n-dev"
  "libkf5iconthemes-dev"
  "libkf5kio-dev"
  "libkf5newstuff-dev"
  "libkf5notifications-dev"
  "libkf5plasma-dev"
  "libkf5runner-dev"
  "libkf5service-dev"
  "libkf5solid-dev"
  "libkf5windowsystem-dev"
  "libkf5xmlgui-dev"
  "libxcb-keysyms1-dev"
  "libxcb-util-dev"
  "libxkbcommon-dev"
  "libxkbcommon-x11-dev"
  "libxtst-dev"
  "libxft-dev"
  "libaccounts-qt5-dev"
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
