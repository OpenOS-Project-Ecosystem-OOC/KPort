#!/usr/bin/env bash
# kport install
#
# Resolves dependencies, builds, and installs one or more packages.
# Uses Pacstall to execute the pacscript build/package/install steps.
#
# Usage: kport install [options] <pkgname...>
#
# Options:
#   --ask           Show install plan and ask for confirmation (default)
#   --no-ask        Install without confirmation prompt
#   --dry-run       Show what would be installed without doing it
#   --rebuild       Reinstall even if already installed
#   --direct        Run build()/package() directly without pacstall (no sandbox)
#   --use "<flags>" Temporary USE flag overrides for this install only
#                   Format: "+flag -flag" (space-separated)
#   --help

set -uo pipefail

source "${KPORT_LIB}/resolve.sh"

# ── Parse args ────────────────────────────────────────────────────────────────

ASK=true
DRY_RUN=false
REBUILD=false
DIRECT=false
EXTRA_USE=""
PACKAGES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ask)      ASK=true;          shift ;;
    --no-ask)   ASK=false;         shift ;;
    --dry-run)  DRY_RUN=true;      shift ;;
    --rebuild)  REBUILD=true;      shift ;;
    --direct)   DIRECT=true;       shift ;;
    --use)      EXTRA_USE="$2";    shift 2 ;;
    --help|-h)
      sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | grep '^#' | sed 's/^# \?//'
      exit 0 ;;
    -*) kport_die "Unknown option: $1" ;;
    *)  PACKAGES+=("$1"); shift ;;
  esac
done

