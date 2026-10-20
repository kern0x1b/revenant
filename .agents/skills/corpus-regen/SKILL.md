---
name: corpus-regen
description: Regenerate the backports registry export and the corpus demand data after a push to the toolchain main, refresh the canon exports, and certify any list of "missing" APIs through tools/corpus/verify.lua. Use after every merge to main, when the demand ranking looks stale, or before handing anyone a list of APIs to implement.
---

# Registry export and corpus regeneration

Tools: `tools/corpus/` in this repository (`$HOME/Git/projects/ios/coordination/corpus-tools` is a
symlink to it). Data: `$HOME/Git/projects/ios/coordination/corpus/` (`REVENANT_CORPUS_ROOT` overrides the
parent directory). Background, every generated file, and what is still Python: `tools/corpus/README.md`.

## 1. Registry export, after every push to main

From a checkout at the pushed commit:

```
sha=$(git rev-parse --short HEAD)
export_tsv=$(xmake l modules/workspace.lua run registry-export)/carried-registry.tsv
xmake l tools/corpus/export-registry.lua "$PWD/packages/frameworks/apple-backports" "$export_tsv"
wc -l "$export_tsv"
cp "$export_tsv" $HOME/Git/projects/ios/coordination/corpus/carried-registry-$sha.tsv
```

- The first argument is the **package root** `packages/frameworks/apple-backports` (the script reads
  `<root>/registry/*.json`), not the checkout root. A wrong root writes a header-only file without an
  error: compare the row count with the previous `carried-registry-*.tsv`.
- The corpus tools read the export at `REVENANT_REGISTRY_TSV`, which defaults to
  `$HOME/.revenant/cache/<task>/registry-export/carried-registry.tsv` (`modules/workspace.lua run registry-export`);
  `regen.lua` uses that default path. The run folder is scratch, so the durable copy is the one in
  `coordination/corpus/`. Point `REVENANT_REGISTRY_TSV` at it when the run-folder copy is missing.
- An export older than the last registry commit on `origin/main` makes every ranking stale:
  `git log -1 --format=%cd origin/main -- packages/frameworks/apple-backports/registry` against the file's mtime.

## 2. Regenerate the ranking

After a canon build (workspace skill `canon-install`), refresh what the 6.1.3 band exports. The report's
`LAUNCH-BLOCK` tally reads this list and names the canon it came from:

```
xmake l tools/corpus/built-exports.lua <canon-run>
```

Then the batch, from the checkout whose tools you trust:

```
xmake l tools/corpus/regen.lua <label>
xmake l tools/corpus/gen-report.lua
```

`regen.lua` does, in this order (do not reorder by hand): save `crash-demand-top.tsv` as
`crash-demand-prev.tsv`; run `crash-demand.lua`; run `hint-track.lua <label>`; copy the
export to `registry-last.tsv`. `gen-report.lua` then writes `band-*.tsv` and `corpus-report.md`.

For a single list of weak imports, `xmake l tools/corpus/weak-imports.lua <symbol-file>` and then
`xmake l tools/corpus/weak-per-image.lua <dir-of-nm-outputs> [--any]`.

- Check the numbers, not the exit code: a tool pointed at a missing input writes a plausible, smaller or
  empty table. Compare row counts with the previous run.
- The tie order of `crash-demand-dropped.tsv` follows Python's set order in the committed file; compare it sorted.
- `observed.py` and `live-scan.py` were removed: they read a deleted `emulator-lab/` tree. Their outputs
  (`observed-device.tsv`, `store-live.json`, `band-11-12-FCS.tsv`) are not regenerated any more.
- Run a step against a scratch `REVENANT_CORPUS_ROOT` first when the output is not meant to replace the real file.

## 3. Certify before handing out

A list of "missing" APIs is not evidence. Every list goes through `tools/corpus/verify.lua`:
`check(name, rows)` takes `rows` of `(api, kind, extra)`, and the command line
`xmake l tools/corpus/verify.lua <name> <rows.tsv>` takes one such row per line. It checks the registry
export and the source tree, and prints how many rows are real. It reads `REVENANT_REGISTRY_TSV` and
`REVENANT_TREE_DIR` (default: this checkout's `packages/frameworks/apple-backports`).

- "Not found" is reliable; "found" must be read: a declaration, a synthesized property and `@dynamic`
  all look like an implementation. `@dynamic` is evidence of absence.
- An explicit registry decision (`absent`/`ignored` with facts) outranks a find in the tree.
- Proving absence needs a control: show the probe finds something known to be there.
