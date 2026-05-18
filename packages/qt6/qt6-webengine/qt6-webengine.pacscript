#!/usr/bin/env bash
# KPort pacscript — qt6/qt6-webengine
# Promoted from generated/ — reviewed against KDE Neon Qt6 packaging.
#
# Qt 6 WebEngine Core library Qt is a cross-platform C++ application framework

# ── Standard Pacstall variables ───────────────────────────────────────────────

pkgname="qt6-webengine"
pkgver="6.10.2"
pkgdesc="Qt 6 WebEngine Core library"
# Fall back to invent.kde.org canonical URL when no homepage is set
url="https://www.qt.io/developers/"
license=("GPL-2.0-or-later")

source=(
  "https://download.qt.io/official_releases/qt/6.10/6.10.2/submodules/qtwebengine-everywhere-src-6.10.2.tar.xz"
)
sha256sums=(
  "856eddf292a69a88618567deea67711b4ec720e69bcb575ed7bb539c9023961e"
)

depends=(
  "qt6-declarative-dev"
  "qt6-svg"
  "sse3-support"
)

makedepends=(
  "binutils"
  "bison"
  "cmake"
  "flex"
  "gperf"
  "generate-ninja"
  "libasound2-dev"
  "libavcodec-dev"
  "libavformat-dev"
  "libavutil-dev"
  "libcups2-dev"
  "libdbus-1-dev"
  "libdrm-dev"
  "libegl1-mesa-dev"
  "libevent-dev"
  "libepoxy-dev"
  "libfontconfig-dev"
  "libfreetype-dev"
  "libgl-dev"
  "libgles-dev"
  "libglib2.0-dev"
  "libglu1-mesa-dev"
  "libgstreamer-plugins-base1.0-dev"
  "libgstreamer1.0-dev"
  "libharfbuzz-dev"
  "libicu-dev"
  "libjpeg-dev"
  "libjs-d3"
  "libjs-jquery"
  "libjs-jquery-tablesorter"
  "libjsoncpp-dev"
  "libkrb5-dev"
  "liblcms2-dev"
  "libminizip-dev"
  "libnss3-dev"
  "libopenjp2-7-dev"
  "libopus-dev"
  "libpci-dev"
  "libpipewire-0.3-dev"
  "libpng-dev"
  "libpoppler-cpp-dev"
  "libprotobuf-dev"
  "libpulse-dev"
  "libre2-dev"
  "libsnappy-dev"
  "libsqlite3-dev"
  "libssl-dev"
  "libtiff-dev"
  "libusb-1.0-0-dev"
  "libva-dev"
  "libvpx-dev"
  "libvulkan-dev"
  "libwayland-dev"
  "libwebp-dev"
  "libx11-dev"
  "libx11-xcb-dev"
  "libxcb-dri3-dev"
  "libxcomposite-dev"
  "libxcursor-dev"
  "libxdamage-dev"
  "libxi-dev"
  "libxkbcommon-dev"
  "libxkbfile-dev"
  "libxml2-dev"
  "libxnvctrl-dev"
  "libxrandr-dev"
  "libxrender-dev"
  "libxshmfence-dev"
  "libxslt1-dev"
  "libxss-dev"
  "libxtst-dev"
  "mesa-common-dev"
  "mold"
  "ninja-build"
  "node-pako"
  "node-rollup-plugin-terser"
  "node-yargs"
  "nodejs"
  "pkgconf"
  "pkg-kde-tools"
  "protobuf-compiler"
  "python3"
  "python3-html5lib"
  "qt6-base-dev"
  "qt6-declarative-dev"
  "qt6-documentation-tools"
  "qt6-httpserver-dev"
  "qt6-imageformats-dev"
  "qt6-positioning-dev"
  "qt6-svg-dev"
  "qt6-tools-dev"
  "qt6-webchannel-dev"
  "qt6-websockets-dev"
  "re2c"
  "rollup"
  "ruby"
  "xauth"
  "xvfb"
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
  "-pipewire"
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
