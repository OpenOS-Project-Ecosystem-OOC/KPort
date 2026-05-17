#!/usr/bin/env bash
# kport info
#
# Show package metadata, USE flags, dependencies, and install status.
#
# Usage: kport info [options] <pkgname>
#
# Options:
#   --use-flags    Show resolved USE flag state for this package
#   --files        Show installed file list (installed packages only)
#   --help

set -uo pipefail

# ── Parse args ────────────────────────────────────────────────────────────────

SHOW_USE_FLAGS=false
SHOW_FILES=false
PKGNAME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --use-flags) SHOW_USE_FLAGS=true; shift ;;
    --files)     SHOW_FILES=true;     shift ;;
    --help|-h)
      sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | grep '^#' | sed 's/^# \?//'
      exit 0 ;;
    -*) kport_die "Unknown option: $1" ;;
    *)  PKGNAME="$1"; shift ;;
  esac
done

[[ -z "$PKGNAME" ]] && kport_die "Usage: kport info <pkgname>"

# ── Find pacscript ────────────────────────────────────────────────────────────

pacscript=$(kport_find_pacscript "$PKGNAME") \
  || kport_die "Package not found: ${PKGNAME}"

# ── Extract metadata ──────────────────────────────────────────────────────────

pkgname=$(kport_pacscript_var  "$pacscript" pkgname)
pkgver=$(kport_pacscript_var   "$pacscript" pkgver)
pkgdesc=$(kport_pacscript_var  "$pacscript" pkgdesc)
url=$(kport_pacscript_var      "$pacscript" url)
category=$(kport_pacscript_var "$pacscript" KCATEGORY)
slot=$(kport_pacscript_var     "$pacscript" KSLOT)
cpu_min=$(kport_pacscript_var  "$pacscript" KCPU_MIN)
gpu_min=$(kport_pacscript_var  "$pacscript" KGPU_MIN)
npu_min=$(kport_pacscript_var  "$pacscript" KNPU_MIN)
channel=$(kport_pacscript_var  "$pacscript" KNEON_CHANNEL)

mapfile -t licenses   < <(kport_pacscript_array "$pacscript" license)
mapfile -t depends    < <(kport_pacscript_array "$pacscript" depends)
mapfile -t makedepends< <(kport_pacscript_array "$pacscript" makedepends)
mapfile -t kuse       < <(kport_pacscript_array "$pacscript" KUSE)

# ── Install status ────────────────────────────────────────────────────────────

installed=false
installed_ver=""
installed_use=""
kport_is_installed "$pkgname" && {
  installed=true
  installed_ver=$(kport_db_read "$pkgname" version)
  installed_use=$(kport_db_read "$pkgname" use_flags)
}

# ── Display ───────────────────────────────────────────────────────────────────

kport_header "${pkgname}"

kport_kv "Description"  "$pkgdesc"
kport_kv "Version"      "$pkgver"
kport_kv "Category"     "$category"
kport_kv "Slot"         "${slot:-0}"
kport_kv "Channel"      "${channel:-stable}"
kport_kv "License"      "${licenses[*]:-unknown}"
kport_kv "Homepage"     "$url"
kport_kv "Pacscript"    "$pacscript"

echo ""
kport_kv "CPU min"  "${cpu_min:-x86-64-v1}"
kport_kv "GPU min"  "${gpu_min:-gpu-sw}"
[[ -n "$npu_min" ]] && kport_kv "NPU min" "$npu_min"

# Hardware compatibility check
if [[ -f "$KPORT_HW_CONF" ]]; then
  hw_cpu=$(kport_hw_read CPU_TIER)
  hw_gpu=$(kport_hw_read GPU_TIER)
  kport_kv "Your CPU"  "${hw_cpu:-(not detected)}"
  kport_kv "Your GPU"  "${hw_gpu:-(not detected)}"
fi

# Install status
echo ""
if [[ "$installed" == "true" ]]; then
  echo -e "  ${C_GREEN}● Installed${C_RESET}  version ${installed_ver}"
  [[ -n "$installed_use" ]] && echo -e "  ${C_DIM}USE flags at build time: ${installed_use}${C_RESET}"
else
  echo -e "  ${C_DIM}○ Not installed${C_RESET}"
fi

# Dependencies
if [[ ${#depends[@]} -gt 0 ]]; then
  echo ""
  kport_header "Runtime dependencies (${#depends[@]})"
  for dep in "${depends[@]}"; do
    local marker="  "
    kport_is_installed "$dep" \
      && marker="${C_GREEN}  ✔ ${C_RESET}" \
      || marker="${C_DIM}  ○ ${C_RESET}"
    echo -e "${marker}${dep}"
  done
fi

if [[ ${#makedepends[@]} -gt 0 ]]; then
  echo ""
  kport_header "Build dependencies (${#makedepends[@]})"
  for dep in "${makedepends[@]}"; do
    echo "    ${dep}"
  done
fi

# USE flags
if [[ ${#kuse[@]} -gt 0 ]]; then
  echo ""
  kport_header "USE flags declared by package"
  for flag in "${kuse[@]}"; do
    local sign="${flag:0:1}"
    local name="${flag:1}"
    if [[ "$sign" == "+" ]]; then
      echo -e "  ${C_GREEN}+${name}${C_RESET}  ${C_DIM}(default on)${C_RESET}"
    else
      echo -e "  ${C_DIM}-${name}  (default off)${C_RESET}"
    fi
  done
fi

# Resolved USE flags (live resolution)
if [[ "$SHOW_USE_FLAGS" == "true" ]]; then
  echo ""
  kport_header "Resolved USE flags (current config)"
  pkgname="$pkgname" KUSE=("${kuse[@]}") \
    KPORT_CONF_DIR="$KPORT_CONF" \
    source "${KPORT_LIB}/use-helpers.sh" 2>/dev/null || true
  use_dump
fi

# Installed files
if [[ "$SHOW_FILES" == "true" && "$installed" == "true" ]]; then
  echo ""
  kport_header "Installed files"
  kport_db_read "$pkgname" files | while read -r f; do
    echo "    $f"
  done
fi

echo ""