[[ ${#PACKAGES[@]} -eq 0 ]] && kport_die "Usage: kport install <pkgname...>"

[[ "$REBUILD" == "true" ]] && export KPORT_RESOLVE_ALL=true

# ── Resolve install plan ──────────────────────────────────────────────────────

kport_resolve_print_plan "${PACKAGES[@]}" || exit 0

mapfile -t INSTALL_ORDER < <(kport_resolve "${PACKAGES[@]}")

# ── Confirm ───────────────────────────────────────────────────────────────────

if [[ "$DRY_RUN" == "true" ]]; then
  kport_info "Dry run — nothing will be installed."
  exit 0
fi

if [[ "$ASK" == "true" ]]; then
  kport_confirm "Proceed with installation?" || { kport_info "Aborted."; exit 0; }
fi

# ── Internal helpers ──────────────────────────────────────────────────────────

_kport_record_install() {
  local pkgname="$1" pkgver="$2" category="$3" pacscript="$4"

  kport_db_write "$pkgname" "version"  "$pkgver"
  kport_db_write "$pkgname" "slot"     "$(kport_pacscript_var "$pacscript" KSLOT)"
  kport_db_write "$pkgname" "category" "$category"

  # Record active USE flags — serialize KUSE array into the subshell body so
  # bash receives a proper array (env var assignments only set scalars).
  local active_flags kuse_arr kuse_decl
  mapfile -t kuse_arr < <(kport_pacscript_array "$pacscript" KUSE)
  printf -v kuse_decl 'KUSE=(%s)' "$(printf '"%s" ' "${kuse_arr[@]}")"
  active_flags=$(pkgname="$pkgname" KPORT_CONF_DIR="$KPORT_CONF" \
    bash -c "${kuse_decl}; source \"\${KPORT_LIB}/use-helpers.sh\" && use_active_flags" 2>/dev/null \
    | tr '\n' ' ' | sed 's/ $//' || true)
  kport_db_write "$pkgname" "use_flags" "$active_flags"

  # Snapshot hardware.conf
  [[ -f "$KPORT_HW_CONF" ]] && \
    cp "$KPORT_HW_CONF" "${KPORT_DB_INSTALLED}/${pkgname}/hardware_conf"

  # Add to world set (explicitly requested packages only)
  for requested in "${PACKAGES[@]}"; do
    [[ "$requested" == "$pkgname" ]] && kport_world_add "$pkgname" "$category" && break
  done
}

_kport_build_direct() {
  local pkgname="$1" pkgver="$2" category="$3" pacscript="$4"
  shift 4
  local build_env=("$@")

  local build_dir
  build_dir=$(mktemp -d)
  trap "rm -rf ${build_dir}" RETURN

  kport_info "Build dir: ${build_dir}"

  # Source the pacscript in a subshell to get source URLs, then fetch
  local source_url
  source_url=$(env "${build_env[@]}" bash -c "
    source '${pacscript}'
    echo \"\${source[0]:-}\"
  " 2>/dev/null)

  if [[ -z "$source_url" ]]; then
    kport_error "Could not determine source URL from pacscript"
    return 1
  fi

  kport_info "Fetching: ${source_url}"
  local tarball="${build_dir}/source.tar.xz"
  curl -fL --progress-bar -o "$tarball" "$source_url" \
    || { kport_error "Download failed"; return 1; }

  kport_info "Extracting..."
  tar -xf "$tarball" -C "$build_dir" --strip-components=1 \
    || { kport_error "Extraction failed"; return 1; }

  kport_info "Building..."
  local pkgdir="${build_dir}/pkg"
  mkdir -p "$pkgdir"

  (
    cd "$build_dir"
    export pkgdir pkgname pkgver
    env "${build_env[@]}" bash -c "
      source '${pacscript}'
      build
    " || exit 1

    env "${build_env[@]}" bash -c "
      source '${pacscript}'
      package
    " || exit 1
  ) || { kport_error "Build/package failed"; return 1; }

  kport_info "Installing to system..."
  sudo cp -r "${pkgdir}/." / \
    || { kport_error "Install failed (sudo cp)"; return 1; }

  # Record installed files and symlinks
  mkdir -p "${KPORT_DB_INSTALLED}/${pkgname}"
  find "$pkgdir" \( -type f -o -type l \) | sed "s|^${pkgdir}||" \
    > "${KPORT_DB_INSTALLED}/${pkgname}/files"

  _kport_record_install "$pkgname" "$pkgver" "$category" "$pacscript"
  kport_info "${C_GREEN}✔${C_RESET} Installed ${pkgname} ${pkgver}"
}

# ── Install each package ──────────────────────────────────────────────────────

ok=0; failed=0

for pkgname in "${INSTALL_ORDER[@]}"; do
  pacscript=$(kport_find_pacscript "$pkgname") \
    || { kport_warn "Pacscript not found for ${pkgname} — skipping"; (( failed++ )) || true; continue; }

  pkgver=$(kport_pacscript_var "$pacscript" pkgver)
  category=$(kport_pacscript_var "$pacscript" KCATEGORY)

  kport_header "Installing ${pkgname} ${pkgver}"
  kport_kv "Category"   "$category"
  kport_kv "Pacscript"  "$pacscript"
  echo ""

  # Build a temporary use.conf overlay for --use overrides
  local_use_conf=""
  if [[ -n "$EXTRA_USE" ]]; then
    local_use_conf=$(mktemp)
    for flag in $EXTRA_USE; do echo "$flag"; done > "$local_use_conf"
    kport_info "Temporary USE overrides: ${EXTRA_USE}"
  fi

  # Set up build environment
  build_env=(
    KPORT_ROOT="$KPORT_ROOT"
    KPORT_LIB_DIR="$KPORT_LIB"
    KPORT_CONF_DIR="$KPORT_CONF"
  )
  [[ -n "$local_use_conf" ]] && build_env+=(KPORT_EXTRA_USE_CONF="$local_use_conf")

  # Execute via pacstall if available and --direct not requested
  if [[ "$DIRECT" != "true" ]] && command -v pacstall &>/dev/null; then
    kport_info "Running pacstall install..."
    if env "${build_env[@]}" pacstall -I "$pacscript"; then
      kport_info "${C_GREEN}✔${C_RESET} Installed ${pkgname} ${pkgver}"
      _kport_record_install "$pkgname" "$pkgver" "$category" "$pacscript"
      (( ok++ )) || true
    else
      kport_error "Failed to install ${pkgname} via pacstall"
      kport_info "Tip: retry with --direct to build without pacstall sandbox"
      (( failed++ )) || true
    fi
  else
    # Run build() + package() directly in a temp dir (no pacstall sandbox)
    [[ "$DIRECT" == "true" ]] \
      && kport_info "Running build() directly (--direct mode)" \
      || kport_warn "pacstall not found — running build() directly"
    _kport_build_direct "$pkgname" "$pkgver" "$category" "$pacscript" "${build_env[@]}" \
      && (( ok++ )) || true \
      || (( failed++ )) || true
  fi

  [[ -n "$local_use_conf" ]] && rm -f "$local_use_conf"
  echo ""
done

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
kport_info "Install complete — succeeded: ${ok}  failed: ${failed}"
[[ "$failed" -gt 0 ]] && exit 1 || exit 0
