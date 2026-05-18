#!/usr/bin/env bash
# KPort pacscript — community-32bit-plasma5/plasma/plasma-framework
#
# The Plasma QML/C++ framework (libplasma). Provides the containment model,
# applet API, theme engine, and QML components used by all Plasma widgets.
# Required by plasma-workspace, plasma-desktop, and most Plasma applets.

pkgname="plasma-framework"
pkgver="5.115.0"
pkgdesc="Plasma QML/C++ framework — libplasma (KF5, i686)"
url="https://invent.kde.org/frameworks/plasma-framework"
license=("LGPL-2.1-or-later")

# plasma-framework ships as part of KDE Frameworks 5, not the Plasma release.
# 5.115.0 is the KF5 LTS release aligned with Plasma 5.27.12.
source=(
  "https://download.kde.org/stable/frameworks/5.115/plasma-framework-${pkgver}.tar.xz"
)
sha256sums=(
  "SKIP"
)

depends=(
  "libkf5activities5"
  "libkf5config5"
  "libkf5configwidgets5"
  "libkf5coreaddons5"
  "libkf5declarative5"
  "libkf5globalaccel5"
  "libkf5i18n5"
  "libkf5iconthemes5"
  "libkf5kio5"
  "libkf5notifications5"
  "libkf5package5"
  "libkf5service5"
  "libkf5wayland5"
  "libkf5windowsystem5"
  "libkf5xmlgui5"
  "libqt5core5a"
  "libqt5dbus5"
  "libqt5gui5"
  "libqt5quick5"
  "libqt5svg5"
  "libqt5widgets5"
  "libqt5x11extras5"
  "libxcb1"
)

makedepends=(
  "cmake"
  "ninja-build"
  "extra-cmake-modules"
  "qtbase5-dev"
  "qtdeclarative5-dev"
  "libqt5svg5-dev"
  "libqt5x11extras5-dev"
  "libkf5activities-dev"
  "libkf5config-dev"
  "libkf5configwidgets-dev"
  "libkf5coreaddons-dev"
  "libkf5declarative-dev"
  "libkf5globalaccel-dev"
  "libkf5i18n-dev"
  "libkf5iconthemes-dev"
  "libkf5kio-dev"
  "libkf5notifications-dev"
  "libkf5package-dev"
  "libkf5service-dev"
  "libkf5wayland-dev"
  "libkf5windowsystem-dev"
  "libkf5xmlgui-dev"
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
