#!/usr/bin/env bash
# KPort pacscript — community-32bit-plasma5/extras/drkonqi
#
# KDE crash handler. Intercepts application crashes, collects backtraces
# via GDB/LLDB, and offers to report them to bugs.kde.org.
# Particularly useful during early i686 testing to catch regressions.

pkgname="drkonqi"
pkgver="5.27.12"
pkgdesc="KDE crash handler (Qt5/KF5, i686)"
url="https://kde.org/plasma-desktop/"
license=("GPL-2.0-or-later" "LGPL-2.1-or-later")

source=(
  "https://download.kde.org/stable/plasma/${pkgver}/drkonqi-${pkgver}.tar.xz"
)
sha256sums=(
  "SKIP"
)

depends=(
  "libkf5config5"
  "libkf5configwidgets5"
  "libkf5coreaddons5"
  "libkf5crash5"
  "libkf5i18n5"
  "libkf5idletime5"
  "libkf5jobwidgets5"
  "libkf5kio5"
  "libkf5notifications5"
  "libkf5service5"
  "libkf5wallet5"
  "libkf5widgetsaddons5"
  "libkf5xmlgui5"
  "libqt5core5a"
  "libqt5dbus5"
  "libqt5gui5"
  "libqt5widgets5"
  "gdb"
)

makedepends=(
  "cmake"
  "ninja-build"
  "extra-cmake-modules"
  "qtbase5-dev"
  "libkf5config-dev"
  "libkf5configwidgets-dev"
  "libkf5coreaddons-dev"
  "libkf5crash-dev"
  "libkf5i18n-dev"
  "libkf5idletime-dev"
  "libkf5jobwidgets-dev"
  "libkf5kio-dev"
  "libkf5notifications-dev"
  "libkf5service-dev"
  "libkf5wallet-dev"
  "libkf5widgetsaddons-dev"
  "libkf5xmlgui-dev"
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
