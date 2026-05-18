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

# ── Test 9: NPU tier block (system below minimum) ─────────────────────────────
ps9="${KW_TMP}/ps9.pacscript"
hw9="${KW_TMP}/hw9.conf"
kw9="${KW_TMP}/kw9.yml"
_kw_pacscript "$ps9" 'KNPU_MIN="npu-dedicated"'
_kw_yml "$kw9" "stable, testing, unstable"
cp "$kw9" "${KW_TMP}/keywords.yml"
_kw_hw "$hw9" "x86-64-v2" "gpu-sw"
echo 'NPU_TIER="npu-none"' >> "$hw9"
_kw_run "NPU tier block (system npu-none, pkg requires npu-dedicated)" \
  "$ps9" "$kw9" "$hw9" "" "block"

# ── Test 10: NPU tier pass (system meets minimum) ─────────────────────────────
ps10="${KW_TMP}/ps10.pacscript"
hw10="${KW_TMP}/hw10.conf"
kw10="${KW_TMP}/kw10.yml"
_kw_pacscript "$ps10" 'KNPU_MIN="npu-igpu"'
_kw_yml "$kw10" "stable, testing, unstable"
cp "$kw10" "${KW_TMP}/keywords.yml"
_kw_hw "$hw10" "x86-64-v2" "gpu-sw"
echo 'NPU_TIER="npu-dedicated"' >> "$hw10"
_kw_run "NPU tier pass (system npu-dedicated, pkg requires npu-igpu)" \
  "$ps10" "$kw10" "$hw10" "" "pass"

# ── ARM CPU tier tests ────────────────────────────────────────────────────────

# ── Test 11: ARM CPU tier block (system aarch64-v8, pkg requires aarch64-v9) ──
ps11="${KW_TMP}/ps11.pacscript"
hw11="${KW_TMP}/hw11.conf"
kw11="${KW_TMP}/kw11.yml"
_kw_pacscript "$ps11" 'KCPU_MIN="aarch64-v9"'
_kw_yml "$kw11" "stable, testing, unstable"
cp "$kw11" "${KW_TMP}/keywords.yml"
_kw_hw "$hw11" "aarch64-v8" "gpu-mali-g52"
_kw_run "ARM CPU tier block (system aarch64-v8, pkg requires aarch64-v9)" \
  "$ps11" "$kw11" "$hw11" "" "block"

# ── Test 12: ARM CPU tier pass (system aarch64-v9.2, pkg requires aarch64-v8.2) ─
ps12="${KW_TMP}/ps12.pacscript"
hw12="${KW_TMP}/hw12.conf"
kw12="${KW_TMP}/kw12.yml"
_kw_pacscript "$ps12" 'KCPU_MIN="aarch64-v8.2"'
_kw_yml "$kw12" "stable, testing, unstable"
cp "$kw12" "${KW_TMP}/keywords.yml"
_kw_hw "$hw12" "aarch64-v9.2" "gpu-mali-g610"
_kw_run "ARM CPU tier pass (system aarch64-v9.2, pkg requires aarch64-v8.2)" \
  "$ps12" "$kw12" "$hw12" "" "pass"

# ── Test 13: cross-arch CPU — x86 pkg on ARM system → pass (undefined, not blocked) ─
ps13="${KW_TMP}/ps13.pacscript"
hw13="${KW_TMP}/hw13.conf"
kw13="${KW_TMP}/kw13.yml"
_kw_pacscript "$ps13" 'KCPU_MIN="x86-64-v4"'
_kw_yml "$kw13" "stable, testing, unstable"
cp "$kw13" "${KW_TMP}/keywords.yml"
_kw_hw "$hw13" "aarch64-v8" "gpu-mali-g52"
_kw_run "cross-arch CPU (x86-64-v4 min on aarch64-v8 system) → not blocked by tier check" \
  "$ps13" "$kw13" "$hw13" "" "pass"

