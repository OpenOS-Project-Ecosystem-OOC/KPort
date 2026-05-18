#!/usr/bin/env bash
# kport sync
#
# Pulls updates for all enabled overlay repositories defined in
# config/repositories.yml, and optionally refreshes the sources cache.
#
# Overlays with auto_sync: false are skipped unless --all or --overlay is used.
# Overlays with no url: field are local-only and are always skipped.
#
# Usage: kport sync [options]
#
# Options:
#   --sources      Also refresh db/sources-cache.json via sync-sources.sh
#   --overlay <n>  Sync only the named overlay (substring match on name)
#   --all          Sync all enabled overlays regardless of auto_sync setting
#   --dry-run      Show what would be updated without pulling
#   --help

set -uo pipefail

# ── Parse args ────────────────────────────────────────────────────────────────

SYNC_SOURCES=false
FILTER_OVERLAY=""
SYNC_ALL=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sources)     SYNC_SOURCES=true;      shift ;;
    --overlay)     FILTER_OVERLAY="$2";    shift 2 ;;
    --all)         SYNC_ALL=true;          shift ;;
    --dry-run)     DRY_RUN=true;           shift ;;
    --help|-h)
      sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | grep '^#' | sed 's/^# \?//'
      exit 0 ;;
    -*) kport_die "Unknown option: $1" ;;
    *)  kport_die "Unexpected argument: $1" ;;
  esac
done

# ── Parse repositories.yml ────────────────────────────────────────────────────

# repositories.yml: user config dir first, fall back to repo config/
REPOS_FILE="${KPORT_CONF}/repositories.yml"
[[ -f "$REPOS_FILE" ]] || REPOS_FILE="${KPORT_ROOT}/config/repositories.yml"
[[ -f "$REPOS_FILE" ]] || kport_die "repositories.yml not found (checked ${KPORT_CONF} and ${KPORT_ROOT}/config)"

# Emit: name|url|branch|local_path|auto_sync  (only enabled entries, sorted by priority desc)
parse_repositories() {
  python3 - "$REPOS_FILE" << 'PYEOF'
import sys, re

path = sys.argv[1]
with open(path) as f:
    content = f.read()

lines = content.splitlines()
in_repos = in_entry = False
entries = []
entry = {}

def finish(e):
    if not e:
        return
    if str(e.get('enabled', 'true')).lower() == 'false':
        return
    # local_path: explicit field or derive from name
    local_path = e.get('local_path', '') or 'overlays/' + e.get('name', 'unknown')
    entries.append({
        'name':       e.get('name', ''),
        'url':        e.get('url', ''),
        'branch':     e.get('branch', 'main'),
        'local_path': local_path,
        'priority':   int(e.get('priority', 0)),
        'auto_sync':  str(e.get('auto_sync', 'false')).lower(),
    })

for line in lines:
    stripped = line.strip()
    if not stripped or stripped.startswith('#'):
        continue
    if stripped == 'repositories:':
        in_repos = True; continue
    if not in_repos:
        continue
    if re.match(r'^\s*-\s+name:', line):
        if in_entry: finish(entry)
        entry = {'name': re.sub(r'^\s*-\s+name:\s*', '', line).strip().strip('"\'') }
        in_entry = True; continue
    if in_entry:
        m = re.match(r'^\s+(url|branch|local_path|enabled|priority|auto_sync|description):\s*(.+)', line)
        if m:
            entry[m.group(1)] = m.group(2).strip().strip('"\'')

if in_entry:
    finish(entry)

# Sort by priority descending
for e in sorted(entries, key=lambda x: -x['priority']):
    print("{name}|{url}|{branch}|{local_path}|{auto_sync}".format(**e))
PYEOF
}

# ── Sync overlays ─────────────────────────────────────────────────────────────

ok=0; skipped=0; failed=0

