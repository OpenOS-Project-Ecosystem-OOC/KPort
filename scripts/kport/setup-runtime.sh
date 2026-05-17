#!/usr/bin/env bash
#
# setup-runtime.sh
#
# Installs KPort runtime files to the system so pacscripts can find them.
# Must be run once after cloning KPort, and re-run after pulling updates.
#
# Usage:
#   sudo scripts/kport/setup-runtime.sh          # install to /usr/lib/kport/
#   scripts/kport/setup-runtime.sh --user        # install to ~/.local/lib/kport/
#   scripts/kport/setup-runtime.sh --prefix /opt # install to /opt/lib/kport/
#   scripts/kport/setup-runtime.sh --dry-run     # show what would be installed
#
# After --user install, pacscripts won't find the helpers at the default path
# (/usr/lib/kport/use-helpers.sh). Set KPORT_LIB_DIR in your environment and
# the pacscript guard handles it:
#
#   export KPORT_LIB_DIR=~/.local/lib/kport
#
# Runtime files installed:
#   lib/kport/use-helpers.sh        →  <prefix>/lib/kport/use-helpers.sh
#   lib/kport/common.sh             →  <prefix>/lib/kport/common.sh
#   lib/kport/resolve.sh            →  <prefix>/lib/kport/resolve.sh
#   lib/kport/cmd/*.sh              →  <prefix>/lib/kport/cmd/*.sh
#   bin/kport                       →  <prefix>/bin/kport

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KPORT_ROOT="${KPORT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

# ── Defaults ──────────────────────────────────────────────────────────────────

PREFIX="/usr"
DRY_RUN=false
USER_INSTALL=false

# ── Argument parsing ──────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user)        USER_INSTALL=true; shift ;;
    --prefix)      PREFIX="$2"; shift 2 ;;
    --dry-run)     DRY_RUN=true; shift ;;
    --help)
      sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | grep '^#' | sed 's/^# \?//'
      exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ "$USER_INSTALL" == "true" ]]; then
  PREFIX="${HOME}/.local"
fi

LIB_DEST="${PREFIX}/lib/kport"

# ── Helpers ───────────────────────────────────────────────────────────────────

info()  { echo "[setup-runtime] $*"; }
dry()   { echo "[dry-run]       $*"; }
error() { echo "[error]         $*" >&2; exit 1; }

install_file() {
  local src="$1" dest_dir="$2" dest_file="$3"
  local dest="${dest_dir}/${dest_file}"

  if [[ "$DRY_RUN" == "true" ]]; then
    dry "install ${src} → ${dest}"
    return 0
  fi

  mkdir -p "$dest_dir" || error "Cannot create ${dest_dir} (try sudo or --user)"
  install -m 644 "$src" "$dest" || error "Failed to install ${src} → ${dest}"
  info "  installed ${dest}"
}

# ── Main ──────────────────────────────────────────────────────────────────────

info "KPort runtime setup"
info "  Source : ${KPORT_ROOT}/lib/kport/"
info "  Dest   : ${LIB_DEST}/"
[[ "$DRY_RUN" == "true" ]] && info "  Mode   : dry run"
echo ""

# ── Verify source tree ────────────────────────────────────────────────────────

for required in lib/kport/use-helpers.sh lib/kport/common.sh lib/kport/resolve.sh bin/kport; do
  [[ -f "${KPORT_ROOT}/${required}" ]] \
    || error "Source file not found: ${KPORT_ROOT}/${required}"
done

# ── Install library files ─────────────────────────────────────────────────────

install_file "${KPORT_ROOT}/lib/kport/use-helpers.sh" "${LIB_DEST}" "use-helpers.sh"
install_file "${KPORT_ROOT}/lib/kport/common.sh"      "${LIB_DEST}" "common.sh"
install_file "${KPORT_ROOT}/lib/kport/resolve.sh"     "${LIB_DEST}" "resolve.sh"

# Install command scripts
CMD_DEST="${LIB_DEST}/cmd"
for cmd_script in "${KPORT_ROOT}/lib/kport/cmd/"*.sh; do
  [[ -f "$cmd_script" ]] || continue
  install_file "$cmd_script" "${CMD_DEST}" "$(basename "$cmd_script")"
done

# ── Install kport binary ──────────────────────────────────────────────────────

BIN_DEST="${PREFIX}/bin"

if [[ "$DRY_RUN" == "true" ]]; then
  dry "install ${KPORT_ROOT}/bin/kport → ${BIN_DEST}/kport  (mode 755)"
else
  mkdir -p "$BIN_DEST" || error "Cannot create ${BIN_DEST}"
  install -m 755 "${KPORT_ROOT}/bin/kport" "${BIN_DEST}/kport" \
    || error "Failed to install kport binary"
  info "  installed ${BIN_DEST}/kport"
fi

echo ""
info "Done."

if [[ "$USER_INSTALL" == "true" && "$DRY_RUN" != "true" ]]; then
  echo ""
  info "User install complete. Add to your shell profile:"
  info "  export PATH=\"${BIN_DEST}:\$PATH\""
  info "  export KPORT_ROOT=\"${KPORT_ROOT}\""
  info "  export KPORT_LIB_DIR=\"${LIB_DEST}\""
fi
