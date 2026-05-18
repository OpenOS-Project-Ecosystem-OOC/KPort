#!/usr/bin/env bash
# KPort pacscript — community-32bit-plasma5/extras/kdeplasma-addons
#
# Extra Plasma widgets and applets: calculator, comic strip, dictionary,
# fuzzy clock, notes, timer, weather, and more. All optional but commonly
# expected by users coming from a full Plasma installation.

pkgname="kdeplasma-addons"
pkgver="5.27.12"
pkgdesc="Extra KDE Plasma widgets and applets (Qt5/KF5, i686)"
url="https://kde.org/plasma-desktop/"
license=("GPL-2.0-or-later" "LGPL-2.1-or-later")

source=(
  "https://download.kde.org/stable/plasma/${pkgver}/kdeplasma-addons-${pkgver}.tar.xz"
)
sha256sums=(
  "SKIP"
)

depends=(
  "plasma-framework"
  "libkf5config5"
  "libkf5coreaddons5"
  "libkf5declarative5"
  "libkf5holidays5"
  "libkf5i18n5"
  "libkf5kio5"
  "libkf5notifications5"
  "libkf5plasma5"
  "libkf5runner5"
  "libkf5service5"
  "libkf5textwidgets5"
  "libkf5unitconversion5"
  "libkf5widgetsaddons5"
  "libqt5core5a"
  "libqt5dbus5"
  "libqt5gui5"
  "libqt5network5"
  "libqt5quick5"
  "libqt5widgets5"
)

makedepends=(
  "cmake"
  "ninja-build"
  "extra-cmake-modules"
  "qtbase5-dev"
  "qtdeclarative5-dev"
  "libkf5config-dev"
  "libkf5coreaddons-dev"
  "libkf5declarative-dev"
  "libkf5holidays-dev"
  "libkf5i18n-dev"
  "libkf5kio-dev"
  "libkf5notifications-dev"
  "libkf5plasma-dev"
  "libkf5runner-dev"
  "libkf5service-dev"
  "libkf5textwidgets-dev"
  "libkf5unitconversion-dev"
  "libkf5widgetsaddons-dev"
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
