# generated/

Auto-generated pacscript skeletons produced by `scripts/kport/generate-pacscripts.sh`.

These are **not production-ready**. Each file needs human review before promotion
to `packages/`. Common things to verify:

- Build dependencies are complete and correctly named
- `source` URL resolves and the checksum is correct
- `build()` function produces a working install
- USE flag conditionals are correct for this package
- Slot handling is correct if multiple versions coexist
- Patches from `debian/patches/` are applied where needed

## Git policy

`generated/*` is excluded from version control via `.gitignore`. Only this
`README.md` is tracked. Generated pacscripts are intentionally untracked:

- They are machine output and change on every generator run
- Committing them would create noise and merge conflicts
- The canonical source of truth is `packages/` (promoted, reviewed files)

If you run `git status` and see no files under `generated/`, that is expected.
To inspect what was generated, run the generator and check the directory directly:

```bash
bash scripts/kport/generate-pacscripts.sh
ls generated/
```

## Promotion workflow

1. Generate: `bash scripts/kport/generate-pacscripts.sh`
2. Review the skeleton: `cat generated/<category>/<pkg>/<pkg>.pacscript`
3. Test locally: `pacstall -Il generated/<category>/<pkg>/<pkg>.pacscript`
4. Fix any issues (deps, checksums, build function, USE flags)
5. Promote: `kport promote <pkg>` — moves the file to `packages/<category>/<pkg>/`
6. Open a PR — CI validates pacscript format and runs the resolver check

## Regeneration

Generated files are overwritten on each generator run. Do not hand-edit files
in `generated/` — edit the promoted copy in `packages/` instead.
