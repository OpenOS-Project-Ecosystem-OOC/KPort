#!/usr/bin/env bash
# KPort pacscript — community-32bit-plasma5/plasma/kwin
#
# KDE window manager and compositor. Supports X11 (stable) and Wayland
# (functional but secondary on i686). Uses KF5/Qt5 — builds on i686.
# Validated: Arch Linux 32 ships kwin 5.27.7 in extra/i686.

pkgname="kwin"
pkgver="5.27.12"
pkgdesc="KDE window manager and compositor (Qt5/KF5, i686)"
url="https://kde.org/plasma-desktop/"
license=("GPL-2.0-or-later" "LGPL-2.1-or-later")

source=(
  "https://download.kde.org/stable/plasma/${pkgver}/kwin-${pkgver}.tar.xz"
)
sha256sums=(
  "SKIP"
)

depends=(
  "libkf5config5"
  "libkf5configwidgets5"
  "libkf5coreaddons5"
  "libkf5crash5"
  "libkf5globalaccel5"
  "libkf5i18n5"
  "libkf5notifications5"
  "libkf5service5"
  "libkf5windowsystem5"
  "libkf5xmlgui5"
  "libqt5core5a"
  "libqt5dbus5"
  "libqt5gui5"
  "libqt5widgets5"
  "libqt5x11extras5"
  "libqt5multimedia5"
  "libepoxy0"
  "libgl1"
  "libgles2"
  "libinput10"
  "libxcb1"
  "libxcb-composite0"
  "libxcb-cursor0"
  "libxcb-damage0"
  "libxcb-glx0"
  "libxcb-icccm4"
  "libxcb-image0"
  "libxcb-keysyms1"
  "libxcb-randr0"
  "libxcb-render0"
  "libxcb-shape0"
  "libxcb-sync1"
  "libxcb-xfixes0"
  "libxcb-xinerama0"
  "libxcb-xkb1"
  "libxkbcommon0"
  "libxkbcommon-x11-0"
  "libwayland-client0"
  "libwayland-server0"
  "libdrm2"
  "libgbm1"
  "libudev1"
)

makedepends=(
  "cmake"
  "ninja-build"
  "extra-cmake-modules"
  "qtbase5-dev"
  "qtmultimedia5-dev"
  "libqt5x11extras5-dev"
  "libkf5config-dev"
  "libkf5configwidgets-dev"
  "libkf5coreaddons-dev"
  "libkf5crash-dev"
  "libkf5globalaccel-dev"
  "libkf5i18n-dev"
  "libkf5notifications-dev"
  "libkf5service-dev"
  "libkf5windowsystem-dev"
  "libkf5xmlgui-dev"
  "libepoxy-dev"
  "libinput-dev"
  "libxcb-composite0-dev"
  "libxcb-cursor-dev"
  "libxcb-damage0-dev"
  "libxcb-glx0-dev"
  "libxcb-icccm4-dev"
  "libxcb-image0-dev"
  "libxcb-keysyms1-dev"
  "libxcb-randr0-dev"
  "libxcb-render0-dev"
  "libxcb-shape0-dev"
  "libxcb-sync-dev"
  "libxcb-xfixes0-dev"
  "libxcb-xinerama0-dev"
  "libxcb-xkb-dev"
  "libxkbcommon-dev"
  "libxkbcommon-x11-dev"
  "libwayland-dev"
  "libdrm-dev"
  "libgbm-dev"
  "libudev-dev"
  "pkg-config"
)

# ── KPort extensions ──────────────────────────────────────────────────────────

KSLOT="5"
KCATEGORY="plasma"
KNEON_CHANNEL="stable"
KCPU_MIN="i686-baseline"
KGPU_MIN="gpu-gl2"   # KWin X11 requires at minimum OpenGL 2.x

KUSE=(
  "+x11"
  "-wayland"   # Wayland on i686 is functional but not the primary target
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
    -DBUILD_TESTING=$(use_flag test ON OFF 2>/dev/null || echo OFF) \
    -DKWIN_BUILD_WAYLAND_BACKEND=$(use_flag wayland ON OFF 2>/dev/null || echo OFF)

  cmake --build build --parallel "$(nproc)"
}

# ── Package ───────────────────────────────────────────────────────────────────

package() {
  DESTDIR="$pkgdir" cmake --install build
}
