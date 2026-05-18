#!/usr/bin/env bash
# kport sync
#
# Pulls updates for all enabled overlay repositories defined in
# config/repositories.yml, and optionally refreshes the sources cache.
#
# Usage: kport sync [options]
#
# Options:
#   --sources      Also refresh db/sources-cache.json via sync-sources.sh
#   --overlay <n>  Sync only the named overlay (substring match on name)
#   --dry-run      Show what would be updated without pulling
#   --help

set -uo pipefail

# ── Parse args ────────────────────────────────────────────────────────────────

SYNC_SOURCES=false
FILTER_OVERLAY=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sources)     SYNC_SOURCES=true;      shift ;;
    --overlay)     FILTER_OVERLAY="$2";    shift 2 ;;
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

# Emit: name|url|branch|local_path  (only enabled entries, sorted by priority desc)
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
    print("{name}|{url}|{branch}|{local_path}".format(**e))
PYEOF
}

# ── Sync overlays ─────────────────────────────────────────────────────────────

ok=0; skipped=0; failed=0

while IFS='|' read -r name url branch local_path; do
  [[ -z "$name" ]] && continue

  if [[ -n "$FILTER_OVERLAY" && "$name" != *"$FILTER_OVERLAY"* ]]; then
    continue
  fi

  # Resolve local path: relative to KPORT_ROOT if not absolute
  if [[ "$local_path" != /* ]]; then
    local_path="${KPORT_ROOT}/${local_path:-overlays/${name}}"
  fi

  kport_info "Overlay: ${name}"
  kport_kv "URL"    "$url"
  kport_kv "Branch" "$branch"
  kport_kv "Path"   "$local_path"

  if [[ "$DRY_RUN" == "true" ]]; then
    kport_info "  [dry-run] would pull ${branch}"
    (( skipped++ )) || true
    echo ""
    continue
  fi

  if [[ -d "${local_path}/.git" ]]; then
    # Existing clone — pull
    kport_verbose "  Pulling..."
    if git -C "$local_path" pull --ff-only origin "$branch" 2>&1 \
        | while IFS= read -r l; do kport_verbose "  $l"; done; then
      kport_info "  ${C_GREEN}✔${C_RESET} Updated"
      (( ok++ )) || true
    else
      kport_warn "  Pull failed — try: git -C ${local_path} pull"
      (( failed++ )) || true
    fi
  elif [[ ! -e "$local_path" ]]; then
    # New overlay — clone
    kport_info "  Cloning..."
    mkdir -p "$(dirname "$local_path")"
    if git clone --branch "$branch" --depth 1 "$url" "$local_path" 2>&1 \
        | while IFS= read -r l; do kport_verbose "  $l"; done; then
      kport_info "  ${C_GREEN}✔${C_RESET} Cloned"
      (( ok++ )) || true
    else
      kport_error "  Clone failed"
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
[[ "$failed" -gt 0 ]] && exit 1 || exit 0
