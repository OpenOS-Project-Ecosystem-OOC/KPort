#!/usr/bin/env bash
#
# generate-pacscripts.sh
#
# Reads debian/control + debian/changelog + debian/watch from KDE Neon's
# GitLab packaging repos and produces pacscript skeletons in generated/.
#
# Usage:
#   generate-pacscripts.sh [options]
#
# Options:
#   --source <name>     Process only the named source (matches sources.yml name field)
#   --package <pkg>     Process only a single package by GitLab project path
#   --dry-run           Print what would be generated without writing files
#   --force             Overwrite existing files in generated/
#   --no-candidates     Skip writing dep-map-candidates.yml
#   --help
#
# Required env vars (or set in config):
#   KPORT_ROOT          Path to KPort repo root (default: repo root relative to script)
#   GITLAB_TOKEN        GitLab PAT for invent.kde.org (optional — raises rate limits)
#
# Output:
#   generated/<category>/<pkgname>/<pkgname>.pacscript
#   generated/dep-map-candidates.yml   (unmapped dep names, for dep-map.yml curation)

set -uo pipefail

# ── Locate repo root ──────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KPORT_ROOT="${KPORT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

# ── Defaults ──────────────────────────────────────────────────────────────────

DRY_RUN=false
FORCE=false
NO_CANDIDATES=false
FILTER_SOURCE=""
FILTER_PACKAGE=""

SOURCES_FILE="${KPORT_ROOT}/config/sources.yml"
DEP_MAP_FILE="${KPORT_ROOT}/config/dep-map.yml"
DESC_OVERRIDES_FILE="${KPORT_ROOT}/config/desc-overrides.yml"
SOURCE_URL_OVERRIDES_FILE="${KPORT_ROOT}/config/source-url-overrides.yml"
GENERATED_DIR="${KPORT_ROOT}/generated"
CANDIDATES_FILE="${GENERATED_DIR}/dep-map-candidates.yml"
CACHE_FILE="${KPORT_ROOT}/db/sources-cache.json"

GITLAB_API="https://invent.kde.org/api/v4"
GITLAB_TOKEN="${GITLAB_TOKEN:-}"

# ── Logging ───────────────────────────────────────────────────────────────────

info()  { echo "[generate] $*"; }
warn()  { echo "[warn]     $*" >&2; }
error() { echo "[error]    $*" >&2; exit 1; }

# ── Argument parsing ──────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source)    FILTER_SOURCE="$2";  shift 2 ;;
    --package)   FILTER_PACKAGE="$2"; shift 2 ;;
    --dry-run)   DRY_RUN=true;        shift ;;
    --force)     FORCE=true;          shift ;;
    --no-candidates) NO_CANDIDATES=true; shift ;;
    --help)
      sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | grep '^#' | sed 's/^# \?//'
      exit 0 ;;
    *) error "Unknown option: $1" ;;
  esac
done

# ── Dependency checks ─────────────────────────────────────────────────────────

for cmd in curl python3 jq; do
  command -v "$cmd" &>/dev/null || error "Required command not found: $cmd"
done

# ── GitLab API helpers ────────────────────────────────────────────────────────

gl_get() {
  local url="$1"
  local auth_header=""
  [[ -n "$GITLAB_TOKEN" ]] && auth_header="-H \"PRIVATE-TOKEN: ${GITLAB_TOKEN}\""

  local response http_code
  response=$(curl -sf -w "\n%{http_code}" \
    ${GITLAB_TOKEN:+-H "PRIVATE-TOKEN: ${GITLAB_TOKEN}"} \
    "$url" 2>/dev/null) || true
  http_code=$(echo "$response" | tail -1)
  local body
  body=$(echo "$response" | sed '$d')

  if [[ "$http_code" == "200" ]]; then
    echo "$body"
    return 0
  elif [[ "$http_code" == "429" ]]; then
    warn "Rate limited — sleeping 60s"
    sleep 60
    gl_get "$url"
  else
    return 1
  fi
}

# Fetch a raw file from a GitLab project.
# Args: project_id  file_path  ref
gl_raw() {
  local project_id="$1"
  local file_path="$2"
  local ref="${3:-HEAD}"
  local encoded_path
  encoded_path=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$file_path")
  local encoded_ref
  encoded_ref=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$ref")
  gl_get "${GITLAB_API}/projects/${project_id}/repository/files/${encoded_path}/raw?ref=${encoded_ref}"
}

# List all projects in a GitLab group (handles pagination).
# Args: group_id
gl_group_projects() {
  local group_id="$1"
  local page=1
  while true; do
    local batch
    batch=$(gl_get "${GITLAB_API}/groups/${group_id}/projects?per_page=100&page=${page}&include_subgroups=false") || break
    local count
    count=$(echo "$batch" | jq 'length')
    [[ "$count" -eq 0 ]] && break
    echo "$batch" | jq -c '.[]'
    (( page++ ))
  done
}

# Resolve a group path (e.g. "neon/kf6") to its numeric ID.
gl_group_id() {
  local group_path="$1"
  local encoded
  encoded=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$group_path")
  gl_get "${GITLAB_API}/groups/${encoded}" | jq -r '.id // empty'
}

# ── debian/control parser ─────────────────────────────────────────────────────

