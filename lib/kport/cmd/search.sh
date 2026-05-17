#!/usr/bin/env bash
# kport search
#
# Search for packages by name or description.
# Searches packages/ tree and enabled overlays.
#
# Usage: kport search [options] <query>
#
# Options:
#   --category <cat>   Limit to a category (e.g. frameworks, plasma)
#   --installed        Show only installed packages
#   --exact            Exact name match only
#   --help

set -uo pipefail

# ── Parse args ────────────────────────────────────────────────────────────────

FILTER_CATEGORY=""
INSTALLED_ONLY=false
EXACT=false
QUERY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --category)    FILTER_CATEGORY="$2"; shift 2 ;;
    --installed)   INSTALLED_ONLY=true;  shift ;;
    --exact)       EXACT=true;           shift ;;
    --help|-h)
      sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | grep '^#' | sed 's/^# \?//'
      exit 0 ;;
    -*) kport_die "Unknown option: $1" ;;
    *)  QUERY="$1"; shift ;;
  esac
done

[[ -z "$QUERY" ]] && kport_die "Usage: kport search <query>"

# ── Search ────────────────────────────────────────────────────────────────────

found=0

# Collect search paths: overlays first, then main tree
search_dirs=()
if [[ -d "$KPORT_OVERLAYS_DIR" ]]; then
  while IFS= read -r d; do
    [[ "$d" == *"/example" ]] && continue
    search_dirs+=("$d")
  done < <(find "$KPORT_OVERLAYS_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
fi
search_dirs+=("$KPORT_PACKAGES_DIR")

for search_root in "${search_dirs[@]}"; do
  [[ -d "$search_root" ]] || continue

  while IFS= read -r pacscript; do
    pkgname=$(kport_pacscript_var "$pacscript" pkgname)
    pkgver=$(kport_pacscript_var  "$pacscript" pkgver)
    pkgdesc=$(kport_pacscript_var "$pacscript" pkgdesc)
    category=$(kport_pacscript_var "$pacscript" KCATEGORY)

    # Category filter
    [[ -n "$FILTER_CATEGORY" && "$category" != *"$FILTER_CATEGORY"* ]] && continue

    # Installed filter
    if [[ "$INSTALLED_ONLY" == "true" ]]; then
      kport_is_installed "$pkgname" || continue
    fi

    # Query match
    if [[ "$EXACT" == "true" ]]; then
      [[ "$pkgname" != "$QUERY" ]] && continue
    else
      # Case-insensitive match against name or description
      local lower_query="${QUERY,,}"
      [[ "${pkgname,,}" != *"$lower_query"* && "${pkgdesc,,}" != *"$lower_query"* ]] && continue
    fi

    # Format result
    local installed_marker=""
    kport_is_installed "$pkgname" && installed_marker=" ${C_GREEN}[installed]${C_RESET}"

    echo -e "${C_BOLD}${pkgname}${C_RESET} ${C_DIM}${pkgver}${C_RESET}${installed_marker}"
    echo -e "  ${C_DIM}${category}${C_RESET}"
    [[ -n "$pkgdesc" ]] && echo "  ${pkgdesc}"
    echo ""
    (( found++ )) || true

  done < <(find "$search_root" -name "*.pacscript" 2>/dev/null | sort)
done

if [[ "$found" -eq 0 ]]; then
  kport_warn "No packages found matching '${QUERY}'"
  exit 1
fi

echo -e "${C_DIM}${found} package(s) found${C_RESET}"
