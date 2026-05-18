#!/usr/bin/env bash
#
# resolver-check.sh
#
# Runs kport_resolve on a set of representative leaf packages and checks that:
#   - Resolution completes without "KPort package not found" warnings
#   - The resolved order is non-empty
#   - No circular dependency warnings are emitted
#
# Usage:
#   resolver-check.sh [--packages <pkg,...>] [--quiet]
#
# The default package set covers all four categories (frameworks, plasma, gear, qt6)
# and exercises the full dep chain from leaf apps down to qt6-base.
#
# Exit codes:
#   0  all checks passed
#   1  one or more resolver warnings or empty plans found

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KPORT_ROOT="${KPORT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
QUIET=false
CUSTOM_PACKAGES=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --packages) CUSTOM_PACKAGES="$2"; shift 2 ;;
    --quiet)    QUIET=true;           shift ;;
    --help)
      sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | grep '^#' | sed 's/^# \?//'
      exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Default representative leaf packages — one per category
DEFAULT_PACKAGES=(
  "kf6-karchive"       # frameworks/tier2 — exercises qt6-base chain
  "dolphin"            # gear — exercises kf6 + qt6 chain
  "kleopatra"          # gear/pim — exercises kpim6 chain
  "kwin-wayland"       # plasma — exercises plasma chain
  "qt6-declarative"    # qt6 — exercises qt6-base
)

if [[ -n "$CUSTOM_PACKAGES" ]]; then
  IFS=',' read -ra CHECK_PACKAGES <<< "$CUSTOM_PACKAGES"
else
  CHECK_PACKAGES=("${DEFAULT_PACKAGES[@]}")
fi

# ── Bootstrap kport env ───────────────────────────────────────────────────────

export KPORT_ROOT
export KPORT_LIB="${KPORT_ROOT}/lib/kport"
export KPORT_DB="${KPORT_ROOT}/.ci-db"          # isolated throwaway DB
export KPORT_CONF="${KPORT_ROOT}/config"
export KPORT_RESOLVE_ALL=true                    # resolve full tree, ignore installed

mkdir -p "${KPORT_DB}/installed"

source "${KPORT_LIB}/common.sh"
source "${KPORT_LIB}/resolve.sh"

# ── Run resolver checks ───────────────────────────────────────────────────────

errors=0
info() { [[ "$QUIET" == "true" ]] || echo "$*"; }

info "Resolver dry-run for ${#CHECK_PACKAGES[@]} package(s)"
info ""

for pkg in "${CHECK_PACKAGES[@]}"; do
  info "  resolving: ${pkg}"

  # Capture both stdout (plan) and stderr (warnings)
  resolver_out=$(kport_resolve "$pkg" 2>&1)
  plan_lines=$(kport_resolve "$pkg" 2>/dev/null | wc -l)

  # Check for missing KPort package warnings
  missing=$(echo "$resolver_out" | grep "KPort package not found:" || true)
  circular=$(echo "$resolver_out" | grep "Circular dependency" || true)

  if [[ -n "$missing" ]]; then
    echo "  ERROR: ${pkg}: unresolved KPort deps:" >&2
    echo "$missing" | sed 's/^/    /' >&2
    (( errors++ )) || true
  fi

  if [[ -n "$circular" ]]; then
    echo "  ERROR: ${pkg}: circular dependency detected:" >&2
    echo "$circular" | sed 's/^/    /' >&2
    (( errors++ )) || true
  fi

  if [[ "$plan_lines" -eq 0 ]]; then
    echo "  ERROR: ${pkg}: resolver returned empty plan" >&2
    (( errors++ )) || true
  else
    info "    → ${plan_lines} package(s) in install order"
  fi
done

# ── Overlay resolution test ───────────────────────────────────────────────────
# Verify that kport_find_pacscript returns the overlay version of kf6-karchive
# when the example overlay is enabled in repositories.yml.

info ""
info "  overlay resolution: kf6-karchive (example overlay should shadow main tree)"

overlay_ps=$(kport_find_pacscript "kf6-karchive" 2>/dev/null)
if [[ "$overlay_ps" == *"overlays/example"* ]]; then
  info "    → overlay hit: ${overlay_ps##${KPORT_ROOT}/}"
else
  echo "  ERROR: kf6-karchive resolved to main tree instead of example overlay" >&2
  echo "    got: ${overlay_ps}" >&2
  (( errors++ )) || true
fi

