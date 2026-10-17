# Corpus demand tooling

These tools measure which iOS API missing on iOS 6.1.3 the demand corpus (ten self-built open-source
App Store apps) actually calls, and rank that demand for the backport bands. The tools are Lua, run
with `xmake l`, except for the Python steps listed under "Still Python" below.

## Tools and data are found in different places

- **Tools** sit beside this file. A Lua tool finds its neighbours through `import(..., {rootdir = os.scriptdir()})`
  and its shared modules through `modules/` next to `tools/`; a shell tool finds its neighbours through
  `${0:A:h}` (zsh) or `$(dirname "$0")`. Copying the whole `tools/corpus/` directory elsewhere keeps working.
- **Data** lives under `$CHARON_CORPUS_ROOT/corpus/`. `CHARON_CORPUS_ROOT` defaults to
  `$HOME/Git/projects/ios/coordination`. Every tool refuses to run, naming the path it checked, when that
  `corpus/` directory is missing. None falls back to an empty default.

Overrides, for a scratch run that must not touch the shared data:

| Variable | Redirects |
| --- | --- |
| `CHARON_CORPUS_ROOT` | the whole data directory (point it at a scratch copy with the inputs a step reads) |
| `CHARON_REGISTRY_TSV` | the registry export (default `.agent-work/runs/registry-export/carried-registry.tsv` in the checkout) |
| `CHARON_CACHES_DIR` | the cache ladder directory (`caches/`) |
| `CHARON_TREE_DIR` | the source tree `verify.lua` checks definitions against |
| `CHARON_BUILT_EXPORTS` | the built-exports file `gen-report.lua` reads |
| `CHARON_WEAK_IMPORTS_OUT` | the output of `weak-imports.lua` (or give it as argument 2) |
| `CHARON_ROOT` | the checkout the dyld readers load their modules from (`cache-value.lua`, `dump-cache.lua`, `corpus-scan.lua`) |

## The batch, in order

`regen.sh <batch-label>` runs one batch. The order matters: the previous list is saved before anything
regenerates, and the hint ledger is read before the registry baseline is replaced.

1. Demand per app. For each app, `scan-app.sh <app> <path-to-.app>` runs `corpus-scan.lua` over the
   bundle's Mach-O files against the stock 6.0 cache and ingests the result with
   `aggregate.lua ingest <app> <path-to-.app>` into `store.json`. `fetch-scan.sh <app> <ipa-url>` downloads
   an IPA first and deletes it afterwards. `reingest-all.sh` runs that ingest for the ten corpus apps from
   their extracted bundles under `corpus/<app>/extracted/Payload`.
2. Selectors per app: `xmake l tools/corpus/scan-selectors.lua <app> <path-to-.app>` writes
   `selcache/<app>.json` (the selector names the bundle carries) and `defcache/<app>.json` (the selectors it
   defines), both from the same binary. `xmake l tools/corpus/defined-methods.lua` with no arguments refreshes
   `defcache/` for every corpus app that has an extracted bundle.
3. Registry export: `xmake l tools/corpus/export-registry.lua <checkout-root> <outfile>`, with
   `<checkout-root>` the `packages/a/apple-backports` directory of the checkout. Write the export to the
   default run-folder path (`.agent-work/runs/registry-export/carried-registry.tsv`), or point
   `CHARON_REGISTRY_TSV` at the file; `regen.sh` and the tools read the same default.
4. Ranking: `tools/corpus/regen.sh <batch-label>` saves the previous list, runs `crash-demand.lua`,
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

## Data in `corpus/`

Not tracked in git: it holds ingest output that changes on every run.

