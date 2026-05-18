#!/usr/bin/env bash
#
# lint-pacscripts.sh
#
# Validates all pacscripts under packages/ for:
#   - Required fields present and non-empty (pkgname, pkgver, sha256sums, KSLOT, KCATEGORY)
#   - sha256sums entries are 64-char hex (no placeholder zeros or empty strings)
#   - No duplicate entries in depends=() or makedepends=()
#   - pkgname matches the directory name
#
# Usage:
#   lint-pacscripts.sh [--packages-dir <dir>] [--quiet]
#
# Exit codes:
#   0  all checks passed
#   1  one or more violations found

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KPORT_ROOT="${KPORT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
PACKAGES_DIR="${KPORT_ROOT}/packages"
QUIET=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --packages-dir) PACKAGES_DIR="$2"; shift 2 ;;
    --quiet)        QUIET=true;        shift ;;
    --help)
      sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | grep '^#' | sed 's/^# \?//'
      exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

errors=0
warnings=0
checked=0

err()  { echo "  ERROR: $*" >&2; (( errors++ )) || true; }
warn() { echo "  WARN:  $*" >&2; (( warnings++ )) || true; }
info() { [[ "$QUIET" == "true" ]] || echo "$*"; }

# ── Extract a scalar variable value from a pacscript ─────────────────────────

_get_var() {
  local file="$1" var="$2"
  grep -m1 "^${var}=" "$file" | sed 's/^[^=]*=//; s/^"//; s/"$//'
}

# ── Extract array entries from a pacscript ────────────────────────────────────

_get_array() {
  local file="$1" var="$2"
  sed -n "/^${var}=(/,/^)/p" "$file" | grep '"' | sed 's/.*"\(.*\)".*/\1/'
}

# ── Check a single pacscript ──────────────────────────────────────────────────

check_pacscript() {
  local file="$1"
  local dir_name pkg_dir
  pkg_dir="$(dirname "$file")"
  dir_name="$(basename "$pkg_dir")"

  local file_errors=0
  _err()  { err "$file: $*"; (( file_errors++ )) || true; }

  # Required scalar fields
  for field in pkgname pkgver KSLOT KCATEGORY; do
    val=$(_get_var "$file" "$field")
    if [[ -z "$val" ]]; then
      _err "missing or empty field: ${field}"
    fi
  done

  # pkgname must match directory name
  pkgname=$(_get_var "$file" "pkgname")
  if [[ -n "$pkgname" && "$pkgname" != "$dir_name" ]]; then
    _err "pkgname '${pkgname}' does not match directory '${dir_name}'"
  fi

  # sha256sums — must have at least one entry, all must be 64-char hex
  mapfile -t shasums < <(_get_array "$file" "sha256sums")
  if [[ ${#shasums[@]} -eq 0 ]]; then
    _err "sha256sums array is empty"
  else
    for sha in "${shasums[@]}"; do
      if [[ -z "$sha" ]]; then
        _err "sha256sums contains empty entry"
      elif [[ ! "$sha" =~ ^[0-9a-f]{64}$ ]]; then
        _err "sha256sums entry is not valid sha256: '${sha}'"
      fi
    done
  fi

  # Duplicate dep check
  for arr in depends makedepends; do
    mapfile -t entries < <(_get_array "$file" "$arr")
    if [[ ${#entries[@]} -gt 0 ]]; then
      dupes=$(printf '%s\n' "${entries[@]}" | sort | uniq -d)
      if [[ -n "$dupes" ]]; then
        while IFS= read -r d; do
          _err "duplicate entry in ${arr}: '${d}'"
        done <<< "$dupes"
      fi
    fi
  done

  (( checked++ )) || true
  return $(( file_errors > 0 ? 1 : 0 ))
}

# ── Main ──────────────────────────────────────────────────────────────────────

info "Linting pacscripts in ${PACKAGES_DIR}"
info ""

while IFS= read -r -d '' pacscript; do
  rel="${pacscript#${KPORT_ROOT}/}"
  info "  checking ${rel}"
  check_pacscript "$pacscript" || true
done < <(find "$PACKAGES_DIR" -name "*.pacscript" -print0 | sort -z)

echo ""
echo "Checked ${checked} pacscript(s) — ${errors} error(s), ${warnings} warning(s)"

if (( errors > 0 )); then
  echo "FAIL" >&2
  exit 1
fi

echo "OK"
exit 0
