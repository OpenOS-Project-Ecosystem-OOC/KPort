#!/usr/bin/env bash
# kport search
#
# Search for packages by name or description.
# Uses a pre-built index ($KPORT_DB/index.json) when available for speed;
# falls back to live grep across packages/ when the index is absent.
#
# Usage: kport search [options] [query]
#
# Options:
#   --category <cat>   Limit to a category (e.g. frameworks, plasma, gear, qt6)
#   --installed        Show only installed packages
#   --exact            Exact name match only
#   --help

set -uo pipefail

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

[[ -z "$QUERY" && "$INSTALLED_ONLY" != "true" ]] && kport_die "Usage: kport search <query>"

INDEX_FILE="${KPORT_DB}/index.json"

_search_from_index() {
  python3 - "$INDEX_FILE" "$QUERY" "$FILTER_CATEGORY" "$EXACT" << 'PYEOF'
import sys, json

index_file = sys.argv[1]
query      = sys.argv[2].lower()
filter_cat = sys.argv[3].lower()
exact      = sys.argv[4] == "true"

try:
    entries = json.load(open(index_file))
except Exception as e:
    print(f"index error: {e}", file=sys.stderr)
    sys.exit(1)

for e in sorted(entries, key=lambda x: x.get("n", "")):
    name = e.get("n", "")
    ver  = e.get("v", "")
    desc = e.get("d", "")
    cat  = e.get("c", "")
    path = e.get("p", "")
    if filter_cat and filter_cat not in cat.lower():
        continue
    if query:
        if exact:
            if name != query:
                continue
        else:
            if query not in name.lower() and query not in desc.lower():
                continue
    print(f"{name}\t{ver}\t{desc}\t{cat}\t{path}")
PYEOF
}

_search_from_pacscripts() {
  local search_dirs=()
  # Include only registered+enabled overlays (same logic as kport_find_pacscript)
  if [[ -d "$KPORT_OVERLAYS_DIR" && -f "${KPORT_CONFIG_DIR}/repositories.yml" ]]; then
    while IFS= read -r overlay_name; do
      [[ -z "$overlay_name" ]] && continue
      [[ -d "${KPORT_OVERLAYS_DIR}/${overlay_name}" ]] && search_dirs+=("${KPORT_OVERLAYS_DIR}/${overlay_name}")
    done < <(python3 "${KPORT_LIB}/list-overlays.py" \
      "${KPORT_CONFIG_DIR}/repositories.yml" 2>/dev/null || true)
  fi
  search_dirs+=("$KPORT_PACKAGES_DIR")
  for search_root in "${search_dirs[@]}"; do
    [[ -d "$search_root" ]] || continue
    while IFS= read -r pacscript; do
      local pkgname pkgver pkgdesc category
      pkgname=$(kport_pacscript_var "$pacscript" pkgname)
      pkgver=$(kport_pacscript_var  "$pacscript" pkgver)
      pkgdesc=$(kport_pacscript_var "$pacscript" pkgdesc)
      category=$(kport_pacscript_var "$pacscript" KCATEGORY)
      [[ -n "$FILTER_CATEGORY" && "$category" != *"$FILTER_CATEGORY"* ]] && continue
      if [[ "$EXACT" == "true" ]]; then
        [[ "$pkgname" != "$QUERY" ]] && continue
      else
        local lower_query="${QUERY,,}"
        [[ "${pkgname,,}" != *"$lower_query"* && "${pkgdesc,,}" != *"$lower_query"* ]] && continue
      fi
      printf '%s\t%s\t%s\t%s\t%s\n' "$pkgname" "$pkgver" "$pkgdesc" "$category" "$pacscript"
    done < <(find "$search_root" -name "*.pacscript" 2>/dev/null | sort)
  done
}

found=0

_display_result() {
  local pkgname="$1" pkgver="$2" pkgdesc="$3" category="$4" pacscript_path="${5:-}"
  if [[ "$INSTALLED_ONLY" == "true" ]]; then
    kport_is_installed "$pkgname" || return 0
  fi

  # Resolve pacscript path if not provided (live search path)
  if [[ -z "$pacscript_path" ]]; then
    pacscript_path=$(kport_find_pacscript "$pkgname" 2>/dev/null) || true
  fi

  # Status badges
  local status_badge=""
  if kport_is_masked "$pkgname" "$category" 2>/dev/null; then
    status_badge=" ${C_RED}[masked]${C_RESET}"
  elif [[ -n "$pacscript_path" ]] && ! kport_check_keyword "$pkgname" "$category" "$pacscript_path" 2>/dev/null; then
    status_badge=" ${C_YELLOW}[~keyword]${C_RESET}"
  fi

  local installed_marker=""
  kport_is_installed "$pkgname" && installed_marker=" ${C_GREEN}[installed]${C_RESET}"

  # Overlay marker
  local overlay_marker=""
  [[ "$pacscript_path" == *"/overlays/"* ]] && overlay_marker=" ${C_DIM}[overlay]${C_RESET}"

  echo -e "${C_BOLD}${pkgname}${C_RESET} ${C_DIM}${pkgver}${C_RESET}${installed_marker}${status_badge}${overlay_marker}"
  echo -e "  ${C_DIM}${category}${C_RESET}"
  [[ -n "$pkgdesc" ]] && echo "  ${pkgdesc}"
  echo ""
  (( found++ )) || true
}

if [[ -f "$INDEX_FILE" ]]; then
  while IFS=$'\t' read -r pkgname pkgver pkgdesc category pkg_path; do
    _display_result "$pkgname" "$pkgver" "$pkgdesc" "$category" "$pkg_path"
  done < <(_search_from_index)
else
  kport_warn "No search index — run 'kport index' to build one (falling back to live search)"
  while IFS=$'\t' read -r pkgname pkgver pkgdesc category pkg_path; do
    _display_result "$pkgname" "$pkgver" "$pkgdesc" "$category" "$pkg_path"
  done < <(_search_from_pacscripts)
fi

if [[ "$found" -eq 0 ]]; then
  if [[ "$INSTALLED_ONLY" == "true" && -z "$QUERY" ]]; then
    kport_warn "No packages installed."
  else
    kport_warn "No packages found matching '${QUERY}'"
  fi
  exit 1
fi

echo -e "${C_DIM}${found} package(s) found${C_RESET}"