# Parse a debian/control file and emit key=value pairs to stdout.
# Emitted keys: SOURCE, HOMEPAGE, BUILD_DEPENDS, RUNTIME_DEPENDS, PKG_NAME, PKG_DESC
parse_control() {
  python3 - "$1" << 'PYEOF'
import sys, re

path = sys.argv[1]
try:
    with open(path) as f:
        content = f.read()
except FileNotFoundError:
    sys.exit(1)

# Split into stanzas (blank-line separated)
stanzas = re.split(r'\n\n+', content.strip())

source_stanza = {}
binary_stanzas = []

for stanza in stanzas:
    fields = {}
    current_key = None
    for line in stanza.splitlines():
        if line.startswith(' ') or line.startswith('\t'):
            if current_key:
                fields[current_key] = fields.get(current_key, '') + ' ' + line.strip()
        else:
            m = re.match(r'^([A-Za-z0-9_-]+):\s*(.*)', line)
            if m:
                current_key = m.group(1).lower()
                fields[current_key] = m.group(2).strip()

    if 'source' in fields:
        source_stanza = fields
    elif 'package' in fields:
        binary_stanzas.append(fields)

# Source fields
print(f"SOURCE={source_stanza.get('source', '')}")
print(f"HOMEPAGE={source_stanza.get('homepage', '')}")

# Build-Depends: strip version constraints and whitespace
raw_bd = source_stanza.get('build-depends', '')
deps = []
for dep in raw_bd.split(','):
    dep = dep.strip()
    dep = re.sub(r'\s*\([^)]*\)', '', dep)  # strip (>= 1.0) etc.
    dep = re.sub(r'\s*\[[^\]]*\]', '', dep) # strip [arch] qualifiers
    dep = dep.strip().strip(',').strip()
    dep = dep.split('|')[0].strip()         # take first alternative
    if dep:
        deps.append(dep)
print(f"BUILD_DEPENDS={' '.join(deps)}")

# Find the primary binary package.
# Skip sub-package stanzas whose name suffix or description prefix indicates
# they are not the main installable binary (dev headers, docs, data-only,
# CLI tools, transitional dummies, etc.).
_SUB_PKG_SUFFIXES = ('-dev', '-doc', '-docs', '-data', '-dbg', '-debug',
                     '-bin', '-tools', '-cli', '-common', '-runtime',
                     '-examples', '-demos')
_SUB_DESC_PREFIXES = ('data files for', 'runtime files for', 'documentation for',
                      'development files for', 'debug symbols for',
                      'command line tool for', 'commandline tool for',
                      'dummy transitional', 'transitional dummy',
                      'transitional package', 'arch independent files')

primary = None
for b in binary_stanzas:
    name = b.get('package', '')
    desc = b.get('description', '').lower()
    # Skip by name suffix
    if any(name.endswith(s) for s in _SUB_PKG_SUFFIXES):
        continue
    # Skip by description prefix (catches merged packages where the first
    # stanza is a data/runtime sub-package)
    if any(desc.startswith(p) for p in _SUB_DESC_PREFIXES):
        continue
    if 'transitional' in desc or 'dummy' in desc:
        continue
    if primary is None:
        primary = b

_used_fallback = False
if primary is None and binary_stanzas:
    primary = binary_stanzas[0]
    _used_fallback = True

if primary:
    pkg_name = primary.get('package', '')
    # Description field: first line is the synopsis, rest is long desc.
    # The field value has continuation lines joined with spaces by our parser,
    # so split on ' . ' (the Debian paragraph separator) and take the first part.
    raw_desc = primary.get('description', '')

    # When the fallback stanza was selected (all stanzas were sub-packages),
    # the synopsis is often "data files for X" or similar.  In that case,
    # skip the synopsis and use the first sentence of the long description.
    #
    # The parser joins all continuation lines with spaces, so the field looks like:
    #   "data files for pkg RealDesc first sentence. . Second paragraph."
    # The Debian paragraph separator ". " becomes " . " in the joined string.
    # The synopsis has no trailing period — the long desc starts at the first
    # uppercase word that follows the package-name token(s) after the prefix.
    if _used_fallback:
        parts = raw_desc.split(' . ')
        synopsis_chunk = parts[0].strip()  # may include long-desc first sentence
        if any(synopsis_chunk.lower().startswith(p) for p in _SUB_DESC_PREFIXES):
            # Strategy 1: find ". Capital" boundary inside the chunk (synopsis ends with period)
            m = re.search(r'\.\s+([A-Z])', synopsis_chunk)
            if m:
                raw_desc = synopsis_chunk[m.start(1):]
            else:
                # Strategy 2: strip the matched prefix and the package-name token(s)
                # that follow it, then use the remainder as the description.
                # The prefix is all-lowercase; after it comes the pkg name (one or
                # more hyphenated/lowercase tokens), then the real description which
                # starts with an uppercase letter.
                matched_prefix = next(p for p in _SUB_DESC_PREFIXES
                                      if synopsis_chunk.lower().startswith(p))
                after_prefix = synopsis_chunk[len(matched_prefix):].strip()
                # Skip pkg-name tokens (no uppercase start) to reach the description
                words = after_prefix.split()
                found = False
                for i, w in enumerate(words):
                    if w[0].isupper():
                        raw_desc = ' '.join(words[i:])
                        found = True
                        break
                # Strategy 3: fall back to parts[1] if available
                if not found and len(parts) > 1:
                    raw_desc = parts[1].strip()

    # Use the first sentence (up to first full stop) as the synopsis
    first_sentence = re.split(r'\.\s', raw_desc)[0].strip()
    # If still too long, truncate at word boundary before 80 chars
    if len(first_sentence) > 80:
        first_sentence = first_sentence[:80].rsplit(' ', 1)[0].rstrip()
    pkg_desc = first_sentence
    print(f"PKG_NAME={pkg_name}")
    print(f"PKG_DESC={pkg_desc}")

    # Runtime Depends: strip substitution variables (${shlibs:Depends} etc.)
    # and version constraints, keep only named package deps.
    raw_rd = primary.get('depends', '')
    rdeps = []
    for dep in raw_rd.split(','):
        dep = dep.strip()
        # Drop Debian substitution variables entirely
        if dep.startswith('${'):
            continue
        dep = re.sub(r'\s*\([^)]*\)', '', dep)  # strip version constraints
        dep = re.sub(r'\s*\[[^\]]*\]', '', dep) # strip [arch] qualifiers
        dep = dep.strip().strip(',').strip()
        dep = dep.split('|')[0].strip()          # first alternative only
        if dep:
            rdeps.append(dep)
    print(f"RUNTIME_DEPENDS={' '.join(rdeps)}")
PYEOF
}

