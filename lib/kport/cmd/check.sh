#!/usr/bin/env bash
# kport check
#
# Verifies installed file manifests against the filesystem.
# For each installed package, reads the files manifest recorded at install
# time and checks that every path still exists on disk.
#
# Usage: kport check [options] [pkg...]
#
# Arguments:
#   pkg...         Check only the named package(s). Defaults to all installed.
#
# Options:
#   --quiet        Only print packages with missing files (no OK lines)
#   --strict       Exit 1 if any package has missing files (default: exit 0)
#   --no-manifest  Warn (don't fail) when a package has no files manifest
#   --help

set -uo pipefail

# ── Parse args ────────────────────────────────────────────────────────────────

QUIET=false
STRICT=false
NO_MANIFEST_WARN=false
FILTER_PKGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --quiet)        QUIET=true;            shift ;;
    --strict)       STRICT=true;           shift ;;
    --no-manifest)  NO_MANIFEST_WARN=true; shift ;;
    --help|-h)
      sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | grep '^#' | sed 's/^# \?//'
      exit 0 ;;
    -*) kport_die "Unknown option: $1" ;;
    *)  FILTER_PKGS+=("$1"); shift ;;
  esac
done

# ── Collect packages to check ─────────────────────────────────────────────────

if [[ ! -d "$KPORT_DB_INSTALLED" ]]; then
  kport_info "No packages installed (${KPORT_DB_INSTALLED} not found)"
  exit 0
fi

declare -a CHECK_PKGS

if [[ ${#FILTER_PKGS[@]} -gt 0 ]]; then
  for pkg in "${FILTER_PKGS[@]}"; do
    if [[ ! -d "${KPORT_DB_INSTALLED}/${pkg}" ]]; then
      kport_error "${pkg}: not installed"
      exit 1
    fi
    CHECK_PKGS+=("$pkg")
  done
else
  mapfile -t CHECK_PKGS < <(
    find "$KPORT_DB_INSTALLED" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort
  )
fi

if [[ ${#CHECK_PKGS[@]} -eq 0 ]]; then
  kport_info "No packages installed"
  exit 0
fi

# ── Check each package ────────────────────────────────────────────────────────

ok=0; broken=0; no_manifest=0

for pkg in "${CHECK_PKGS[@]}"; do
  manifest="${KPORT_DB_INSTALLED}/${pkg}/files"
  version=$(kport_db_read "$pkg" version 2>/dev/null || echo "?")

  if [[ ! -f "$manifest" ]]; then
    if [[ "$NO_MANIFEST_WARN" == "true" || "$QUIET" == "true" ]]; then
      kport_warn "${pkg}: no files manifest (installed before manifest tracking?)"
    else
      kport_warn "${pkg}-${version}: no files manifest"
    fi
    (( no_manifest++ )) || true
    continue
  fi

  # Read manifest and check each path
  missing=()
  while IFS= read -r fpath; do
    [[ -z "$fpath" ]] && continue
    [[ -e "$fpath" || -L "$fpath" ]] || missing+=("$fpath")
  done < "$manifest"

  total=$(grep -c . "$manifest" 2>/dev/null || echo 0)

  if [[ ${#missing[@]} -eq 0 ]]; then
    [[ "$QUIET" == "false" ]] && \
      kport_info "${C_GREEN}✔${C_RESET} ${pkg}-${version} (${total} files)"
    (( ok++ )) || true
  else
    kport_warn "${pkg}-${version}: ${#missing[@]}/${total} files missing"
    for f in "${missing[@]}"; do
      echo "    ${C_RED}✗${C_RESET} ${f}"
    done
    (( broken++ )) || true
  fi
done

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
kport_info "Check complete — ok: ${ok}  broken: ${broken}  no-manifest: ${no_manifest}"

if [[ "$STRICT" == "true" && "$broken" -gt 0 ]]; then
  exit 1
fi
exit 0
