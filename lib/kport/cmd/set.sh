#!/usr/bin/env bash
# kport set
#
# Toggle USE flags for a package or globally, and optionally trigger a rebuild.
#
# Per-package flags are written to ~/.config/kport/package.use.
# Global flags are written to ~/.config/kport/use.conf.
#
# Usage: kport set [options] <pkg> [+flag|-flag ...]
#        kport set --global [+flag|-flag ...]
#        kport set <pkg>          (no flags — show current resolved USE flags)
#
# Options:
#   --global       Write flags to use.conf instead of package.use
#   --rebuild      Run 'kport upgrade --use-changed' after writing flags
#   --show         Show resolved USE flags for <pkg> (default when no flags given)
#   --help

set -uo pipefail

# ── Parse args ────────────────────────────────────────────────────────────────

GLOBAL=false
REBUILD=false
SHOW_ONLY=false
PKG=""
declare -a FLAGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --global)   GLOBAL=true;   shift ;;
    --rebuild)  REBUILD=true;  shift ;;
    --show)     SHOW_ONLY=true; shift ;;
    --help|-h)
      sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | grep '^#' | sed 's/^# \?//'
      exit 0 ;;
    --)
      shift
      # Everything after -- is a flag spec
      FLAGS+=("$@"); break ;;
    --*)
      kport_die "Unknown option: $1" ;;
    +*)
      # +flag spec
      FLAGS+=("$1"); shift ;;
    -*)
      # Could be -flag spec or unknown option.
      # Treat as a flag spec if it looks like -word (no double-dash, no =).
      if [[ "$1" =~ ^-[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
        FLAGS+=("$1"); shift
      else
        kport_die "Unknown option: $1"
      fi ;;
    *)
      if [[ -z "$PKG" ]]; then
        PKG="$1"; shift
      else
        kport_die "Unexpected argument: $1"
      fi ;;
  esac
done

# ── Validate ──────────────────────────────────────────────────────────────────

if [[ "$GLOBAL" == "true" && -n "$PKG" ]]; then
  kport_die "--global and a package name are mutually exclusive"
fi

if [[ "$GLOBAL" == "false" && -z "$PKG" ]]; then
  kport_die "Package name required (or use --global for global flags)"
fi

# No flags given → show mode
if [[ ${#FLAGS[@]} -eq 0 ]]; then
  SHOW_ONLY=true
fi

# ── Show resolved USE flags ───────────────────────────────────────────────────

_show_use_flags() {
  local pkg="$1"

  if ! kport_is_installed "$pkg"; then
    kport_warn "${pkg}: not installed — showing pacscript defaults only"
  fi

  local pacscript
  pacscript=$(kport_find_pacscript "$pkg") \
    || kport_die "${pkg}: pacscript not found"

  kport_header "USE flags for ${pkg}"

  # Resolve via use-helpers.sh in a subshell
  mapfile -t kuse_arr < <(kport_pacscript_array "$pacscript" KUSE)
  if [[ ${#kuse_arr[@]} -eq 0 ]]; then
    kport_info "  (no USE flags defined for this package)"
    return 0
  fi

  printf -v kuse_decl 'KUSE=(%s)' "$(printf '"%s" ' "${kuse_arr[@]}")"

  # use_dump prints a table: FLAG  STATE  SOURCE (space-aligned, with header lines)
  # Skip header lines (those not matching a flag data row) and parse the rest.
  pkgname="$pkg" KPORT_CONF_DIR="$KPORT_CONF" \
    bash -c "${kuse_decl}
      source \"\${KPORT_LIB}/use-helpers.sh\"
      use_dump" 2>/dev/null \
    | awk '$2=="on" || $2=="off" {
        flag=$1
        val=$2
        src=""
        for(i=3;i<=NF;i++) src=src (i==3?"":OFS) $i
        print flag "\t" val "\t" src
      }' \
    | while IFS=$'\t' read -r flag val src; do
        if [[ "$val" == "on" ]]; then
          printf "  ${C_GREEN}+%-20s${C_RESET} ${C_DIM}%s${C_RESET}\n" "$flag" "$src"
        else
          printf "  ${C_RED}-%-20s${C_RESET} ${C_DIM}%s${C_RESET}\n" "$flag" "$src"
        fi
      done

  echo ""
  kport_info "Edit: ${KPORT_CONF}/package.use"
  kport_info "  Format: ${pkg}: +flag -flag ..."
}

if [[ "$SHOW_ONLY" == "true" ]]; then
  _show_use_flags "$PKG"
  exit 0
fi

# ── Write USE flags ───────────────────────────────────────────────────────────

# Validate flag specs
for f in "${FLAGS[@]}"; do
  if [[ ! "$f" =~ ^[+-][a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
    kport_die "Invalid flag spec '${f}' — must be +flagname or -flagname"
  fi
done

mkdir -p "$KPORT_CONF"

if [[ "$GLOBAL" == "true" ]]; then
  # ── Global use.conf ───────────────────────────────────────────────────────
  conf_file="${KPORT_CONF}/use.conf"
  touch "$conf_file"

  for spec in "${FLAGS[@]}"; do
    flag="${spec#[+-]}"
    flag="${flag,,}"

    # Remove any existing line for this flag (+ or -)
    tmp=$(mktemp)
    grep -vE "^[+-]?${flag}$" "$conf_file" > "$tmp" || true
    mv "$tmp" "$conf_file"

    # Append the new spec
    echo "$spec" >> "$conf_file"
    kport_info "Global: ${spec} written to use.conf"
  done

else
  # ── Per-package package.use ───────────────────────────────────────────────
  conf_file="${KPORT_CONF}/package.use"
  touch "$conf_file"

  # Read existing line for this package (if any)
  existing_line=""
  if grep -qE "^${PKG}:" "$conf_file" 2>/dev/null; then
    existing_line=$(grep -E "^${PKG}:" "$conf_file" | head -1)
  fi

  # Parse existing flags into an associative array: flag → spec (+/-)
  declare -A current_flags=()
  if [[ -n "$existing_line" ]]; then
    specs_part="${existing_line#*:}"
    for spec in $specs_part; do
      flag="${spec#[+-]}"
      flag="${flag,,}"
      current_flags["$flag"]="$spec"
    done
  fi

  # Apply new flag specs (overwrite existing entries for the same flag)
  for spec in "${FLAGS[@]}"; do
    flag="${spec#[+-]}"
    flag="${flag,,}"
    current_flags["$flag"]="$spec"
    kport_info "${PKG}: ${spec}"
  done

  # Rebuild the line
  new_specs=""
  for flag in $(echo "${!current_flags[@]}" | tr ' ' '\n' | sort); do
    new_specs+=" ${current_flags[$flag]}"
  done
  new_line="${PKG}:${new_specs}"

  # Replace or append in the file
  tmp=$(mktemp)
  if grep -qE "^${PKG}:" "$conf_file" 2>/dev/null; then
    # Replace existing line
    sed "s|^${PKG}:.*|${new_line}|" "$conf_file" > "$tmp"
  else
    # Append new line
    cat "$conf_file" > "$tmp"
    echo "$new_line" >> "$tmp"
  fi
  mv "$tmp" "$conf_file"

  kport_info "Written to ${conf_file}"
fi

# ── Optionally rebuild ────────────────────────────────────────────────────────

if [[ "$REBUILD" == "true" ]]; then
  echo ""
  kport_header "Rebuilding affected packages"
  if [[ "$GLOBAL" == "true" ]]; then
    exec bash "${KPORT_LIB}/cmd/upgrade.sh" --use-changed
  else
    # Only rebuild the specific package if it's installed
    if kport_is_installed "$PKG"; then
      exec bash "${KPORT_LIB}/cmd/install.sh" "$PKG"
    else
      kport_info "${PKG} is not installed — nothing to rebuild"
    fi
  fi
fi

exit 0
