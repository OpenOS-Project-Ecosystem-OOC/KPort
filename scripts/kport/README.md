# KPort scripts

Scripts for generating and managing KPort pacscripts from KDE Neon packaging metadata.

## Prerequisites

### GitLab token (recommended)

`invent.kde.org` is public but unauthenticated requests are rate-limited to
500 req/min. A personal access token raises this significantly and avoids
transient 429 errors during large generation runs.

1. Go to https://invent.kde.org/-/user_settings/personal_access_tokens
2. Create a token with the `read_api` scope
3. Export it before running any script:

```bash
export GITLAB_TOKEN=glpat-xxxxxxxxxxxxxxxxxxxx
```

Or add it to your shell profile / a local `.env` file (never commit it).

---

## Typical workflow

### First run

```bash
# 1. Populate the project cache (do this once, then weekly or on --force)
scripts/kport/sync-sources.sh

# 2. Dry run — see what would be generated without writing anything
scripts/kport/generate-pacscripts.sh --dry-run

# 3. Generate all packages
scripts/kport/generate-pacscripts.sh

# 4. Review unmapped deps and extend dep-map.yml
#    (generated/dep-map-candidates.yml is written automatically)
$EDITOR config/dep-map.yml

# 5. Re-run to pick up the new mappings
scripts/kport/generate-pacscripts.sh --force
```

### Updating after a KDE release

```bash
# Refresh the cache for changed sources only
scripts/kport/sync-sources.sh --source "KDE Frameworks 6"

# Regenerate, overwriting existing skeletons
scripts/kport/generate-pacscripts.sh --source "KDE Frameworks 6" --force
```

### Single package

```bash
scripts/kport/generate-pacscripts.sh --package kf6-karchive
```

---

## generate-pacscripts.sh

Reads `debian/control`, `debian/changelog`, and `debian/watch` from each
project in the enabled sources and writes a pacscript skeleton to
`generated/<category>/<pkgname>/<pkgname>.pacscript`.

```
Usage: generate-pacscripts.sh [options]

Options:
  --source <name>     Process only the named source (substring match on name field)
  --package <pkg>     Process only a single package by GitLab project path
  --dry-run           Print what would be generated without writing files
  --force             Overwrite existing files in generated/
  --no-candidates     Skip writing dep-map-candidates.yml
  --help
```

### What gets generated

| Field | Source |
|---|---|
| `pkgname`, `pkgver` | `debian/changelog` |
| `pkgdesc`, `url` | `debian/control` source stanza |
| `source` URL | `debian/watch` capture groups |
| `depends` | `debian/control` binary stanza `Depends` (named deps only; `${shlibs:Depends}` dropped) |
| `makedepends` | `debian/control` `Build-Depends`, translated via `config/dep-map.yml` |
| `KUSE` | Inferred from build-dep names (wayland, x11, vulkan, pipewire, docs, test) |
| `KGPU_MIN` | Inferred from package name and build-deps |
| `KCATEGORY` | From `config/sources.yml` category field |

### dep-map-candidates.yml

Any dep name not found in `config/dep-map.yml` is written to
`generated/dep-map-candidates.yml` after the run. Each entry has a
`debian_name` and an empty `kport_name` to fill in. Once curated, add the
mapping to `config/dep-map.yml` and re-run with `--force`.

Special values in `dep-map.yml`:

| Value | Meaning |
|---|---|
| `~apt:<name>` | Satisfied by the system apt package, not a KPort package |
| `~virtual:<name>` | Satisfied by a KPort virtual package |
| `~ignore` | Drop this dep (handled implicitly by the build system) |

### Runtime depends note

Neon's binary stanzas use `${shlibs:Depends}` for most runtime deps, which is
resolved at Debian build time and cannot be read statically. Named deps that
appear alongside it (e.g. `kf6-kdeclarative`, `libdrm2`) are extracted and
translated. For packages where only `${shlibs:Depends}` is present, `depends`
is left empty with a comment — populate it after a test build by inspecting
`ldd` output or `dpkg -I` on the built `.deb`.

---

## sync-sources.sh

Fetches the project list for each enabled GitLab source in `config/sources.yml`
and caches it to `db/sources-cache.json`. The generator reads this cache to
avoid re-enumerating the API on every run.

```
Usage: sync-sources.sh [options]

Options:
  --source <name>   Refresh only the named source (substring match)
  --force           Re-fetch even if cache is less than 24 hours old
  --dry-run         Print what would be fetched without writing the cache
  --help
```

Cache entries expire after 24 hours. Run with `--force` after adding a new
source to `config/sources.yml` or after a major KDE release.