# Parse debian/changelog first line to extract upstream version.
# Input: raw changelog text on stdin
# Output: version string (e.g. "6.26.0")
parse_version() {
  # Args: $1 = first line of debian/changelog only (not the full file)
  python3 - "$1" << 'PYEOF'
import sys, re
# First line of changelog: "pkgname (epoch:upstream-debian) suite; urgency=..."
line = sys.argv[1].strip() if len(sys.argv) > 1 else ''
m = re.match(r'^\S+\s+\((?:\d+:)?([^)]+)\)', line)
if m:
    ver = m.group(1).strip()
    ver = re.split(r'[-~]', ver)[0]
    print(ver)
PYEOF
}

# Parse debian/watch to extract the KDE download URL pattern.
# Input: raw watch file text on stdin
# Output: source URL template with $pkgver placeholder
parse_watch_url() {
  # Args: $1 = raw watch file text (passed via stdin to avoid ARG_MAX limits)
  echo "$1" | python3 - << 'PYEOF'
import sys, re
content = sys.stdin.read()
for line in content.splitlines():
    line = line.strip()
    if not line or line.startswith('version=') or line.startswith('#'):
        continue
    # Strip opts=... prefix
    line = re.sub(r'^opts=[^\s]+\s+', '', line)
    # The full watch pattern looks like:
    #   https://download.kde.org/stable/frameworks/([\d\.]*)/karchive-(.*)\.tar\.xz
    # We want to reconstruct a template URL with $pkgver_minor and $pkgver placeholders.
    # Strategy: replace each (...) capture group in order with the right placeholder.
    m = re.match(r'(https://download\.kde\.org/\S+)', line)
    if not m:
        continue
    url = m.group(1)
    # Replace first capture group (version directory) with $pkgver_minor
    url = re.sub(r'\([^)]+\)', '$pkgver_minor', url, count=1)
    # Replace second capture group (full version in filename) with $pkgver
    url = re.sub(r'\([^)]+\)', '$pkgver', url, count=1)
    # Handle uscan @PACKAGE@ / @ANY_VERSION@ / @ARCHIVE_EXT@ macros
    url = re.sub(r'@PACKAGE@',      '$_pkgname', url)
    url = re.sub(r'@ANY_VERSION@',  '-$pkgver',  url)
    url = re.sub(r'@ARCHIVE_EXT@',  '.tar.xz',   url)
    # Strip any trailing regex anchors
    url = re.sub(r'\\\..*$', '.tar.xz', url)
    print(url)
    break
PYEOF
}

# ── dep-map loader ────────────────────────────────────────────────────────────

# Load dep_map from config/dep-map.yml into an associative array.
# Also populates DEP_MAP_KEYS array for iteration.
declare -A DEP_MAP
declare -a DEP_MAP_KEYS
declare -a UNMAPPED_DEPS=()   # accumulated across all packages