while IFS='|' read -r name url branch local_path auto_sync; do
  [[ -z "$name" ]] && continue

  # --overlay filter: explicit name match takes priority over auto_sync
  if [[ -n "$FILTER_OVERLAY" ]]; then
    if [[ "$name" != *"$FILTER_OVERLAY"* ]]; then
      continue
    fi
  else
    # Skip overlays with auto_sync: false unless --all was passed
    if [[ "$auto_sync" != "true" && "$SYNC_ALL" != "true" ]]; then
      kport_verbose "Skipping ${name} (auto_sync: false — use --all or --overlay ${name})"
      (( skipped++ )) || true
      continue
    fi
  fi

  # Resolve local path: relative to KPORT_ROOT if not absolute
  if [[ "$local_path" != /* ]]; then
    local_path="${KPORT_ROOT}/${local_path:-overlays/${name}}"
  fi

  kport_info "Overlay: ${name}"
  kport_kv "URL"    "${url:-(local)}"
  kport_kv "Branch" "$branch"
  kport_kv "Path"   "$local_path"

  # Local-only overlay (no URL) — nothing to pull
  if [[ -z "$url" ]]; then
    kport_info "  ${C_YELLOW}—${C_RESET} Local overlay, no remote URL"
    (( skipped++ )) || true
    echo ""
    continue
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    if [[ -d "${local_path}/.git" ]]; then
      kport_info "  [dry-run] would pull ${branch} in ${local_path}"
    else
      kport_info "  [dry-run] would clone ${url} → ${local_path} (branch: ${branch})"
    fi
    (( skipped++ )) || true
    echo ""
    continue
  fi

  if [[ -d "${local_path}/.git" ]]; then
    # Existing clone — pull
    kport_verbose "  Pulling..."
    pull_out=$(git -C "$local_path" pull --ff-only origin "$branch" 2>&1)
    pull_rc=$?
    while IFS= read -r l; do kport_verbose "  $l"; done <<< "$pull_out"
    if [[ $pull_rc -eq 0 ]]; then
      if grep -q "Already up to date" <<< "$pull_out"; then
        kport_info "  ${C_GREEN}✔${C_RESET} Already up to date"
      else
        kport_info "  ${C_GREEN}✔${C_RESET} Updated"
      fi
      (( ok++ )) || true
    else
      kport_warn "  Pull failed — try: git -C ${local_path} pull"
      (( failed++ )) || true
    fi
  elif [[ ! -e "$local_path" ]]; then
    # New overlay — clone
    kport_info "  Cloning..."
    mkdir -p "$(dirname "$local_path")"
    clone_out=$(git clone --branch "$branch" --depth 1 "$url" "$local_path" 2>&1)
    clone_rc=$?
    while IFS= read -r l; do kport_verbose "  $l"; done <<< "$clone_out"
    if [[ $clone_rc -eq 0 ]]; then
      kport_info "  ${C_GREEN}✔${C_RESET} Cloned"
      (( ok++ )) || true
    else
      kport_error "  Clone failed: ${clone_out}"
      (( failed++ )) || true
    fi
  else
    kport_warn "  ${local_path} exists but is not a git repo — skipping"
    (( skipped++ )) || true
  fi

  echo ""
done < <(parse_repositories)

# ── Sync sources cache ────────────────────────────────────────────────────────

if [[ "$SYNC_SOURCES" == "true" ]]; then
  kport_header "Refreshing sources cache"
  sync_args=()
  [[ "$DRY_RUN" == "true" ]] && sync_args+=(--dry-run)
  KPORT_ROOT="$KPORT_ROOT" bash "${KPORT_ROOT}/scripts/kport/sync-sources.sh" \
    "${sync_args[@]}" || kport_warn "sync-sources.sh reported errors"
  echo ""
fi

kport_info "Sync complete — updated: ${ok}  skipped: ${skipped}  failed: ${failed}"

# Rebuild search index after sync (unless dry-run)
if [[ "$DRY_RUN" != "true" ]]; then
  source "${KPORT_LIB}/cmd/index.sh" --force 2>/dev/null || true
fi

[[ "$failed" -gt 0 ]] && exit 1 || exit 0
