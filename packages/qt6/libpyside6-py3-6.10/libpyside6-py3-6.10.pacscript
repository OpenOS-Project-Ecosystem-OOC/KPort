#!/usr/bin/env bash
# KPort pacscript — qt6/libpyside6-py3-6.10
# Promoted from generated/ — reviewed against KDE Neon Qt6 packaging.
#
# Python 3 bindings for Qt 6 (base files) pyside6 provides Python bindings for Qt

# ── Standard Pacstall variables ───────────────────────────────────────────────

pkgname="libpyside6-py3-6.10"
pkgver="6.10.2"
pkgdesc="Python 3 bindings for Qt 6 (base files) pyside6 provides Python bindings for Qt"
# Fall back to invent.kde.org canonical URL when no homepage is set
url="https://wiki.qt.io/Qt_for_Python"
license=("GPL-2.0-or-later")

source=(
  "https://download.qt.io/official_releases/QtForPython/pyside6/PySide6-6.10.2-src/pyside-setup-everywhere-src-6.10.2.tar.xz"
)
sha256sums=(
  "05eec38bb71bffff8860786e3c0766cc4b86affc72439bd246c54889bdcb7400"
)

depends=(
  # No named runtime deps found in debian/control (only ${shlibs:Depends}).
  # Populate after a test build by inspecting ldd output or dpkg -I.
)

makedepends=(
  "chrpath"
  "clang"
  "cmake"
  "dh-sequence-sphinxdoc"
  "furo"
  "libclang-dev"
  "libxml2-dev"
  "libxslt1-dev"
  "llvm-dev"
  "ninja-build"
  "patchelf"
  "pkg-kde-tools"
  "python3-dev"
  "python3-distro"
  "python3-numpy"
  "python3-opengl"
  "python3-packaging"
  "python3-pip"
  "python3-pkginfo"
  "python3-myst-parser"
  "python3-setuptools"
  "python3-sphinx"
  "python3-sphinx-copybutton"
  "python3-sphinx-design"
  "python3-sphinxcontrib.qthelp"
  "python3-wheel"
  "qml6-module-qtqml-workerscript"
  "qml6-module-qtquick"
  "qml6-module-qtquick-controls"
  "qml6-module-qtquick-layouts"
  "qml6-module-qtquick-templates"
  "qml6-module-qtquick-window"
  "qt6-3d-dev"
  "qt6-base-dev"
  "qt6-base-private-dev"
  "qt6-charts-dev"
  "qt6-connectivity-dev"
  "qt6-datavis3d-dev"
  "qt6-declarative-dev"
  "qt6-declarative-private-dev"
  "qt6-graphs-dev"
  "qt6-httpserver-dev"
  "qt6-location-dev"
  "qt6-multimedia-dev"
  "qt6-networkauth-dev"
  "qt6-pdf-dev"
  "qt6-positioning-dev"
  "qt6-qmllint-plugins"
  "qt6-qmltooling-plugins"
  "qt6-quick3d-dev"
  "qt6-remoteobjects-dev"
  "qt6-scxml-dev"
  "qt6-sensors-dev"
  "qt6-serialbus-dev"
  "qt6-serialport-dev"
  "qt6-shadertools-dev"
  "qt6-speech-dev"
  "qt6-svg-dev"
  "qt6-tools-dev"
  "qt6-virtualkeyboard-dev"
  "qt6-wayland-dev"
  "qt6-webchannel-dev"
  "qt6-webengine-dev"
  "qt6-websockets-dev"
  "qt6-webview-dev"
  "qtchooser"
  "sip-tools"
  "xauth"
  "xvfb"
)

# ── KPort extensions ──────────────────────────────────────────────────────────

KSLOT="0"
KCATEGORY="qt6"
KNEON_CHANNEL="unstable"
KCPU_MIN="x86-64-v1"
KGPU_MIN="gpu-sw"

KUSE=(
  "+wayland"
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
