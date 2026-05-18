#!/usr/bin/env bash
# lib/kport/resolve.sh
#
# Dependency resolver for kport install/upgrade.
# Sourced by install.sh and upgrade.sh — never executed directly.
#
# Public functions:
#   kport_resolve <pkgname...>
#     Resolves the full install order for one or more packages.
#     Outputs a newline-separated list of pkgnames in install order
#     (dependencies before dependents). Already-installed packages
#     are excluded unless KPORT_RESOLVE_ALL=true.
#
#   kport_resolve_print_plan <pkgname...>
#     Prints a human-readable install plan table.

[[ -n "${_KPORT_RESOLVE_LOADED:-}" ]] && return 0
_KPORT_RESOLVE_LOADED=1

# ── Internal state ────────────────────────────────────────────────────────────

declare -gA _KPORT_RESOLVE_VISITED=()   # pkgname → 1 (cycle detection)
declare -ga _KPORT_RESOLVE_ORDER=()     # final install order

# ── Recursive resolver ────────────────────────────────────────────────────────

# Resolve a single package and its deps recursively (DFS post-order).
# Args: pkgname  [indent-level]
_kport_resolve_one() {
  local pkgname="$1"
  local depth="${2:-0}"

  # Already in the resolved order — skip
  for already in "${_KPORT_RESOLVE_ORDER[@]:-}"; do
    [[ "$already" == "$pkgname" ]] && return 0
  done

  # Cycle detection
  if [[ -n "${_KPORT_RESOLVE_VISITED[$pkgname]:-}" ]]; then
    kport_warn "Circular dependency detected involving ${pkgname} — skipping"
    return 0
  fi
  _KPORT_RESOLVE_VISITED["$pkgname"]=1

  # Find pacscript
  local pacscript
  pacscript=$(kport_find_pacscript "$pkgname") || {
    # Warn only for names that look like KPort packages (kf6-*, plasma-*, kport-*).
    # Bare apt names (qt6-base-dev, libfoo-dev, etc.) are system deps — skip silently.
    if [[ "$pkgname" == kf6-* || "$pkgname" == plasma-* || "$pkgname" == kport-* ]]; then
      kport_warn "  KPort package not found: ${pkgname}"
    else
      kport_verbose "  system dep (apt): ${pkgname}"
    fi
    unset '_KPORT_RESOLVE_VISITED[$pkgname]'
    return 0
  }

  # Mask check — blocked packages are never installed
  local category
  category=$(kport_pacscript_var "$pacscript" KCATEGORY)
  if kport_is_masked "$pkgname" "$category"; then
    kport_warn "  ${pkgname}: masked — skipping (unmask in ~/.config/kport/package.unmask)"
    unset '_KPORT_RESOLVE_VISITED[$pkgname]'
    return 0
  fi

  # Skip already-installed unless KPORT_RESOLVE_ALL=true
  if [[ "${KPORT_RESOLVE_ALL:-false}" != "true" ]]; then
    if kport_is_installed "$pkgname"; then
      kport_verbose "  already installed: ${pkgname}"
      unset '_KPORT_RESOLVE_VISITED[$pkgname]'
      return 0
    fi
  fi

  # Recurse into depends
  local dep
  while IFS= read -r dep; do
    [[ -z "$dep" ]] && continue
    # Skip ~apt: and ~virtual: deps — not managed by kport
    [[ "$dep" == "~apt:"* || "$dep" == "~virtual:"* ]] && continue
    _kport_resolve_one "$dep" $(( depth + 1 ))
  done < <(kport_pacscript_array "$pacscript" depends)

  # Add this package after its deps (post-order)
  _KPORT_RESOLVE_ORDER+=("$pkgname")
  unset '_KPORT_RESOLVE_VISITED[$pkgname]'
}

# ── Public API ────────────────────────────────────────────────────────────────

# kport_resolve <pkgname...>
# Outputs install order to stdout, one pkgname per line.
kport_resolve() {
  _KPORT_RESOLVE_VISITED=()
  _KPORT_RESOLVE_ORDER=()

  for pkg in "$@"; do
    _kport_resolve_one "$pkg"
  done

  [[ ${#_KPORT_RESOLVE_ORDER[@]} -gt 0 ]] && printf '%s\n' "${_KPORT_RESOLVE_ORDER[@]}"
}

# kport_resolve_print_plan <pkgname...>
# Prints a formatted install plan. Returns 0 if anything to install, 1 if empty.
kport_resolve_print_plan() {
  local -a plan
  mapfile -t plan < <(kport_resolve "$@")

  if [[ ${#plan[@]} -eq 0 ]]; then
    kport_info "Nothing to install — all packages already up to date."
    return 1
  fi

  kport_header "Install plan (${#plan[@]} package(s))"
  for pkg in "${plan[@]}"; do
    local pacscript ver category
    pacscript=$(kport_find_pacscript "$pkg") || continue
    ver=$(kport_pacscript_var "$pacscript" pkgver)
    category=$(kport_pacscript_var "$pacscript" KCATEGORY)
    printf "  ${C_BOLD}%-30s${C_RESET} ${C_DIM}%-12s  %s${C_RESET}\n" \
      "$pkg" "$ver" "$category"
  done
  echo ""
  return 0
}