load_dep_map() {
  local map_file="$1"
  [[ -f "$map_file" ]] || error "dep-map file not found: $map_file"

  while IFS= read -r line; do
    # Skip comments and blank lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue
    # Skip the dep_map: header
    [[ "$line" =~ ^dep_map: ]] && continue
    # Parse "  key: value" or "  \"key\": value" — strip leading spaces, quotes
    # Quoted keys (e.g. "python3:any") are matched by the first branch.
    if [[ "$line" =~ ^[[:space:]]+\"([^\"]+)\":[[:space:]]+\"?([^\"]+)\"?$ ]]; then
      local key="${BASH_REMATCH[1]}"
      local val="${BASH_REMATCH[2]// /}"
      DEP_MAP["$key"]="$val"
      DEP_MAP_KEYS+=("$key")
    elif [[ "$line" =~ ^[[:space:]]+([^:]+):[[:space:]]+\"?([^\"]+)\"?$ ]]; then
      local key="${BASH_REMATCH[1]// /}"
      local val="${BASH_REMATCH[2]// /}"
      DEP_MAP["$key"]="$val"
      DEP_MAP_KEYS+=("$key")
    fi
  done < "$map_file"
  info "Loaded ${#DEP_MAP[@]} dep-map entries"
}

# Load desc-overrides.yml into the DESC_OVERRIDES associative array.
declare -A DESC_OVERRIDES=()
load_desc_overrides() {
  local file="$1"
  [[ -f "$file" ]] || return 0   # optional file — silently skip if absent
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue
    [[ "$line" =~ ^desc_overrides: ]] && continue
    if [[ "$line" =~ ^[[:space:]]+([^:]+):[[:space:]]+\"(.+)\"$ ]]; then
      DESC_OVERRIDES["${BASH_REMATCH[1]// /}"]="${BASH_REMATCH[2]}"
    fi
  done < "$file"
}

# Load source-url-overrides.yml into SOURCE_URL_OVERRIDES associative array.
# Uses Python to parse so that URL values containing $ are not misinterpreted
# by the bash regex engine.  Emits "key TAB val" lines; bash reads them with
# IFS=$'\t'.
declare -A SOURCE_URL_OVERRIDES=()
load_source_url_overrides() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  while IFS=$'\t' read -r key val; do
    [[ -n "$key" ]] && SOURCE_URL_OVERRIDES["$key"]="$val"
  done < <(python3 - "$file" << 'PYEOF'
import sys, re
with open(sys.argv[1]) as f:
    for line in f:
        m = re.match(r'^\s+([^:#][^:]*?):\s+"(.+)"\s*$', line)
        if m:
            print(m.group(1).strip() + "\t" + m.group(2))
PYEOF
  )
}

# Translate a single Debian dep name to a KPort dep name.
# Outputs the translated name, or the original with a warning if unmapped.
# Sets UNMAPPED flag if the dep was not in the map.
translate_dep() {
  local debian_name="$1"
  local mapped="${DEP_MAP[$debian_name]:-}"

  if [[ -z "$mapped" ]]; then
    warn "  unmapped dep: ${debian_name}"
    UNMAPPED_DEPS+=("$debian_name")
    echo "$debian_name"
    return
  fi

  case "$mapped" in
    "~ignore")   echo "";          return ;;
    "~apt:"*)    echo "${mapped}"; return ;;
    "~virtual:"*)echo "${mapped}"; return ;;
    *)           echo "$mapped";   return ;;
  esac
}

# Translate a space-separated list of Debian dep names.
# Outputs two arrays (by reference): makedepends and runtime_deps
# ~apt: entries go to makedepends only (they're build tools or system libs)
# ~ignore entries are dropped
# KPort package names go to makedepends
translate_build_depends() {
  local -n _makedepends="$1"
  local raw_deps="$2"

  for dep in $raw_deps; do
    [[ -z "$dep" ]] && continue
    local translated
    translated=$(translate_dep "$dep")
    [[ -z "$translated" ]] && continue
    _makedepends+=("$translated")
  done
}

# ── Category / tier inference ─────────────────────────────────────────────────

# Infer KPort category from source group path and package name.
# Args: group_path (e.g. "neon/kf6")  category_hint (from sources.yml)
infer_category() {
  local group_path="$1"
  local category_hint="$2"
  echo "$category_hint"
}

# Derive the invent.kde.org project path from a Homepage URL.
# Handles the common patterns:
#   https://projects.kde.org/projects/…/<ns>/<repo>  → <ns>/<repo>  (last two segments)
#   https://invent.kde.org/<ns>/<repo>               → <ns>/<repo>
# Returns empty string if the URL doesn't match a known pattern.
#
# Namespace aliases: some projects.kde.org namespaces differ from invent.kde.org.
declare -A _KDE_NS_ALIASES=(
  [kdesupport]="frameworks"
  [kde/frameworks]="frameworks"
  [kde/pim]="pim"
  [kde/workspace]="plasma"
)
# Some projects.kde.org paths use a different repo name than invent.kde.org.
# Map "namespace/old-repo-name" → "namespace/new-repo-name".
declare -A _KDE_REPO_ALIASES=(
  ["pim/kcalcore"]="frameworks/kcalendarcore"
)
_homepage_to_invent_path() {
  local homepage="$1"
  local path=""
  # projects.kde.org/projects/... — take the last two path segments
  if [[ "$homepage" =~ projects\.kde\.org/projects/(.+) ]]; then
    local tail="${BASH_REMATCH[1]%/}"   # strip trailing slash
    # Extract last two slash-separated segments
    local repo ns
    repo="${tail##*/}"
    ns="${tail%/*}"
    ns="${ns##*/}"
    # Apply multi-segment namespace aliases (e.g. kde/frameworks → frameworks)
    local full_ns="${tail%/*}"
    for alias_key in "${!_KDE_NS_ALIASES[@]}"; do
      if [[ "$full_ns" == "$alias_key" ]]; then
        ns="${_KDE_NS_ALIASES[$alias_key]}"
        break
      fi
    done
    if [[ -n "$ns" && -n "$repo" ]]; then
      path="${ns}/${repo}"
      # Apply repo-level aliases (e.g. pim/kcalcore → frameworks/kcalendarcore)
      path="${_KDE_REPO_ALIASES[$path]:-$path}"
    fi
  # invent.kde.org/<ns>/<repo>
  elif [[ "$homepage" =~ invent\.kde\.org/([^/]+/[^/?#]+) ]]; then
    path="${BASH_REMATCH[1]%/}"
  # Short-form projects.kde.org/<repo> (no /projects/ prefix) — old-style URLs.
  # These are always KDE Frameworks repos; map to frameworks/<repo>.
  elif [[ "$homepage" =~ projects\.kde\.org/([^/?#]+)$ ]]; then
    path="frameworks/${BASH_REMATCH[1]}"
  # api.kde.org/frameworks/<repo>/... — KDE API docs URL; extract repo name.
  elif [[ "$homepage" =~ api\.kde\.org/frameworks/([^/?#/]+) ]]; then
    path="frameworks/${BASH_REMATCH[1]}"
  # cgit.kde.org/<repo>.git — old cgit URL; strip .git suffix.
  elif [[ "$homepage" =~ cgit\.kde\.org/([^/?#]+)\.git ]]; then
    path="frameworks/${BASH_REMATCH[1]}"
  fi
  echo "$path"
}

# Fetch metainfo.yaml from the upstream KDE repo on invent.kde.org.
# Prints two lines:  METAINFO_DESC=<value>  and  METAINFO_TIER=<value>
# Prints nothing (silently) if the file cannot be fetched.
fetch_metainfo() {
  local homepage="$1"
  local invent_path
  invent_path=$(_homepage_to_invent_path "$homepage")
  [[ -z "$invent_path" ]] && return 0

  local encoded_path
  encoded_path=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$invent_path")

  local raw
  # Use -L to follow redirects (some KDE repos redirect to a canonical project ID URL)
  raw=$(curl -sfL "${GITLAB_API}/projects/${encoded_path}/repository/files/metainfo.yaml/raw?ref=master" \
    ${GITLAB_TOKEN:+-H "PRIVATE-TOKEN: ${GITLAB_TOKEN}"} 2>/dev/null) || return 0
  [[ -z "$raw" ]] && return 0

  # Parse description and tier from metainfo.yaml.
  # Use 'subgroup' (e.g. "Tier 3") rather than 'tier' (numeric) because a handful
  # of KDE repos have an off-by-one in the numeric field while subgroup is correct.
  local desc tier
  desc=$(echo "$raw" | python3 -c "
import sys, re
for line in sys.stdin:
    m = re.match(r'^description:\s*(.+)', line)
    if m:
        print(m.group(1).strip().strip('\"'))
        break
" 2>/dev/null)
  tier=$(echo "$raw" | python3 -c "
import sys, re
for line in sys.stdin:
    m = re.match(r'^\s*subgroup:\s*Tier\s*(\d+)', line)
    if m:
        print(m.group(1))
        break
" 2>/dev/null)

  [[ -n "$desc" ]] && echo "METAINFO_DESC=${desc}"
  [[ -n "$tier" ]] && echo "METAINFO_TIER=${tier}"
}

# Infer KDE Frameworks tier.
# Uses metainfo tier value when available; falls back to a heuristic based on
# the count of kf6- build-deps.
infer_frameworks_tier() {
  local build_depends="$1"
  local metainfo_tier="$2"

  if [[ -n "$metainfo_tier" && "$metainfo_tier" =~ ^[1-4]$ ]]; then
    echo "tier${metainfo_tier}"
    return
  fi

  # Fallback heuristic: count kf6- build-deps
  local kf6_count
  kf6_count=$(echo "$build_depends" | tr ' ' '\n' | grep -c '^kf6-' 2>/dev/null || echo 0)
  if [[ "$kf6_count" -eq 0 ]]; then
    echo "tier1"
  elif [[ "$kf6_count" -le 3 ]]; then
    echo "tier2"
  elif [[ "$kf6_count" -le 8 ]]; then
    echo "tier3"
  else
    echo "tier4"
  fi
}

# Infer GPU minimum tier from package name and build-deps.
infer_gpu_min() {
  local pkg_name="$1"
  local build_depends="$2"
  case "$pkg_name" in
    kwin|kwayland*|plasma-*) echo "gpu-gl4" ;;
    *)
      if echo "$build_depends" | grep -q 'vulkan\|libvulkan'; then
        echo "gpu-vk12"
      elif echo "$build_depends" | grep -q 'libgl\|libegl\|libepoxy\|libgbm'; then
        echo "gpu-gl2"
      else
        echo "gpu-sw"
      fi
      ;;
  esac
}

# Infer relevant USE flags from build-deps and package name.
# Outputs a bash array literal.
infer_use_flags() {
  local pkg_name="$1"
  local build_depends="$2"
  local flags=()

  echo "$build_depends" | grep -q 'wayland'   && flags+=('"+wayland"')
  echo "$build_depends" | grep -q 'libx11\|xcb' && flags+=('"+x11"')
  echo "$build_depends" | grep -q 'vulkan'    && flags+=('"-vulkan"')
  echo "$build_depends" | grep -q 'pipewire'  && flags+=('"-pipewire"')
  echo "$build_depends" | grep -q 'doxygen\|qdoc' && flags+=('"-docs"')
  flags+=('"-test"')

  if [[ ${#flags[@]} -gt 0 ]]; then
    printf '%s\n' "${flags[@]}"
  fi
}

# ── KDE download URL builder ───────────────────────────────────────────────────

# Build the KDE download source URL from watch file pattern + version.
# Falls back to a sensible default if watch parsing fails.
build_source_url() {
  local watch_url="$1"
  local pkg_name="$2"
  local version="$3"
  local category="$4"

  # Minor version = first two components (e.g. "6.26.0" → "6.26")
  local minor_ver
  minor_ver=$(echo "$version" | cut -d. -f1-2)

  # Check source-url-overrides.yml first — takes precedence over watch file.
  # Needed for packages whose debian/watch points to the wrong tarball entirely.
  local override_url="${SOURCE_URL_OVERRIDES[$pkg_name]:-}"
  if [[ -n "$override_url" ]]; then
    override_url="${override_url/\$pkgver_minor/$minor_ver}"
    override_url="${override_url/\$pkgver/$version}"
    override_url="${override_url/\$_pkgname/$pkg_name}"
    echo "$override_url"
    return
  fi

  if [[ -n "$watch_url" ]]; then
    local url="$watch_url"
    url="${url/\$pkgver_minor/$minor_ver}"
    url="${url/\$pkgver/$version}"
    url="${url/\$_pkgname/$pkg_name}"
    echo "$url"
    return
  fi

  # Fallback URL patterns by category
  case "$category" in
    frameworks*)
      echo "https://download.kde.org/stable/frameworks/${minor_ver}/${pkg_name}-${version}.tar.xz"
      ;;
    plasma*)
      echo "https://download.kde.org/stable/plasma/${version}/${pkg_name}-${version}.tar.xz"
      ;;
    gear*)
      echo "https://download.kde.org/stable/release-service/${version}/src/${pkg_name}-${version}.tar.xz"
      ;;
    *)
      echo "https://download.kde.org/stable/${pkg_name}/${version}/${pkg_name}-${version}.tar.xz"
      ;;
  esac
}

# ── Pacscript renderer ────────────────────────────────────────────────────────

render_pacscript() {
  local pkg_name="$1"
  local version="$2"
  local pkg_desc="$3"
  local homepage="$4"
  local source_url="$5"
  local category="$6"
  local gpu_min="$7"
  local slot="$8"
  local makedepends_file="$9"
  local use_flags_file="${10}"
  local depends_file="${11:-}"

  local makedepends_arr=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && makedepends_arr+=("$line")
  done < "$makedepends_file"

  local use_flags_arr=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && use_flags_arr+=("$line")
  done < "$use_flags_file"

  local depends_arr=()
  if [[ -n "$depends_file" && -f "$depends_file" ]]; then
    while IFS= read -r line; do
      [[ -n "$line" ]] && depends_arr+=("$line")
    done < "$depends_file"
  fi

  # Determine KSLOT from slot arg
  local kslot="${slot:-0}"

  # Build depends block (runtime)
  local depends_block=""
  local depends_comment=""
  if [[ ${#depends_arr[@]} -gt 0 ]]; then
    for dep in "${depends_arr[@]}"; do
      case "$dep" in
        "~apt:"*) depends_block+="  \"${dep#\~apt:}\"\n" ;;
        "~virtual:"*|"~ignore") ;;
        *) depends_block+="  \"${dep}\"\n" ;;
      esac
    done
  else
    depends_comment="  # No named runtime deps found in debian/control (only \${shlibs:Depends})."$'\n'
    depends_comment+="  # Populate after a test build by inspecting ldd output or dpkg -I."$'\n'
  fi

  # Build makedepends block
  local makedepends_block=""
  for dep in "${makedepends_arr[@]}"; do
    case "$dep" in
      "~apt:"*) makedepends_block+="  \"${dep#\~apt:}\"\n" ;;
      "~virtual:"*|"~ignore") ;;
      *) makedepends_block+="  \"${dep}\"\n" ;;
    esac
  done

  # Build KUSE block
  local kuse_block=""
  for flag in "${use_flags_arr[@]}"; do
    kuse_block+="  ${flag}\n"
  done

  # Infer license from category
  local license
  case "$category" in
    frameworks*) license='"LGPL-2.0-or-later"' ;;
    plasma*)     license='"GPL-2.0-or-later" "LGPL-2.0-or-later"' ;;
    *)           license='"GPL-2.0-or-later"' ;;
  esac

  cat << PACSCRIPT
#!/usr/bin/env bash
# KPort pacscript — ${category}/${pkg_name}
# Auto-generated by generate-pacscripts.sh — review before promoting to packages/
#
# ${pkg_desc}

# ── Standard Pacstall variables ───────────────────────────────────────────────

pkgname="${pkg_name}"
pkgver="${version}"
pkgdesc="$(echo "$pkg_desc" | sed 's/"/\\"/g')"
# Fall back to invent.kde.org canonical URL when no homepage is set
url="${homepage:-https://invent.kde.org/frameworks/${pkg_name#kf6-}}"
license=(${license})

source=(
  "${source_url}"
)
sha256sums=(
  "SKIP"   # replace with actual sha256 after download
)

depends=(
$(printf '%b' "${depends_comment}${depends_block}")
)

makedepends=(
$(printf '%b' "$makedepends_block")
)

# ── KPort extensions ──────────────────────────────────────────────────────────

KSLOT="${kslot}"
KCATEGORY="${category}"
KNEON_CHANNEL="unstable"
KCPU_MIN="x86-64-v1"
KGPU_MIN="${gpu_min}"

KUSE=(
$(printf '%b' "$kuse_block")
)

# ── Build ─────────────────────────────────────────────────────────────────────

build() {
  _kport_lib="\${KPORT_LIB_DIR:-/usr/lib/kport}/use-helpers.sh"
  [[ -f "\$_kport_lib" ]] && source "\$_kport_lib"

  cmake -B build -G Ninja \\
    -DCMAKE_BUILD_TYPE=Release \\
    -DCMAKE_INSTALL_PREFIX=/usr \\
    -DBUILD_TESTING=\$(use_flag test ON OFF 2>/dev/null || echo OFF) \\
    -DBUILD_QCH=\$(use_flag docs ON OFF 2>/dev/null || echo OFF)

  cmake --build build --parallel "\$(nproc)"
}

# ── Package ───────────────────────────────────────────────────────────────────

package() {
  DESTDIR="\$pkgdir" cmake --install build
}
PACSCRIPT
}

# ── Per-project processor ─────────────────────────────────────────────────────

# Process a single GitLab project and write its pacscript skeleton.
# Args: project_json  category  branch
process_project() {
  local project_json="$1"
  local category="$2"
  local branch="$3"

  local project_id project_path project_name
  project_id=$(echo "$project_json"   | jq -r '.id')
  project_path=$(echo "$project_json" | jq -r '.path_with_namespace')
  project_name=$(echo "$project_json" | jq -r '.path')

  # Apply package filter if set
  if [[ -n "$FILTER_PACKAGE" && "$project_path" != *"$FILTER_PACKAGE"* ]]; then
    return 0
  fi

  info "Processing ${project_path}"

  # Fetch debian/control
  local control_raw
  control_raw=$(gl_raw "$project_id" "debian/control" "$branch") || {
    warn "  No debian/control found — skipping"
    return 0
  }

  # Write to temp file for parser
  local tmp_control
  tmp_control=$(mktemp)
  echo "$control_raw" > "$tmp_control"

  # Parse control
  local parsed
  parsed=$(parse_control "$tmp_control")
  rm -f "$tmp_control"

  [[ -z "$parsed" ]] && { warn "  Failed to parse debian/control — skipping"; return 0; }

  local source_name homepage build_depends runtime_depends pkg_name pkg_desc
  source_name=$(echo "$parsed"       | grep '^SOURCE='          | cut -d= -f2-)
  homepage=$(echo "$parsed"          | grep '^HOMEPAGE='        | cut -d= -f2-)
  build_depends=$(echo "$parsed"     | grep '^BUILD_DEPENDS='   | cut -d= -f2-)
  runtime_depends=$(echo "$parsed"   | grep '^RUNTIME_DEPENDS=' | cut -d= -f2-)
  pkg_name=$(echo "$parsed"          | grep '^PKG_NAME='        | cut -d= -f2-)
  pkg_desc=$(echo "$parsed"          | grep '^PKG_DESC='        | cut -d= -f2-)

  [[ -z "$pkg_name" ]] && pkg_name="$project_name"
  [[ -z "$pkg_desc" ]] && pkg_desc="KDE package: ${pkg_name}"

  # Fetch metainfo.yaml from upstream KDE repo for authoritative description + tier.
  # When the Neon control file has no Homepage field, derive the invent.kde.org
  # path directly from the package name for known namespaces.
  local metainfo_homepage="$homepage"
  if [[ -z "$metainfo_homepage" && "$category" == "frameworks" ]]; then
    # Strip kf6- prefix and common suffixes to get the upstream repo name
    local repo_name="${pkg_name#kf6-}"
    repo_name="${repo_name%-qt}"   # e.g. bluez-qt → bluez (wrong; keep as-is)
    metainfo_homepage="https://invent.kde.org/frameworks/${pkg_name#kf6-}"
  fi
  local metainfo metainfo_desc metainfo_tier
  metainfo=$(fetch_metainfo "$metainfo_homepage")
  metainfo_desc=$(echo "$metainfo" | grep '^METAINFO_DESC=' | cut -d= -f2-)
  metainfo_tier=$(echo "$metainfo" | grep '^METAINFO_TIER=' | cut -d= -f2-)

  # Apply description in priority order:
  #   1. desc-overrides.yml (explicit manual override)
  #   2. upstream metainfo.yaml description
  #   3. debian/control synopsis (already in pkg_desc from parse_control)
  local override_desc="${DESC_OVERRIDES[$pkg_name]:-}"
  if [[ -n "$override_desc" ]]; then
    pkg_desc="$override_desc"
  elif [[ -n "$metainfo_desc" ]]; then
    pkg_desc="$metainfo_desc"
  fi

  # Fetch debian/changelog for version
  local changelog_raw version
  # Fetch only the first line — full changelogs can be 100s of KB and exceed
  # shell argument limits when passed to parse_version.
  changelog_raw=$(gl_raw "$project_id" "debian/changelog" "$branch" | head -1) || true
  version=$(parse_version "$changelog_raw")
  [[ -z "$version" ]] && version="0.0.0"

  # Fetch debian/watch for source URL
  local watch_raw watch_url
  watch_raw=$(gl_raw "$project_id" "debian/watch" "$branch") || true
  watch_url=$(parse_watch_url "$watch_raw")

  # Infer metadata
  local tier gpu_min slot
  if [[ "$category" == "frameworks" ]]; then
    tier=$(infer_frameworks_tier "$build_depends" "$metainfo_tier")
    category="frameworks/${tier}"
    slot="6"
  elif [[ "$category" == "plasma" ]]; then
    slot="6"
  else
    slot="0"
  fi

  gpu_min=$(infer_gpu_min "$pkg_name" "$build_depends")
  local source_url
  source_url=$(build_source_url "$watch_url" "$pkg_name" "$version" "$category")

  # Translate build-depends
  local tmp_makedepends
  tmp_makedepends=$(mktemp)
  local makedepends=()
  translate_build_depends makedepends "$build_depends"
  printf '%s\n' "${makedepends[@]}" > "$tmp_makedepends"

  # Translate runtime depends
  local tmp_depends
  tmp_depends=$(mktemp)
  local rundeps=()
  translate_build_depends rundeps "$runtime_depends"
  printf '%s\n' "${rundeps[@]}" > "$tmp_depends"

  # Infer USE flags
  local tmp_useflags
  tmp_useflags=$(mktemp)
  infer_use_flags "$pkg_name" "$build_depends" > "$tmp_useflags"

  # Determine output path
  local out_dir="${GENERATED_DIR}/${category}/${pkg_name}"
  local out_file="${out_dir}/${pkg_name}.pacscript"

  if [[ -f "$out_file" && "$FORCE" != "true" ]]; then
    info "  skip  ${out_file} (exists, use --force to overwrite)"
    rm -f "$tmp_makedepends" "$tmp_depends" "$tmp_useflags"
    return 0
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    info "  [dry-run] would write ${out_file}"
    rm -f "$tmp_makedepends" "$tmp_depends" "$tmp_useflags"
    return 0
  fi

  mkdir -p "$out_dir"
  render_pacscript \
    "$pkg_name" "$version" "$pkg_desc" "$homepage" \
    "$source_url" "$category" "$gpu_min" "$slot" \
    "$tmp_makedepends" "$tmp_useflags" "$tmp_depends" \
    > "$out_file"

  info "  wrote ${out_file}"
  rm -f "$tmp_makedepends" "$tmp_depends" "$tmp_useflags"
}

# ── Cache-aware project iterator ─────────────────────────────────────────────

# Emit project JSON objects for a group, preferring the sources cache.
# Falls back to live API enumeration if cache is absent or group not cached.
# Args: group_path
projects_for_group() {
  local group_path="$1"

  if [[ -f "$CACHE_FILE" ]]; then
    local cached_projects
    cached_projects=$(jq -c \
      --arg g "$group_path" \
      '.sources[$g].projects // [] | .[]' \
      "$CACHE_FILE" 2>/dev/null)
    if [[ -n "$cached_projects" ]]; then
      echo "$cached_projects"
      return 0
    fi
    warn "Group ${group_path} not in cache — falling back to live API"
  fi

  # Live fallback: resolve group ID then paginate
  local group_id
  group_id=$(gl_group_id "$group_path") || {
    warn "Could not resolve group ID for ${group_path}"
    return 1
  }
  gl_group_projects "$group_id"
}

# ── sources.yml parser ────────────────────────────────────────────────────────

# Parse sources.yml and emit one line per enabled gitlab source:
#   name|base_url|group|category|branch
parse_sources() {
  python3 - "$SOURCES_FILE" << 'PYEOF'
import sys, re

path = sys.argv[1]
with open(path) as f:
    content = f.read()

lines = content.splitlines()
in_sources = False
in_entry   = False

entry = {}

def emit(e):
    if e.get('type') == 'gitlab' and e.get('enabled', 'true') != 'false':
        name     = e.get('name', '')
        base_url = e.get('base_url', 'https://invent.kde.org')
        group    = e.get('group', '')
        category = e.get('category', '')
        branch   = e.get('branch', 'Neon/unstable')
        print(f"{name}|{base_url}|{group}|{category}|{branch}")

for line in lines:
    stripped = line.strip()
    if not stripped or stripped.startswith('#'):
        continue

    if stripped == 'sources:':
        in_sources = True
        continue

    if not in_sources:
        continue

    # New list entry
    if re.match(r'^\s*-\s+name:', line):
        if in_entry:
            emit(entry)
        entry = {'name': re.sub(r'^\s*-\s+name:\s*', '', line).strip().strip('"\'') }
        in_entry = True
        continue

    if in_entry:
        m = re.match(r'^\s+(type|base_url|group|category|branch|enabled):\s*(.+)', line)
        if m:
            entry[m.group(1)] = m.group(2).strip().strip('"\'')

if in_entry:
    emit(entry)
PYEOF
}

# ── Candidates file writer ────────────────────────────────────────────────────

write_candidates() {
  [[ "$NO_CANDIDATES" == "true" ]] && return 0
  [[ ${#UNMAPPED_DEPS[@]} -eq 0 ]] && return 0

  # Deduplicate
  local -A seen
  local unique=()
  for dep in "${UNMAPPED_DEPS[@]}"; do
    [[ -z "${seen[$dep]:-}" ]] && unique+=("$dep") && seen["$dep"]=1
  done

  if [[ "$DRY_RUN" == "true" ]]; then
    info "Would write ${#unique[@]} unmapped dep(s) to ${CANDIDATES_FILE}"
    return 0
  fi

  mkdir -p "$(dirname "$CANDIDATES_FILE")"
  {
    echo "# dep-map-candidates.yml"
    echo "# Auto-generated by generate-pacscripts.sh — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "#"
    echo "# These Debian dep names were not found in config/dep-map.yml."
    echo "# For each entry, determine whether it should be:"
    echo "#   - A KPort package name (add to dep_map as-is or with a new name)"
    echo "#   - Satisfied by apt (~apt:<name>)"
    echo "#   - A virtual package (~virtual:<name>)"
    echo "#   - Ignored (~ignore)"
    echo "# Then add the mapping to config/dep-map.yml and re-run the generator."
    echo ""
    echo "candidates:"
    for dep in "${unique[@]}"; do
      echo "  - debian_name: \"${dep}\""
      echo "    kport_name:  \"\"   # TODO"
    done
  } > "$CANDIDATES_FILE"

  info "Wrote ${#unique[@]} unmapped dep(s) to ${CANDIDATES_FILE}"
}

# ── Main ──────────────────────────────────────────────────────────────────────

main() {
  [[ "$DRY_RUN"  == "true" ]] && info "Dry run — no files will be written"
  [[ "$FORCE"    == "true" ]] && info "Force mode — existing files will be overwritten"
  [[ -n "$GITLAB_TOKEN"    ]] && info "Using authenticated GitLab API"

  load_dep_map "$DEP_MAP_FILE"
  load_desc_overrides "$DESC_OVERRIDES_FILE"
  load_source_url_overrides "$SOURCE_URL_OVERRIDES_FILE"
  echo ""

  local source_lines
  source_lines=$(parse_sources) || error "Failed to parse ${SOURCES_FILE}"

  local total_sources=0 total_packages=0 total_skipped=0

  while IFS='|' read -r src_name base_url group category branch; do
    [[ -z "$src_name" ]] && continue

    # Apply source filter — matches against name or group path
    if [[ -n "$FILTER_SOURCE" && "$src_name" != *"$FILTER_SOURCE"* && "$group" != *"$FILTER_SOURCE"* ]]; then
      continue
    fi

    # Skip non-package meta sources
    [[ "$category" == "_meta" ]] && continue

    info "════════════════════════════════════════"
    info "Source: ${src_name}"
    info "  group=${group}  category=${category}  branch=${branch}"
    echo ""

    (( total_sources++ )) || true

    # When --package is set, look up the project directly rather than
    # enumerating the entire group (avoids pagination timeout on large groups).
    if [[ -n "$FILTER_PACKAGE" ]]; then
      info "  Direct lookup for: ${FILTER_PACKAGE}"
      local encoded_group
      encoded_group=$(python3 -c \
        "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=''))" \
        "$group")
      local project_json
      # Use exact path match to avoid prefix collisions (e.g. kf6-kactivities
      # matching kf6-kactivities-stats when stats sorts first in results).
      project_json=$(gl_get \
        "${GITLAB_API}/groups/${encoded_group}/projects?search=${FILTER_PACKAGE}" \
        | jq -c --arg pkg "${group}/${FILTER_PACKAGE}" \
            'map(select(.path_with_namespace == $pkg)) | .[0] // empty') || true
      if [[ -n "$project_json" ]]; then
        process_project "$project_json" "$category" "$branch"
        (( total_packages++ )) || true
      else
        warn "  Project not found: ${FILTER_PACKAGE} in group ${group}"
      fi
      continue
    fi

    # Full group enumeration (cache-aware)
    local cache_note=""
    [[ -f "$CACHE_FILE" ]] && cache_note=" (from cache)"
    info "  Enumerating projects${cache_note}"

    while IFS= read -r project_json; do
      [[ -z "$project_json" ]] && continue
      process_project "$project_json" "$category" "$branch"
      (( total_packages++ )) || true
      sleep 0.3
    done < <(projects_for_group "$group")

    echo ""
  done <<< "$source_lines"

  write_candidates

  echo ""
  info "════════════════════════════════════════"
  info "Done"
  info "  Sources processed : ${total_sources}"
  info "  Packages processed: ${total_packages}"
  info "  Unmapped deps     : ${#UNMAPPED_DEPS[@]}"
  [[ "$NO_CANDIDATES" != "true" && ${#UNMAPPED_DEPS[@]} -gt 0 ]] && \
    info "  Candidates file   : ${CANDIDATES_FILE}"
  info "════════════════════════════════════════"
}

main "$@"
