#!/usr/bin/env bash
# KPort pacscript — qt6/qt6-base
# Promoted from generated/ — reviewed against KDE Neon Qt6 packaging.
#
# Qt 6 core module Qt is a cross-platform C++ application framework

# ── Standard Pacstall variables ───────────────────────────────────────────────

pkgname="qt6-base"
pkgver="6.10.2"
pkgdesc="Qt 6 core module"
# Fall back to invent.kde.org canonical URL when no homepage is set
url="https://www.qt.io/developers/"
license=("GPL-2.0-or-later")

source=(
  "https://download.qt.io/official_releases/qt/6.10/6.10.2/submodules/qtbase-everywhere-src-6.10.2.tar.xz"
)
sha256sums=(
  "aeb78d29291a2b5fd53cb55950f8f5065b4978c25fb1d77f627d695ab9adf21e"
)

depends=(
  "fontconfig"
  "gnome-themes-extra-data"
  "shared-mime-info"
)

makedepends=(
  "cmake"
  "default-libmysqlclient-dev"
  "firebird-dev"
  "freetds-dev"
  "glslang-tools"
  "glslc"
  "libatspi2.0-dev"
  "libb2-dev"
  "libbrotli-dev"
  "libcups2-dev"
  "libdbus-1-dev"
  "libdouble-conversion-dev"
  "libdrm-dev"
  "libegl-dev"
  "libfontconfig-dev"
  "libfreetype-dev"
  "libgbm-dev"
  "libgif-dev"
  "libgl-dev"
  "libgles-dev"
  "libglib2.0-dev"
  "libglu1-mesa-dev"
  "libglx-dev"
  "libgtk-3-dev"
  "libharfbuzz-dev"
  "libice-dev"
  "libicu-dev"
  "libinput-dev"
  "libjemalloc-dev"
  "libjpeg-dev"
  "libkrb5-dev"
  "liblttng-ust-dev"
  "libmd4c-dev"
  "libmd4c-html0-dev"
  "libmtdev-dev"
  "libopengl-dev"
  "libpcre2-dev"
  "libpng-dev"
  "libpq-dev"
  "libproxy-dev"
  "libsctp-dev"
  "libsqlite3-dev"
  "libssl-dev"
  "libsystemd-dev"
  "libts-dev"
  "libturbojpeg0-dev"
  "libudev-dev"
  "libvulkan-dev"
  "libwayland-dev"
  "libx11-dev"
  "libx11-xcb-dev"
  "libxcb1-dev"
  "libxcb-cursor-dev"
  "libxcb-composite0-dev"
  "libxcb-damage0-dev"
  "libxcb-dpms0-dev"
  "libxcb-dri2-0-dev"
  "libxcb-dri3-dev"
  "libxcb-ewmh-dev"
  "libxcb-glx0-dev"
  "libxcb-icccm4-dev"
  "libxcb-image0-dev"
  "libxcb-keysyms1-dev"
  "libxcb-present-dev"
  "libxcb-randr0-dev"
  "libxcb-record0-dev"
  "libxcb-render-util0-dev"
  "libxcb-render0-dev"
  "libxcb-res0-dev"
  "libxcb-screensaver0-dev"
  "libxcb-shape0-dev"
  "libxcb-shm0-dev"
  "libxcb-sync-dev"
  "libxcb-util-dev"
  "libxcb-xfixes0-dev"
  "libxcb-xf86dri0-dev"
  "libxcb-xinerama0-dev"
  "libxcb-xinput-dev"
  "libxcb-xkb-dev"
  "libxcb-xrm-dev"
  "libxcb-xv0-dev"
  "libxcb-xvmc0-dev"
  "libxcb-xtest0-dev"
  "libxext-dev"
  "libxfixes-dev"
  "libxi-dev"
  "libxkbcommon-dev"
  "libxkbcommon-x11-dev"
  "libxrender-dev"
  "libzstd-dev"
  "mold"
  "ninja-build"
  "pkgconf"
  "pkg-kde-tools"
  "python3"
  "shared-mime-info"
  "unixodbc-dev"
  "zlib1g-dev"
)

# ── KPort extensions ──────────────────────────────────────────────────────────

KSLOT="0"
KCATEGORY="qt6"
KNEON_CHANNEL="unstable"
KCPU_MIN="x86-64-v1"
KGPU_MIN="gpu-vk12"

KUSE=(
  "+wayland"
  "+x11"
  "-vulkan"
  "-test"
)

# ── Build ─────────────────────────────────────────────────────────────────────

build() {
  _kport_lib="${KPORT_LIB_DIR:-/usr/lib/kport}/use-helpers.sh"
  [[ -f "$_kport_lib" ]] && source "$_kport_lib"

  cmake -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DBUILD_TESTING=$(use_flag test ON OFF 2>/dev/null || echo OFF) \
    -DBUILD_QCH=$(use_flag docs ON OFF 2>/dev/null || echo OFF)

  cmake --build build --parallel "$(nproc)"
}

# ── Package ───────────────────────────────────────────────────────────────────

package() {
  DESTDIR="$pkgdir" cmake --install build
}
