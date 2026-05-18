#!/usr/bin/env bash
# lib/kport/common.sh
#
# Shared utilities sourced by all kport subcommand scripts.
# Sourced by bin/kport before dispatching to a command.
# Never executed directly.

[[ -n "${_KPORT_COMMON_LOADED:-}" ]] && return 0
_KPORT_COMMON_LOADED=1

# ── Sanity checks ─────────────────────────────────────────────────────────────

[[ -n "${KPORT_ROOT:-}" ]]  || { echo "KPORT_ROOT not set" >&2; exit 1; }
[[ -n "${KPORT_LIB:-}" ]]   || { echo "KPORT_LIB not set"  >&2; exit 1; }
[[ -n "${KPORT_DB:-}" ]]    || { echo "KPORT_DB not set"   >&2; exit 1; }
[[ -n "${KPORT_CONF:-}" ]]  || { echo "KPORT_CONF not set" >&2; exit 1; }

# ── Package tree paths ────────────────────────────────────────────────────────

KPORT_PACKAGES_DIR="${KPORT_ROOT}/packages"
KPORT_GENERATED_DIR="${KPORT_ROOT}/generated"
KPORT_OVERLAYS_DIR="${KPORT_ROOT}/overlays"
KPORT_CONFIG_DIR="${KPORT_ROOT}/config"

KPORT_HW_CONF="${KPORT_CONF}/hardware.conf"
KPORT_USE_CONF="${KPORT_CONF}/use.conf"
KPORT_PKG_USE="${KPORT_CONF}/package.use"
KPORT_PKG_UNMASK="${KPORT_CONF}/package.unmask"
KPORT_PKG_KEYWORDS="${KPORT_CONF}/package.accept_keywords"

KPORT_DB_WORLD="${KPORT_DB}/world"
KPORT_DB_INSTALLED="${KPORT_DB}/installed"

export KPORT_PACKAGES_DIR KPORT_GENERATED_DIR KPORT_OVERLAYS_DIR
export KPORT_CONFIG_DIR KPORT_HW_CONF KPORT_USE_CONF KPORT_PKG_USE KPORT_PKG_UNMASK KPORT_PKG_KEYWORDS
export KPORT_DB_WORLD KPORT_DB_INSTALLED

# ── Package resolution ────────────────────────────────────────────────────────

# Find the pacscript for a package name.
# Searches: overlays (by priority) → packages/ tree.
# Args: pkgname
# Outputs: absolute path to .pacscript, or empty if not found.
kport_find_pacscript() {
  local pkgname="$1"

  # Search enabled overlays in priority order (highest first).
  # The overlay list is cached in _KPORT_OVERLAY_NAMES for the process lifetime
  # to avoid a python3 subprocess on every package lookup during resolution.
  if [[ -d "$KPORT_OVERLAYS_DIR" && -f "${KPORT_CONFIG_DIR}/repositories.yml" ]]; then
    if [[ -z "${_KPORT_OVERLAY_NAMES+set}" ]]; then
      mapfile -t _KPORT_OVERLAY_NAMES < <(
        python3 "${KPORT_LIB}/list-overlays.py" \
          "${KPORT_CONFIG_DIR}/repositories.yml" 2>/dev/null
      )
      export _KPORT_OVERLAY_NAMES
    fi
    local overlay_name overlay_hit
    for overlay_name in "${_KPORT_OVERLAY_NAMES[@]:-}"; do
      [[ -z "$overlay_name" ]] && continue
      overlay_hit=$(find "${KPORT_OVERLAYS_DIR}/${overlay_name}" \
        -name "${pkgname}.pacscript" 2>/dev/null | head -1)
      [[ -n "$overlay_hit" ]] && echo "$overlay_hit" && return 0
    done
  fi

  # Search main packages tree
  local pkg_hit
  pkg_hit=$(find "$KPORT_PACKAGES_DIR" -name "${pkgname}.pacscript" 2>/dev/null | head -1)
  [[ -n "$pkg_hit" ]] && echo "$pkg_hit" && return 0

  return 1
}

# Extract a variable value from a pacscript without executing it.
# Args: pacscript_path  variable_name
# Outputs: variable value (unquoted)
kport_pacscript_var() {
  local path="$1" varname="$2"
  grep -m1 "^${varname}=" "$path" 2>/dev/null \
    | sed "s/^${varname}=//;s/^['\"]//;s/['\"]$//"
}

