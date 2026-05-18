#!/usr/bin/env bash
# KPort pacscripts — community-32bit-plasma5/system/kde-cli-tools
#
# Collection of small CLI/GUI utilities: kdesu (privilege escalation dialog),
# kdialog (shell-scriptable dialogs), kstart (window rule launcher),
# kreadconfig5, kwriteconfig5, and kioclient5.

pkgname="kde-cli-tools"
pkgver="5.27.12"
pkgdesc="KDE CLI and GUI utility tools (Qt5/KF5, i686)"
url="https://kde.org/plasma-desktop/"
license=("GPL-2.0-or-later" "LGPL-2.1-or-later")

source=(
  "https://download.kde.org/stable/plasma/${pkgver}/kde-cli-tools-${pkgver}.tar.xz"
)
sha256sums=(
  "SKIP"
)

depends=(
  "libkf5config5"
  "libkf5configwidgets5"
  "libkf5coreaddons5"
  "libkf5dbusaddons5"
  "libkf5i18n5"
  "libkf5iconthemes5"
  "libkf5kio5"
  "libkf5service5"
  "libkf5su5"
  "libkf5windowsystem5"
  "libkf5xmlgui5"
  "libqt5core5a"
  "libqt5dbus5"
  "libqt5gui5"
  "libqt5widgets5"
  "libqt5x11extras5"
)

makedepends=(
  "cmake"
  "ninja-build"
  "extra-cmake-modules"
  "qtbase5-dev"
  "libqt5x11extras5-dev"
  "libkf5config-dev"
  "libkf5configwidgets-dev"
  "libkf5coreaddons-dev"
  "libkf5dbusaddons-dev"
  "libkf5i18n-dev"
  "libkf5iconthemes-dev"
  "libkf5kio-dev"
  "libkf5service-dev"
  "libkf5su-dev"
  "libkf5windowsystem-dev"
  "libkf5xmlgui-dev"
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
