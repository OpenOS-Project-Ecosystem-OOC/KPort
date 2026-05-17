#!/usr/bin/env bash
# kport upgrade
#
# Rebuilds world set packages that have a newer version available or whose
# resolved USE flags have changed since the last build.
#
# Usage: kport upgrade [options]
#
# Options:
#   --ask          Show upgrade plan and confirm (default)
#   --no-ask       Upgrade without confirmation
#   --dry-run      Show what would be upgraded without doing it
#   --use-changed  Only rebuild packages whose USE flags changed (skip version bumps)
#   --version-only Only rebuild packages with a newer version (skip USE changes)
#   --help

set -uo pipefail

source "${KPORT_LIB}/resolve.sh"

# ── Parse args ────────────────────────────────────────────────────────────────

ASK=true
DRY_RUN=false
USE_CHANGED_ONLY=false
VERSION_ONLY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ask)          ASK=true;              shift ;;
    --no-ask)       ASK=false;             shift ;;
    --dry-run)      DRY_RUN=true;          shift ;;
    --use-changed)  USE_CHANGED_ONLY=true; shift ;;
    --version-only) VERSION_ONLY=true;     shift ;;
    --help|-h)
      sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | grep '^#' | sed 's/^# \?//'
      exit 0 ;;
    -*) kport_die "Unknown option: $1" ;;
    *)  kport_die "Unexpected argument: $1" ;;
  esac
done

# ── Read world set ────────────────────────────────────────────────────────────

[[ -f "$KPORT_DB_WORLD" ]] || { kport_info "World set is empty — nothing to upgrade."; exit 0; }

mapfile -t world_entries < "$KPORT_DB_WORLD"
[[ ${#world_entries[@]} -eq 0 ]] && { kport_info "World set is empty — nothing to upgrade."; exit 0; }

# ── Check each world package for upgrades ────────────────────────────────────

declare -a to_upgrade=()
declare -A upgrade_reason=()

kport_header "Checking world set (${#world_entries[@]} package(s))"

for entry in "${world_entries[@]}"; do
  [[ -z "$entry" ]] && continue
  # entry format: category/pkgname
  pkgname="${entry##*/}"

  pacscript=$(kport_find_pacscript "$pkgname") || {
    kport_warn "  ${pkgname}: pacscript not found — skipping"
    continue
  }

  avail_ver=$(kport_pacscript_var "$pacscript" pkgver)
  inst_ver=$(kport_db_read "$pkgname" version)
  inst_use=$(kport_db_read "$pkgname" use_flags)

  # Compute current resolved USE flags
  mapfile -t kuse_arr < <(kport_pacscript_array "$pacscript" KUSE)
  current_use=$(pkgname="$pkgname" KUSE=("${kuse_arr[@]}") \
    KPORT_CONF_DIR="$KPORT_CONF" \
    bash -c 'source "${KPORT_LIB}/use-helpers.sh" && use_active_flags' 2>/dev/null \
    | tr '\n' ' ' | sed 's/ $//')

  local reason=""
  local needs_upgrade=false

  # Version check
  if [[ "$avail_ver" != "$inst_ver" ]] && [[ "$USE_CHANGED_ONLY" != "true" ]]; then
    reason="version ${inst_ver} → ${avail_ver}"
    needs_upgrade=true
  fi

  # USE flag check
  if [[ "$current_use" != "$inst_use" ]] && [[ "$VERSION_ONLY" != "true" ]]; then
    local use_reason="USE flags changed"
    reason="${reason:+${reason}, }${use_reason}"
    needs_upgrade=true
  fi

  if [[ "$needs_upgrade" == "true" ]]; then
    to_upgrade+=("$pkgname")
    upgrade_reason["$pkgname"]="$reason"
    echo -e "  ${C_BOLD}${pkgname}${C_RESET}  ${C_YELLOW}${reason}${C_RESET}"
  else
    kport_verbose "  ${pkgname}: up to date (${avail_ver})"
  fi
done

echo ""

if [[ ${#to_upgrade[@]} -eq 0 ]]; then
  kport_info "All world packages are up to date."
  exit 0
fi

# ── Resolve full upgrade order (including deps) ───────────────────────────────

kport_header "Upgrade plan"
export KPORT_RESOLVE_ALL=true
kport_resolve_print_plan "${to_upgrade[@]}" || exit 0
mapfile -t upgrade_order < <(kport_resolve "${to_upgrade[@]}")

if [[ "$DRY_RUN" == "true" ]]; then
  kport_info "Dry run — nothing will be upgraded."
  exit 0
fi

if [[ "$ASK" == "true" ]]; then
  kport_confirm "Proceed with upgrade?" || { kport_info "Aborted."; exit 0; }
fi

# ── Delegate to install --rebuild ─────────────────────────────────────────────

exec bash "${KPORT_LIB}/cmd/install.sh" --no-ask --rebuild "${upgrade_order[@]}"