# Extract an array variable from a pacscript without executing it.
# Args: pacscript_path  variable_name
# Outputs: one element per line
kport_pacscript_array() {
  local path="$1" varname="$2"
  python3 - "$path" "$varname" << 'PYEOF'
import sys, re

path    = sys.argv[1]
varname = sys.argv[2]

with open(path) as f:
    content = f.read()

# Strip line comments before parsing so that ')' inside comments does not
# confuse the array boundary detection.
content_no_comments = re.sub(r'#[^\n]*', '', content)

# Match varname=( ... ) using the comment-stripped content.
# Use a non-greedy match up to the first bare ')' on its own line.
m = re.search(
    r'^' + re.escape(varname) + r'\s*=\s*\(([^)]*)\)',
    content_no_comments, re.MULTILINE | re.DOTALL
)
if not m:
    sys.exit(0)

block = m.group(1)
# Extract quoted or unquoted tokens
for tok in re.findall(r'"([^"]*)"' + r"|'([^']*)'" + r'|(\S+)', block):
    val = tok[0] or tok[1] or tok[2]
    val = val.strip()
    if val:
        print(val)
PYEOF
}

# ── Database helpers ──────────────────────────────────────────────────────────

# Check if a package is installed.
# Args: pkgname
kport_is_installed() {
  local pkgname="$1"
  [[ -d "${KPORT_DB_INSTALLED}/${pkgname}" ]]
}

# Read an installed package's metadata field.
# Args: pkgname  field (version|slot|use_flags|files)
kport_db_read() {
  local pkgname="$1" field="$2"
  local path="${KPORT_DB_INSTALLED}/${pkgname}/${field}"
  [[ -f "$path" ]] && cat "$path"
}

# Write a package metadata field to the database.
# Args: pkgname  field  value
kport_db_write() {
  local pkgname="$1" field="$2" value="$3"
  local dir="${KPORT_DB_INSTALLED}/${pkgname}"
  mkdir -p "$dir"
  echo "$value" > "${dir}/${field}"
}

# Remove a package from the database.
# Args: pkgname
kport_db_remove() {
  local pkgname="$1"
  rm -rf "${KPORT_DB_INSTALLED:?}/${pkgname}"
}

# Add a package to the world set (explicitly installed).
# Args: pkgname  category
kport_world_add() {
  local pkgname="$1" category="$2"
  mkdir -p "$(dirname "$KPORT_DB_WORLD")"
  local entry="${category}/${pkgname}"
  grep -qxF "$entry" "$KPORT_DB_WORLD" 2>/dev/null || echo "$entry" >> "$KPORT_DB_WORLD"
}

# Remove a package from the world set.
# Args: pkgname  category
kport_world_remove() {
  local pkgname="$1" category="$2"
  local entry="${category}/${pkgname}"
  [[ -f "$KPORT_DB_WORLD" ]] || return 0
  local tmp
  tmp=$(mktemp)
  grep -vxF "$entry" "$KPORT_DB_WORLD" > "$tmp" || true
  mv "$tmp" "$KPORT_DB_WORLD"
}

# ── Hardware config helpers ───────────────────────────────────────────────────

# Read a value from hardware.conf.
# Args: key (e.g. CPU_TIER, GPU_TIER)
kport_hw_read() {
  local key="$1"
  [[ -f "$KPORT_HW_CONF" ]] || return 1
  grep -m1 "^${key}=" "$KPORT_HW_CONF" \
    | sed "s/^${key}=//;s/^['\"]//;s/['\"]$//"
}

# ── Mask / keyword checks ─────────────────────────────────────────────────────

# Check if a package is masked.
# Args: pkgname  category
# Returns 0 if masked, 1 if not.
kport_is_masked() {
  local pkgname="$1" category="$2"
  local masks_file="${KPORT_CONFIG_DIR}/masks.yml"
  [[ -f "$masks_file" ]] || return 1

  # Check user unmask file first
  if [[ -f "$KPORT_PKG_UNMASK" ]]; then
    grep -qxF "${category}/${pkgname}" "$KPORT_PKG_UNMASK" && return 1
  fi

  # Simple check: is the package listed in masks.yml?
  grep -q "pkg: ${category}/${pkgname}" "$masks_file" 2>/dev/null
}

