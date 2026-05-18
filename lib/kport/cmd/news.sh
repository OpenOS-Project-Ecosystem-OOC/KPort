#!/usr/bin/env bash
# kport news
#
# Shows recent git changelog entries for packages in the KPort tree.
# For each package, runs 'git log' against its path in packages/.
#
# When run without arguments, shows news for all installed packages.
# When package names are given, shows news for those packages only.
#
# Requires the KPort tree to be a git repository. If it is not (e.g.
# installed from a tarball), a warning is printed and the command exits 0.
#
# Usage: kport news [options] [pkg...]
#
# Arguments:
#   pkg...         Show news for named package(s). Defaults to installed.
#
# Options:
#   --all          Show news for all packages in the tree (not just installed)
#   --count <n>    Max commits per package (default: 10)
#   --since <ref>  Limit to commits since a date or git ref (e.g. 2025-01-01)
#   --help

set -uo pipefail

# ── Parse args ────────────────────────────────────────────────────────────────

COUNT=10
SINCE=""
SHOW_ALL=false
FILTER_PKGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)      SHOW_ALL=true;         shift ;;
    --count)    COUNT="$2";            shift 2 ;;
    --since)    SINCE="$2";            shift 2 ;;
    --help|-h)
      sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | grep '^#' | sed 's/^# \?//'
      exit 0 ;;
    -*) kport_die "Unknown option: $1" ;;
    *)  FILTER_PKGS+=("$1"); shift ;;
  esac
done

# ── Check git availability ────────────────────────────────────────────────────

if ! git -C "$KPORT_ROOT" rev-parse --git-dir &>/dev/null; then
  kport_warn "KPort tree at ${KPORT_ROOT} is not a git repository — no news available"
  exit 0
fi

# ── Collect packages to show ──────────────────────────────────────────────────

declare -a NEWS_PKGS=()

if [[ ${#FILTER_PKGS[@]} -gt 0 ]]; then
  NEWS_PKGS=("${FILTER_PKGS[@]}")
elif [[ "$SHOW_ALL" == "true" ]]; then
  # All packages in the tree
  mapfile -t NEWS_PKGS < <(
    find "${KPORT_ROOT}/packages" -name "*.pacscript" \
      | sed 's|.*/\([^/]*\)\.pacscript$|\1|' | sort -u
  )
else
  # Installed packages only
  if [[ ! -d "$KPORT_DB_INSTALLED" ]]; then
    kport_info "No packages installed — use 'kport news --all' to see all package news"
    exit 0
  fi
  mapfile -t NEWS_PKGS < <(
    find "$KPORT_DB_INSTALLED" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort
  )
  if [[ ${#NEWS_PKGS[@]} -eq 0 ]]; then
    kport_info "No packages installed — use 'kport news --all' to see all package news"
    exit 0
  fi
fi

# ── Build git log args ────────────────────────────────────────────────────────

git_args=(--oneline "--max-count=${COUNT}")
[[ -n "$SINCE" ]] && git_args+=("--since=${SINCE}")

# ── Show news per package ─────────────────────────────────────────────────────

shown=0; no_history=0

for pkg in "${NEWS_PKGS[@]}"; do
  # Find the pacscript path to determine the packages/ subdir
  ps_path=$(find "${KPORT_ROOT}/packages" -name "${pkg}.pacscript" 2>/dev/null | head -1)

  if [[ -z "$ps_path" ]]; then
    kport_verbose "  ${pkg}: no pacscript found in packages/ — skipping"
    continue
  fi

  pkg_dir="${ps_path%/*}"                          # strip filename
  pkg_rel="${pkg_dir#${KPORT_ROOT}/}"              # relative to repo root

  version=$(kport_db_read "$pkg" version 2>/dev/null || \
            kport_pacscript_var "$ps_path" pkgver 2>/dev/null || echo "")

  # Get git log for this package's directory
  log_out=$(git -C "$KPORT_ROOT" log "${git_args[@]}" -- "$pkg_rel" 2>/dev/null)

  if [[ -z "$log_out" ]]; then
    (( no_history++ )) || true
    kport_verbose "  ${pkg}: no git history for ${pkg_rel}"
    continue
  fi

  # Header
  if [[ -n "$version" ]]; then
    kport_header "${pkg} ${version}"
  else
    kport_header "${pkg}"
  fi
  kport_kv "Path" "$pkg_rel"
  echo ""

  # Print each log line with light formatting
  while IFS= read -r line; do
    hash="${line%% *}"
    msg="${line#* }"
    printf "  ${C_DIM}%s${C_RESET}  %s\n" "$hash" "$msg"
  done <<< "$log_out"

  echo ""
  (( shown++ )) || true
done

# ── Summary ───────────────────────────────────────────────────────────────────

if [[ $shown -eq 0 ]]; then
  kport_info "No changelog entries found"
  if [[ $no_history -gt 0 ]]; then
    kport_info "  (${no_history} package(s) have no git history yet)"
  fi
else
  kport_verbose "Showed news for ${shown} package(s); ${no_history} had no history"
fi

exit 0