| Path | Written by |
| --- | --- |
| `store.json` | `aggregate.lua ingest` (through `scan-app.sh`) |
| `selcache/<app>.json`, `defcache/<app>.json` | `scan-selectors.lua`, `defined-methods.lua` |
| `caches/<release>.tsv` | the output of `dump-cache.lua`, redirected (the symbol ladder); `caches/sel/<release>.strings` by `sel-universe.sh` (see "Two cache ladders") |
| `crash-demand-top.tsv`, `crash-demand-ambiguous-owners.tsv`, `crash-demand-dropped.tsv` | `crash-demand.lua` (no arguments) |
| `selector-demand-7-10.tsv`, `selector-demand-FUIKit.tsv` | `selector-demand.lua extract` (the caches, slow), then `selector-demand.lua report` |
| `static-candidates-demand.tsv` | `static-candidates.lua <surface-diff --list output>` (argument 2 or `CHARON_STATIC_CANDIDATES_OUT` redirects it) |
| `hint-ledger.tsv`, `absent-reversals.tsv`, `crash-demand-prev.tsv` | `hint-track.lua`, and `regen.sh` for the saved list |
| `registry-last.tsv` | `regen.sh` (the registry export, after the hint step has read the old one) |
| `weak-imports-ranked.tsv`, `weak-imports-by-image{,-any}.tsv` | `weak-imports.lua`, `weak-per-image.lua` |
| `band-*.tsv`, `corpus-report.md` | `gen-report.lua` |
| `built-exports-6.1.3.txt` | `built-exports.lua` |
| `sdk-introduced.json` | `sdk-introduced.py` (Python, see below); read by `weak-imports.lua` and `crash-demand.lua` |
| `impl-source-trees/` | `tools/gen.lua impl-index` |
| `sdk-surface-model.tsv` | `tools/gen.lua surface` (written to `--out`) |
| `decision-overrides.tsv` | hand-maintained: Coordinator verdicts the registry export does not carry yet |
| `absent/*.absent.tsv` | merged from Katabasis; read by `gen-report.lua` |

## Still Python

These files are not ported. Each is still needed by a step above, or is named by the port list and blocked
on a decision, so none has been deleted.

- `sdk-introduced.py` writes `sdk-introduced.json`, which `weak-imports.lua` and `crash-demand.lua` read. No Lua
  producer exists for that file yet, so deleting the script would leave the file without a regenerator. The
  extractor in `tools/found` cannot stand in for its walk: `decls` takes its target from the SDK's own settings,
  so it cannot compile for `arm64-apple-ios26.0-macabi`, it does not read the iOSSupport overlay that
  `surface-diff` applies for macabi, and `avail.lua` merges a key's declarations by different rules from
  `surface-diff`'s `declared()`. A byte-for-byte match therefore needs a target option in `decls` and a
  reviewed decision about the merge rule; neither is made here.
- The selector universe that `crash-demand.lua`, `selector-demand.lua` and `static-candidates.lua` read is the
  stock 6.0 armv7 cache, through `aggregate.selector_universe()` (apple.objc's `known_selectors`); the class
  universe is `aggregate.class_universe()` (apple.objc's `inventory`). Neither reads `~/.charon/dyld` directly.
- `sdk-surface.py`: its `impl-index` is ported. Its `build` writes `sdk-<v>-surface.tsv`, which
  `tests/backports/host/combine/coverage.sh` and `tests/backports/host/matter/run.sh` read (the 26.2 table). `tools/gen surface` does not replace that table yet, so `build` stays, and
  `selftest-api-ledger-getter.py` reads the script's source, so the file stays.
- `swiftinterface-surface.py`: `tests/backports/host/combine/coverage.py` runs it, and that test also needs a
  full armv7 build of the Combine module (`coverage.sh`).
- `api-ledger.py`, `api-ledger-swift.py` and their selftests: `const-values.py`, `tests/backports/host/videotoolbox-frameprocessor/check_port.py`,
  `tools/corpus/tests/test_corpus.py` still calls them.
- Python tools in this directory that no step above names: `gen-cifilter-builtins.py`, `gen-imageio-names.py`,
  `gen-imageio-property-map.py`, `gen-ledger-objects.py`, `gen-mio.py`, `generate-ledger-objects.py`, `mio-rows.py`,
  `surface-diff-latest.py`.
  Whether each is still needed is the coordinator's call.

`tools/corpus/tests/test_corpus.py` is still in the light guard; `tools/corpus/tests/corpus_test.lua` is the Lua
suite for the ported tools (30 fixture checks, the text matchers and json_order). The coordinator swaps the guard entry when the Python
callers above are gone.

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
read, so it is a decision with its own blast radius. The regeneration through the index is Python today
(see "Still Python").

## Known limits

- `crash-demand-dropped.tsv`'s row order for rows tied on caller count depends on Python's hash seed. The
  Lua tools sort every tie with an explicit key, so their output does not depend on a run's hash order.
- `impl-lead` is a lead by file name, not a fact of implementation: nothing checks that the file implements
  the member, and WinObjC's tree is years older than most rows.
- `sdk-introduced.py --sdk` walks a whole iPhoneOS SDK and is slow; run it through `coordination/heavy.sh`.