# kport_check_keyword pkgname category pacscript
# Returns 0 if the package is accepted under current keywords, 1 if blocked.
# Checks:
#   1. KNEON_CHANNEL vs accept_keywords.stability in config/keywords.yml
#   2. KCPU_MIN vs CPU_TIER in hardware.conf
#   3. KGPU_MIN vs GPU_TIER in hardware.conf
#   Per-package overrides in ~/.config/kport/package.accept_keywords take
#   precedence over the global keywords.yml defaults.
kport_check_keyword() {
  local pkgname="$1" category="$2" pacscript="$3"

  local channel cpu_min gpu_min
  channel=$(kport_pacscript_var "$pacscript" KNEON_CHANNEL)
  cpu_min=$(kport_pacscript_var "$pacscript" KCPU_MIN)
  gpu_min=$(kport_pacscript_var "$pacscript" KGPU_MIN)

  # ── Stability check ───────────────────────────────────────────────────────

  if [[ -n "$channel" ]]; then
    # Delegate YAML parsing to a helper script to avoid export -f quoting issues
    local accepted_stability
    accepted_stability=$(python3 "${KPORT_LIB}/keyword-check.py" \
      "${KPORT_CONFIG_DIR}/keywords.yml" "${category}/${pkgname}" "$channel" 2>/dev/null \
      || echo "stable testing")

    # User package.accept_keywords overrides (simple key: stability: [..] format)
    if [[ -f "${KPORT_PKG_KEYWORDS:-}" ]]; then
      local user_stability
      user_stability=$(grep -E "^${category}/${pkgname}:" "$KPORT_PKG_KEYWORDS" 2>/dev/null \
        | sed 's/.*stability:[[:space:]]*//' | tr -d '[]"' | tr ',' ' ') || true
      [[ -n "$user_stability" ]] && accepted_stability="$user_stability"
    fi

    local kw ok=false
    for kw in $accepted_stability; do
      [[ "$kw" == "$channel" ]] && ok=true && break
    done
    [[ "$ok" == "false" ]] && return 1
  fi

  # ── CPU tier check ────────────────────────────────────────────────────────

  if [[ -n "$cpu_min" && -f "${KPORT_HW_CONF:-}" ]]; then
    local cpu_tier
    cpu_tier=$(grep "^CPU_TIER=" "$KPORT_HW_CONF" | cut -d'"' -f2)
    if [[ -n "$cpu_tier" ]]; then
      local -a cpu_order=(x86-64-v1 x86-64-v2 x86-64-v3 x86-64-v4 aarch64 aarch64-v8.2)
      local tier_idx=-1 min_idx=-1 i
      for i in "${!cpu_order[@]}"; do
        [[ "${cpu_order[$i]}" == "$cpu_tier" ]] && tier_idx=$i
        [[ "${cpu_order[$i]}" == "$cpu_min"  ]] && min_idx=$i
      done
      [[ $tier_idx -ge 0 && $min_idx -ge 0 && $tier_idx -lt $min_idx ]] && return 1
    fi
  fi

  # ── GPU tier check ────────────────────────────────────────────────────────

  if [[ -n "$gpu_min" && -f "${KPORT_HW_CONF:-}" ]]; then
    local gpu_tier
    gpu_tier=$(grep "^GPU_TIER=" "$KPORT_HW_CONF" | cut -d'"' -f2)
    if [[ -n "$gpu_tier" ]]; then
      local -a gpu_order=(gpu-sw gpu-gl2 gpu-gl4 gpu-vk12 gpu-vk13)
      local gtier_idx=-1 gmin_idx=-1 j
      for j in "${!gpu_order[@]}"; do
        [[ "${gpu_order[$j]}" == "$gpu_tier" ]] && gtier_idx=$j
        [[ "${gpu_order[$j]}" == "$gpu_min"  ]] && gmin_idx=$j
      done
      [[ $gtier_idx -ge 0 && $gmin_idx -ge 0 && $gtier_idx -lt $gmin_idx ]] && return 1
    fi
  fi

  return 0
}

# ── Formatting helpers ────────────────────────────────────────────────────────

# Print a section header.
kport_header() {
  echo -e "\n${C_BOLD}${C_CYAN}$*${C_RESET}"
  echo -e "${C_DIM}$(printf '%.0s─' {1..50})${C_RESET}"
}

# Print a key: value pair.
kport_kv() {
  printf "  ${C_BOLD}%-18s${C_RESET} %s\n" "$1" "$2"
}

# Confirm a destructive action. Returns 0 if confirmed.
# Args: prompt
kport_confirm() {
  local prompt="${1:-Continue?}"
  local reply
  read -r -p "$(echo -e "${C_YELLOW}?? ${C_RESET}${prompt} [y/N] ")" reply
  [[ "${reply,,}" == "y" || "${reply,,}" == "yes" ]]
}