# ── ARM GPU tier tests ────────────────────────────────────────────────────────

# ── Test 14: Mali GPU tier block (system mali-g52, pkg requires mali-g610) ───
ps14="${KW_TMP}/ps14.pacscript"
hw14="${KW_TMP}/hw14.conf"
kw14="${KW_TMP}/kw14.yml"
_kw_pacscript "$ps14" 'KGPU_MIN="gpu-mali-g610"'
_kw_yml "$kw14" "stable, testing, unstable"
cp "$kw14" "${KW_TMP}/keywords.yml"
_kw_hw "$hw14" "aarch64-v8.2" "gpu-mali-g52"
_kw_run "Mali GPU tier block (system gpu-mali-g52, pkg requires gpu-mali-g610)" \
  "$ps14" "$kw14" "$hw14" "" "block"

# ── Test 15: Mali GPU tier pass (system immortalis, pkg requires mali-g610) ──
ps15="${KW_TMP}/ps15.pacscript"
hw15="${KW_TMP}/hw15.conf"
kw15="${KW_TMP}/kw15.yml"
_kw_pacscript "$ps15" 'KGPU_MIN="gpu-mali-g610"'
_kw_yml "$kw15" "stable, testing, unstable"
cp "$kw15" "${KW_TMP}/keywords.yml"
_kw_hw "$hw15" "aarch64-v9" "gpu-immortalis-g715"
_kw_run "Mali GPU tier pass (system gpu-immortalis-g715, pkg requires gpu-mali-g610)" \
  "$ps15" "$kw15" "$hw15" "" "pass"

# ── Test 16: cross-family GPU — x86 pkg on Mali system → pass (undefined) ───
ps16="${KW_TMP}/ps16.pacscript"
hw16="${KW_TMP}/hw16.conf"
kw16="${KW_TMP}/kw16.yml"
_kw_pacscript "$ps16" 'KGPU_MIN="gpu-vk13"'
_kw_yml "$kw16" "stable, testing, unstable"
cp "$kw16" "${KW_TMP}/keywords.yml"
_kw_hw "$hw16" "aarch64-v9" "gpu-immortalis-g715"
_kw_run "cross-family GPU (gpu-vk13 min on gpu-immortalis system) → not blocked by tier check" \
  "$ps16" "$kw16" "$hw16" "" "pass"

# ── RISC-V CPU tier tests ─────────────────────────────────────────────────────

# ── Test 17: RISC-V CPU tier block (system rv64gc, pkg requires rv64gcv) ─────
ps17="${KW_TMP}/ps17.pacscript"
hw17="${KW_TMP}/hw17.conf"
kw17="${KW_TMP}/kw17.yml"
_kw_pacscript "$ps17" 'KCPU_MIN="riscv64-rv64gcv"'
_kw_yml "$kw17" "stable, testing, unstable"
cp "$kw17" "${KW_TMP}/keywords.yml"
_kw_hw "$hw17" "riscv64-rv64gc" "gpu-img-bxm"
_kw_run "RISC-V CPU tier block (system rv64gc, pkg requires rv64gcv)" \
  "$ps17" "$kw17" "$hw17" "" "block"

# ── Test 18: RISC-V CPU tier pass (system rv64gcv, pkg requires rv64gc) ──────
ps18="${KW_TMP}/ps18.pacscript"
hw18="${KW_TMP}/hw18.conf"
kw18="${KW_TMP}/kw18.yml"
_kw_pacscript "$ps18" 'KCPU_MIN="riscv64-rv64gc"'
_kw_yml "$kw18" "stable, testing, unstable"
cp "$kw18" "${KW_TMP}/keywords.yml"
_kw_hw "$hw18" "riscv64-rv64gcv" "gpu-img-bxm"
_kw_run "RISC-V CPU tier pass (system rv64gcv, pkg requires rv64gc)" \
  "$ps18" "$kw18" "$hw18" "" "pass"

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
