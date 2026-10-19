# Corpus demand tooling

These tools measure which iOS API missing on iOS 6.1.3 the demand corpus (ten self-built open-source
App Store apps) actually calls, and rank that demand for the backport bands. Every tool is Lua, run
with `xmake l` from the charon checkout.

## Tools and data are found in different places

- **Tools** sit beside this file. A tool finds its neighbours through `import(..., {rootdir = os.scriptdir()})`
  and its shared modules through `modules/` next to `tools/`.
- **Data** lives under `$CHARON_CORPUS_ROOT/corpus/`, resolved by `modules/workspace.lua` (`corpus()`).
  `CHARON_CORPUS_ROOT` defaults to `$HOME/Git/projects/ios/coordination`. Every tool refuses to run, naming
  the path it checked, when that `corpus/` directory is missing. None falls back to an empty default.
- **Run output and scratch** go to `$HOME/.cache/hades/<task>/` (`workspace.run`/`workspace.fresh`; the task
  is `HADES_TASK` or the checkout's folder name), never into the checkout. The iPhoneOS 26.2 SDK is
  `workspace.sdk()` (`CHARON_GEN_SDK` overrides it).

Overrides, for a scratch run that must not touch the shared data:

| Variable | Redirects |
| --- | --- |
| `CHARON_CORPUS_ROOT` | the whole data directory (point it at a scratch copy with the inputs a step reads) |
| `CHARON_REGISTRY_TSV` | the registry export (default `$HOME/.cache/hades/<task>/registry-export/carried-registry.tsv`, `xmake l modules/workspace.lua run registry-export`) |
| `CHARON_CACHES_DIR` | the cache ladder directory (`caches/`) |
| `CHARON_TREE_DIR` | the source tree `verify.lua` checks definitions against |
| `CHARON_BUILT_EXPORTS` | the built-exports file `gen-report.lua` reads |
| `CHARON_WEAK_IMPORTS_OUT` | the output of `weak-imports.lua` (or give it as argument 2) |
| `CHARON_ROOT` | the checkout the dyld readers load their modules from (`cache-value.lua`, `dump-cache.lua`, `corpus-scan.lua`) |

## The batch, in order

`xmake l tools/corpus/regen.lua <batch-label>` runs one batch. The order matters: the previous list is saved
before anything regenerates, and the hint ledger is read before the registry baseline is replaced.

1. Demand per app. For each app, `xmake l tools/corpus/scan-app.lua <app> <path-to-.app>` runs `corpus-scan.lua`
   over the bundle's Mach-O files against the stock 6.0 cache (into `<app>.scan.tsv`) and ingests the bundle
   with `aggregate.lua ingest <app> <path-to-.app>` into `store.json`. The ten corpus apps' extracted bundles
   are under `corpus/<app>/extracted/Payload`.
2. Selectors per app: `xmake l tools/corpus/scan-selectors.lua <app> <path-to-.app>` writes
   `selcache/<app>.json` (the selector names the bundle carries) and `defcache/<app>.json` (the selectors it
   defines), both from the same binary. `xmake l tools/corpus/defined-methods.lua` with no arguments refreshes
   `defcache/` for every corpus app that has an extracted bundle.
3. Registry export: `xmake l tools/corpus/export-registry.lua <checkout-root> <outfile>`, with
   `<checkout-root>` the `packages/a/apple-backports` directory of the checkout. Write the export to the
   default run-folder path (`$(xmake l modules/workspace.lua run registry-export)/carried-registry.tsv`), or
   point `CHARON_REGISTRY_TSV` at the file; `regen.lua` and the tools read the same default.
4. Ranking: `xmake l tools/corpus/regen.lua <batch-label>` saves the previous list, runs `crash-demand.lua`,
   runs `hint-track.lua <batch-label>` (appends decided hints to `hint-ledger.tsv` and
   `absent-reversals.tsv`, reading the saved previous list), then saves the registry export as
   `registry-last.tsv` for the next batch.
5. Weak imports: `xmake l tools/corpus/weak-imports.lua <symbol-file> [output]` ranks a list of weak
   symbols into `weak-imports-ranked.tsv`; then `xmake l tools/corpus/weak-per-image.lua <dir-of-nm-outputs> [--any]`
   attributes them to the images that import them (`weak-imports-by-image{,-any}.tsv`).
6. Report: `xmake l tools/corpus/gen-report.lua` (no arguments) writes `band-*.tsv` and `corpus-report.md`.
   Run it after a full re-ingest; it reads `absent/*.absent.tsv` for the Katabasis cross-check column.
7. Canon exports, after each canon build: `xmake l tools/corpus/built-exports.lua <canon-run>` writes the
   list `gen-report.lua` reads for `LAUNCH-BLOCK`, under a first line naming the canon's version. A list
   older than the canon shows that version in the report.
8. A single symbol list checked against the registry and the tree: `xmake l tools/corpus/verify.lua <name> <rows.tsv>`,
   where each line of `rows.tsv` is `api<TAB>kind<TAB>extra`. `verify.lua` takes its decision rows from
   that file and reads `store.json` for the adopter list.

The generator's surface, which replaces the corpus table for the tools that read it:

- `xmake l tools/gen.lua impl-index --tree <checkout> --coordination <corpus-dir>` lists the reference
  implementations' files (`impl-source-trees/`) with `gh api`, names only, nothing cloned.
- `xmake l tools/gen.lua surface --tree <checkout> --sdk <iPhoneOS SDK> --out <dir> --coordination <corpus-dir>`
  writes `sdk-surface-model.tsv`: every declaration that arrived after iOS 6.1, with its registry status,
  demand and implementation lead.

Read-only readers of a dyld shared cache, through `modules/apple/dyld.lua`:

- `CHARON_ROOT=<checkout> xmake l tools/corpus/cache-value.lua <cache> <symbols>` reads the value of
  exported data symbols (one symbol per line: name, width, pointer flag, string flag).
- `xmake lua tools/cache-extract.lua <modules> <cache> <install> <outfile>` writes one image of a cache out
  as a Mach-O file, for a reader that needs the image's own symbol table (32-bit images).
- `xmake l tools/corpus/disasm.lua <cache> <image> <lo> <hi> [armv7|arm64e]` disassembles one window of an
  image at the release's own addresses (`llvm-mc`; on armv7 the low bit of `lo` picks Thumb); `<cache>` may be
  `@<hexfile>`, a file of hex digits.

## The SDK walks and the API ledger

- `xmake l tools/corpus/surface-diff.lua <Framework...> [--sdk S] [--target T] [--registry R] [--above V]
  [--up-to V] [--release R] [--list] [--rows F]`: what an SDK declares for a framework (clang's AST of its
  headers, `surface_walk.lua`) against the registry.
- `xmake l tools/corpus/sdk-introduced.lua --sdk <iPhoneOS SDK>` walks a whole SDK (every framework's headers,
  the C libraries under `usr/include`, every `.swiftinterface` through `swiftinterface.lua`) into
  `sdk-<version>-declared.json`; without `--sdk` it writes `sdk-introduced.json` and
  `sdk-introduced-unverified.tsv` from the Mac Catalyst SDK. Slow: run it through `coordination/heavy.sh`.
- `xmake l tools/corpus/sdk-surface.lua build [--new F] [--old F] [--registry F] [--demand F] [--out DIR]`
  writes `sdk-<v>-surface.tsv`, `sdk-<v>-removed-since-<old>.tsv` and `sdk-<v>-surface.md` from two declared
  walks, the registry export, `crash-demand-top.tsv` and `impl-source-trees/`.
- `xmake l tools/corpus/api-ledger.lua build ...` measures every surface row at a release (the `ledger*/`
  folders); `api-ledger-swift.lua` reads the built armv7 Swift modules into `swift-modules.json` for it, and
  `const-values.lua` reads the exported constants' values out of real dyld caches. Each prints its usage.

## Data in `corpus/`

Not tracked in git: it holds ingest output that changes on every run.

| Path | Written by |
| --- | --- |
| `store.json` | `aggregate.lua ingest` (through `scan-app.lua`) |
| `selcache/<app>.json`, `defcache/<app>.json` | `scan-selectors.lua`, `defined-methods.lua` |
| `caches/<release>.tsv` | the output of `dump-cache.lua`, redirected (the symbol ladder); `caches/sel/<release>.strings` by `strings -a` over each cache, no tool in this tree (see "Two cache ladders") |
| `crash-demand-top.tsv`, `crash-demand-ambiguous-owners.tsv`, `crash-demand-dropped.tsv` | `crash-demand.lua` (no arguments) |
| `selector-demand-7-10.tsv`, `selector-demand-FUIKit.tsv` | `selector-demand.lua extract` (the caches, slow), then `selector-demand.lua report` |
| `static-candidates-demand.tsv` | `static-candidates.lua <surface-diff --list output>` (argument 2 or `CHARON_STATIC_CANDIDATES_OUT` redirects it) |
| `hint-ledger.tsv`, `absent-reversals.tsv`, `crash-demand-prev.tsv` | `hint-track.lua`, and `regen.lua` for the saved list |
| `registry-last.tsv` | `regen.lua` (the registry export, after the hint step has read the old one) |
| `weak-imports-ranked.tsv`, `weak-imports-by-image{,-any}.tsv` | `weak-imports.lua`, `weak-per-image.lua` |
| `band-*.tsv`, `corpus-report.md` | `gen-report.lua` |
| `built-exports-6.1.3.txt` | `built-exports.lua` |
| `sdk-introduced.json`, `sdk-introduced-unverified.tsv` | `sdk-introduced.lua` (Catalyst mode); read by `weak-imports.lua` and `crash-demand.lua` |
| `sdk-<v>-declared.json` | `sdk-introduced.lua --sdk` |
| `sdk-<v>-surface.tsv`, `sdk-<v>-removed-since-<old>.tsv`, `sdk-<v>-surface.md` | `sdk-surface.lua build` |
| `ledger*/` | `api-ledger.lua`, with `api-ledger-swift.lua`'s `swift-modules.json` and `const-values.lua`'s values |
| `impl-source-trees/` | `tools/gen.lua impl-index` |
| `sdk-surface-model.tsv` | `tools/gen.lua surface` (written to `--out`) |
| `decision-overrides.tsv` | hand-maintained: Coordinator verdicts the registry export does not carry yet |
| `absent/*.absent.tsv` | merged from Katabasis; read by `gen-report.lua` |

## Universes, tests and callers

- The selector universe that `crash-demand.lua`, `selector-demand.lua` and `static-candidates.lua` read is the
  stock 6.0 armv7 cache, through `aggregate.selector_universe()` (apple.objc's `known_selectors`); the class
  universe is `aggregate.class_universe()` (apple.objc's `inventory`). Neither reads `~/.charon/dyld` directly.
- `sdk-<v>-surface.tsv` (the 26.2 table) is read by `tests/backports/host/combine/coverage.sh` and
  `tests/backports/host/matter/run.sh`; `tools/gen surface` writes a different table (`sdk-surface-model.tsv`).
- `tools/corpus/tests/corpus_test.lua`, which the light guard runs, holds the text-matcher and json_order checks
  and then runs the suites beside it: `registry_files_test`, `walk_test`, `surface_table_test`, `ledger_test`,
  `values_test`.
- `tests/backports/host/combine/coverage.py` still loads the removed `swiftinterface-surface.py` and no longer runs;
  `swiftinterface.lua` gives the same rows.

## Two cache ladders disagree with the dyld index

`caches/<release>.tsv` and `caches/sel/<release>.strings` are `strings(1)` products: a rung was "the first
of these files, oldest first, that contains the name". Recomputing every row through the dyld index
(measured 2026-09-30, the scripts in the cache-index worktree's `runs/recompute/`) found:

- symbol ladder, `caches/<stem>.tsv`, 3 179 542 placed rows: 2 667 477 (83.90 %) identical in the index;
  511 318 (16.08 %) moved; 747 placed but not in the index. Of the moved, 510 685 move to an earlier release.
- selector ladder, `caches/sel/<stem>.strings`, 9 518 012 placed rows: 427 332 (4.49 %) identical;
  2 308 659 (24.26 %) moved, 2 233 020 of them to an earlier release; 6 782 021 lines hold no name the index
  knows.

`strings(1)` does not read a Mach-O symbol table, so a name that lives only in one is invisible to the old
scan and dated to a later release. On the Foundation of iPhone OS 3.0, `strings -a` misses 2060 of the
file's 2061 `nm -gU` names. The selector ladder is the whole cache file's `strings -a` output, not only the
`__objc_methname` strings, so `crash-demand.lua` dates unversioned selectors from whatever printable bytes a
scan found.

Nothing has been regenerated. Rewriting either ladder changes what `crash-demand.lua` and `aggregate.lua`
read, so it is a decision with its own blast radius. No tool in this tree regenerates them through the index.

## Known limits

- The committed `crash-demand-dropped.tsv` was written by a Python tool whose order for rows tied on caller count
  followed its hash seed. The Lua tools sort every tie with an explicit key, so their output does not depend on a
  run's hash order; compare that file sorted.
- `impl-lead` is a lead by file name, not a fact of implementation: nothing checks that the file implements
  the member, and WinObjC's tree is years older than most rows.
- `sdk-introduced.lua --sdk` walks a whole iPhoneOS SDK and is slow; run it through `coordination/heavy.sh`.