# Verify the overlay pacscript has the expected marker in pkgdesc
overlay_desc=$(kport_pacscript_var "$overlay_ps" pkgdesc 2>/dev/null)
if [[ "$overlay_desc" == *"example overlay"* ]]; then
  info "    → pkgdesc confirms overlay version"
else
  echo "  ERROR: overlay pkgdesc does not contain 'example overlay' marker" >&2
  echo "    got: ${overlay_desc}" >&2
  (( errors++ )) || true
fi

# ── Keyword enforcement tests ─────────────────────────────────────────────────
# Exercises kport_check_keyword() with synthetic pacscripts and hardware configs
# to verify that stability, CPU tier, and GPU tier gates work correctly.

info ""
info "  keyword enforcement tests"

# Temp workspace for synthetic fixtures
KW_TMP=$(mktemp -d)
trap 'rm -rf "$KW_TMP"' EXIT

# Helper: write a minimal pacscript with given keyword vars
_kw_pacscript() {
  local path="$1"; shift
  {
    echo 'pkgname="kw-test-pkg"'
    echo 'pkgver="1.0"'
    echo 'pkgdesc="keyword test"'
    echo 'KCATEGORY="test"'
    while [[ $# -gt 0 ]]; do echo "$1"; shift; done
  } > "$path"
}

# Helper: write a minimal keywords.yml with given stability list
_kw_yml() {
  local path="$1" stability="$2"
  cat > "$path" << YEOF
accept_keywords:
  stability: [${stability}]
  cpu: [x86-64-v1, x86-64-v2, x86-64-v3, x86-64-v4, aarch64]
  gpu: [gpu-sw, gpu-gl2, gpu-gl4, gpu-vk12, gpu-vk13]
package_keywords:
YEOF
}

# Helper: write a hardware.conf with given CPU_TIER and GPU_TIER
_kw_hw() {
  local path="$1" cpu="$2" gpu="$3"
  cat > "$path" << HWEOF
CPU_TIER="${cpu}"
GPU_TIER="${gpu}"
HWEOF
}

# Save and override config paths for keyword tests
_orig_kw_yml="${KPORT_CONFIG_DIR}/keywords.yml"
_orig_hw_conf="${KPORT_HW_CONF:-}"
_orig_pkg_kw="${KPORT_PKG_KEYWORDS:-}"

_kw_run() {
  local desc="$1" ps="$2" kw_yml="$3" hw_conf="$4" pkg_kw="$5" expect="$6"
  # common.sh derives KPORT_CONFIG_DIR from KPORT_ROOT and KPORT_HW_CONF/
  # KPORT_PKG_KEYWORDS from KPORT_CONF — set both so the overrides take effect
  # after common.sh initialises.  We re-assign the vars inside the subshell
  # after sourcing to win the race against common.sh's defaults.
  bash -c "
    export KPORT_ROOT='${KPORT_ROOT}'
    export KPORT_LIB='${KPORT_LIB}'
    export KPORT_DB='${KPORT_DB}'
    export KPORT_CONF='${KW_TMP}'
    source '${KPORT_LIB}/common.sh'
    # Override paths that common.sh just set from KPORT_ROOT/KPORT_CONF
    KPORT_CONFIG_DIR='${KW_TMP}'
    KPORT_HW_CONF='${hw_conf}'
    KPORT_PKG_KEYWORDS='${pkg_kw}'
    kport_check_keyword 'kw-test-pkg' 'test' '${ps}'
  " 2>/dev/null
  local rc=$?
  if [[ "$expect" == "pass" && $rc -eq 0 ]]; then
    info "    ✔ ${desc}"
  elif [[ "$expect" == "block" && $rc -ne 0 ]]; then
    info "    ✔ ${desc}"
  else
    echo "  ERROR: keyword test '${desc}': expected ${expect}, got rc=${rc}" >&2
    (( errors++ )) || true
  fi
}

# ── Test 1: stability pass (channel in accepted list) ────────────────────────
ps1="${KW_TMP}/ps1.pacscript"
kw1="${KW_TMP}/kw1.yml"
_kw_pacscript "$ps1" 'KNEON_CHANNEL="stable"'
_kw_yml "$kw1" "stable, testing"
cp "$kw1" "${KW_TMP}/keywords.yml"
_kw_run "stability pass (stable channel, accepts stable testing)" \
  "$ps1" "$kw1" "" "" "pass"

# ── Test 2: stability block (channel not in accepted list) ───────────────────
ps2="${KW_TMP}/ps2.pacscript"
kw2="${KW_TMP}/kw2.yml"
_kw_pacscript "$ps2" 'KNEON_CHANNEL="unstable"'
_kw_yml "$kw2" "stable, testing"
cp "$kw2" "${KW_TMP}/keywords.yml"
_kw_run "stability block (unstable channel, accepts stable testing only)" \
  "$ps2" "$kw2" "" "" "block"

# ── Test 3: per-package override unblocks a blocked channel ──────────────────
ps3="${KW_TMP}/ps3.pacscript"
kw3="${KW_TMP}/kw3.yml"
pkg_kw3="${KW_TMP}/pkg_kw3"
_kw_pacscript "$ps3" 'KNEON_CHANNEL="unstable"'
_kw_yml "$kw3" "stable, testing"
cp "$kw3" "${KW_TMP}/keywords.yml"
echo "test/kw-test-pkg: stability: [stable, testing, unstable]" > "$pkg_kw3"
_kw_run "per-package override unblocks unstable channel" \
  "$ps3" "$kw3" "" "$pkg_kw3" "pass"

# ── Test 4: CPU tier block (system below minimum) ─────────────────────────────
ps4="${KW_TMP}/ps4.pacscript"
hw4="${KW_TMP}/hw4.conf"
kw4="${KW_TMP}/kw4.yml"
_kw_pacscript "$ps4" 'KCPU_MIN="x86-64-v4"'
_kw_yml "$kw4" "stable, testing, unstable"
cp "$kw4" "${KW_TMP}/keywords.yml"
_kw_hw "$hw4" "x86-64-v1" "gpu-sw"
_kw_run "CPU tier block (system x86-64-v1, pkg requires x86-64-v4)" \
  "$ps4" "$kw4" "$hw4" "" "block"

# ── Test 5: CPU tier pass (system meets minimum) ──────────────────────────────
ps5="${KW_TMP}/ps5.pacscript"
hw5="${KW_TMP}/hw5.conf"
kw5="${KW_TMP}/kw5.yml"
_kw_pacscript "$ps5" 'KCPU_MIN="x86-64-v2"'
_kw_yml "$kw5" "stable, testing, unstable"
cp "$kw5" "${KW_TMP}/keywords.yml"
_kw_hw "$hw5" "x86-64-v3" "gpu-sw"
_kw_run "CPU tier pass (system x86-64-v3, pkg requires x86-64-v2)" \
  "$ps5" "$kw5" "$hw5" "" "pass"

# ── Test 6: GPU tier block (system below minimum) ─────────────────────────────
ps6="${KW_TMP}/ps6.pacscript"
hw6="${KW_TMP}/hw6.conf"
kw6="${KW_TMP}/kw6.yml"
_kw_pacscript "$ps6" 'KGPU_MIN="gpu-vk13"'
_kw_yml "$kw6" "stable, testing, unstable"
cp "$kw6" "${KW_TMP}/keywords.yml"
_kw_hw "$hw6" "x86-64-v2" "gpu-sw"
_kw_run "GPU tier block (system gpu-sw, pkg requires gpu-vk13)" \
  "$ps6" "$kw6" "$hw6" "" "block"

# ── Test 7: GPU tier pass (system meets minimum) ──────────────────────────────
ps7="${KW_TMP}/ps7.pacscript"
hw7="${KW_TMP}/hw7.conf"
kw7="${KW_TMP}/kw7.yml"
_kw_pacscript "$ps7" 'KGPU_MIN="gpu-gl4"'
_kw_yml "$kw7" "stable, testing, unstable"
cp "$kw7" "${KW_TMP}/keywords.yml"
_kw_hw "$hw7" "x86-64-v2" "gpu-vk12"
_kw_run "GPU tier pass (system gpu-vk12, pkg requires gpu-gl4)" \
  "$ps7" "$kw7" "$hw7" "" "pass"

# ── Test 8: no keyword vars → always pass ─────────────────────────────────────
ps8="${KW_TMP}/ps8.pacscript"
kw8="${KW_TMP}/kw8.yml"
_kw_pacscript "$ps8"   # no KNEON_CHANNEL, KCPU_MIN, KGPU_MIN
_kw_yml "$kw8" "stable"
cp "$kw8" "${KW_TMP}/keywords.yml"
_kw_run "no keyword vars → always pass" \
  "$ps8" "$kw8" "" "" "pass"

# ── Cleanup ───────────────────────────────────────────────────────────────────

rm -rf "${KPORT_DB}"

echo ""
echo "Resolver check complete — ${errors} error(s)"

if (( errors > 0 )); then
  echo "FAIL" >&2
  exit 1
fi

echo "OK"
exit 0
