---
name: backports-gate
description: Run the apple-backports gate on a toolchain checkout or worktree and read its verdict — the light guard, the full package gate (all libraries, check_registry, imports), the release-split check and the host-test liveness sweep. Use before sending a backports patch, when merging one, or whenever asked "is this tree green".
---

# Gating apple-backports

Run everything from the top of the checkout being gated.

## 1. Light guard (seconds)

```
./xmakew l tools/check.lua toolchain
```

The `tests/addon` suites. Each prints `<name>: OK (0 failures)` or one `<name> FAIL: ...` line per failure.

## 2. Full gate (minutes to tens of minutes)

An `implemented` **protocol** row also has a header behind it, and a gate is the first thing that
looks. `modules/apple/backports.lua` writes one source per release a library's protocol rows arrived
in, naming each row with `@protocol(<name>)` and importing `Revenant<Folder>Protocols.h`; a row that
header does not declare is a source that does not compile, and nothing before the gate reads that
header. So before the gate, after a round that adds or changes a protocol row:

```
sh tests/addon/protocol-sources.sh <the 16.4 SDK> "$PWD/.agent-work/runs/<task>/protocols"
```

43 sources over 17 libraries at the time of writing; it prints `gate-shape: N source(s), M failed`
and exits with M. The light guard's `protocol_headers_test` catches the same class in seconds and
names the rows, so run it too — it is the check that makes the failure cheap rather than the one
that finds it first.

To *declare* a protocol the 16.4 SDK does not have, regenerate the library's header rather than
editing it — `xmake l tools/gen.lua protocols` over the 26.2 and 16.4 SDK sysroots, with the wanted
list read from the registry. It forward-declares a protocol a header of the library's own folder
declares and imports that header, so the eight trait protocols of UIKit come from
`RevenantTraits17.h`; the command and the row list are in the commit that regenerated them
(`7a073c987`).

Every edit for the round is done and committed first. The full gate is a build of `revenant@apple-backports`
with every library of `LIBRARIES` in `modules/apple/backports.lua`, which is what runs `check_registry` and the
imports check; the build log is what is read below. The script that drove it lived outside the repository and is
gone; until `tools/check.lua backports` replaces it, build the package that way by hand.

Reading the verdict (`$out.log`):

- **Green:** no `error:` line; the log has
  `imports: every non-weak import of the armv7 slices of N binaries resolves against M exports`
  followed by one `.../lib<Framework>Backports.dylib` path per library. When that line goes on with
  `; K weak imports it does not export`, the `warning:` lines above it name each, per library and with the
  cache checked against: a call through NULL at that release unless a check stands in front of it, so read them
  before calling the run green. A package build checks both ends of every band and prints such lines for each.
- **Red:** `error: the registry does not describe what the backports carry:` and the lines under it —
  `built, but no entry in registry/`, `listed as implemented, but nothing of that name is built`,
  `listed as absent, but what is built answers it`, and the rest. Each names symbols; fix the
  registry or the code, not the check.
- `note: N of the registry's entries name no file of facts yet` is a note, not a failure.
- **Red before the registry is read:** `error: the staged bands cannot have their imports checked:`
  and one line per release, `iOS X, an end of the band of iOS P (first to last): xmake firmware
  --arch=A fetch X`. The canon stages every band and checks each against its first and last
  release; the gate names every such cache not held, all at once. Fetch them one at a time (the
  network, not a heavy slot), then gate again: a fetched cache can move a band point earlier and
  with it the end of the band before (measured 2026-09-23, 7.1 -> 7.0.6 -> held), so a second run
  can name a release the first did not.
- `EXIT=0` alone is not green: read the lines above. A pipe or a backgrounded wrapper can hide a
  non-zero exit.

Traps:

- The tree is frozen while the gate runs: `sources()` globs once at the start, so a file added or
  edited mid-run gives a false red or a false green. Edits wait for the next run.
- Argument three is the checkout. Always pass it; never gate by a remembered path.
- A port or test project that requires `revenant@apple-backports` with only some of its configs never
  runs `check_registry`: `modules/apple/backports.lua` runs it only when every library in
  `LIBRARIES` was built. Such a green build says nothing about the registry; only this gate does.

## 3. Release split (mandatory after a green build, before handing off)

The gate checks releases on the coarse grid of band points; this checks each symbol against the
cache ladder. `OBJECTSDIR` is one framework directory (the script does not recurse):

```
for d in "$out"/build/objects/*/; do xmake l tools/release-split.lua "$d"; done
```

A flagged file has symbols first exported in more than one release: split it, one release per
object file.

- A release it names is the first held rung that exports the symbol, an upper bound: nothing is held
  between 12.0 and 16.0, so 16.0 means "after 12.0, by 16.0", never a measured 13.0-15.x (the script
  prints each such gap).

- A category has no `nm`-visible symbols, so a clean result says nothing about category files:
  check those by selector-string search against the release caches
  (`$HOME/.revenant/dyld/<release>/dyld_shared_cache_armv7`), with a negative control that the
  search finds a selector known to be there.

## 4. Host tests (liveness)

```
sh tests/backports/host/run-all.sh [--seconds N] [NAMES]
```

A sweep: it reports whether each `host/*/run.sh` got past building itself, not whether its checks
pass. A test that stops linking dies silently under `set -eu`; after reviving one, run it in full
and read it for regressions before calling it healthy.

`revenant_check(passed, name, detail)` takes `const char *name` and prints it with `%s`, so a name
is a C string. An `@"…"` there is read as a pointer: the check still passes or fails as it should,
the run still exits with the failure count, and the line that would tell a reader *which* check
failed prints an address - `FAIL P'^A: it adopts none` - which is worse than no line, because a
red run can no longer be read. The existing macro `NAMED(...)` already returns `.UTF8String` for a
name built with a format. A file a band adds checks to should compile with no warning at all
under the flags `run.sh` compiles a test with (`-Wall -fobjc-arc` and the harness on the include
path), and a test that deliberately probes a `nil` or a newer API than the target carries says so
in a local pragma rather than losing the warning in a file-wide one.

## What goes with a patch

The base commit, what is inside, which of steps 1–4 ran with their verdict lines, and the caveats.

Before `git format-patch`, `git status` must show no rebase or `am` in progress, and `git log -1`
must be your own last commit: during a stopped rebase HEAD is a partly replayed branch, and the
export carries the wrong commits.
