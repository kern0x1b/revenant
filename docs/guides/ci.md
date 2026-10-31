# Continuous checks

`.github/workflows/check.yml` runs on every push to `main`, and on demand from the Actions tab or with
`gh workflow run check.yml --ref <branch>`. A push to any other branch starts nothing: a full run is four macOS jobs of
30 to 40 minutes, and a branch is checked once, when it is ready to land. All of its jobs but one run on `macos-26`: an `ubuntu-latest` job named `changes`
decides from the diff against the merge base with `main` which of them a branch run needs, and a public repository
runs five macOS jobs at a time, so a job whose inputs did not change is skipped:

- a change that touches only `docs/` or a Markdown file at the top of the repository runs `repository` alone, which is
  `./xmakew test -P . 'repository/*'`: the layout and documentation checks that read those files;
- `checks` runs for every other change;
- `backports`, `package` and `swift` run only when the change reaches the native builds: a change outside `docs/`,
  `emulator/`, `recompiler/`, `toolchain/tests/emulate/` and Markdown. Those folders never reach the native builds.

Every run starts with `quick` on `macos-26`: `./xmakew l -P . tools/prepush.lua`, the checks of [Before a push](#before-a-push-prepush).
It is on macOS because the lowered-members check reads the SDK. `repository`, `checks`, `backports`, `package` and `swift`
all `need` it, so a failure that prepush finds costs one short job and starts none of the macOS jobs of the run. The
other jobs are not cancelled when one of them fails, on purpose: a cancelled job skips every save step that is not
`always()`, and `backports` (its store and its objects), `package` (its facts, its objects and its store) and `swift`
(its store) save only on success. A cancel would lose the caches that a sibling still running saves today.

A push to `main` and a dispatch run every job. Each selects Xcode 26.6
and sets the prebuilt variables through the composite action `.github/actions/revenant-setup`; a composite action cannot
choose a runner, so each job keeps its own `runs-on`.

- `checks` runs `./xmakew test -P .`: every test a host with the prebuilt packages can run, in parallel. That is the
  repository's layout, comment, copied-text, credential and open-gap checks (`repository/*`), the toolchain's suites (`toolchain_light/*` and
  `toolchain_packages/*`), the emulator's and the recompiler's host tests. It sets `REVENANT_PREBUILT=kern0x1b/revenant`
  and `REVENANT_PREBUILT_ONLY=llvm,swift,ld64`, so LLVM, Swift and ld64 come from their releases and a missing release is an error, not a
  source build. It configures with `--emulator_vulkan=n`: the Vulkan renderer's SwiftShader is built from source, which
  takes most of the job, and the tests do not use it. The option stays on for the emulator's own builds. The tests that need a device, an emulator image or firmware are not declared on CI; see
  [the tests reference](../reference/toolchain/tests.md).
- `backports` sets `REVENANT_PREBUILT_ONLY=llvm,swift,ld64`, so LLVM and Swift come from their releases and are never
  built in the job. It configures and builds the Backports component
  (`./xmakew f -P . -p iphoneos -a armv7 --component=Backports`, then `./xmakew build -P .`) and uploads
  `build/iphoneos/armv7/release/lib*.dylib` as the artifact `backports-libraries`.
- `swift` configures the Swift component, builds the Swift targets (AppIntents, ActivityKit, TipKit, WidgetKit,
  swiftSpatial, swiftCloudKit, swiftWeatherKit, swiftNetwork, swiftUniformTypeIdentifiers, swiftCryptoKit) and installs the Swift
  packages through their wrappers. It names `swift-runtime` and `libcxx` in `REVENANT_PREBUILT_ONLY` as well, so a
  missing release of either is an error. Its install step has a 40-minute limit: on a cold store it installed the eleven
  packages in 17 min 47 s, and on a warm store, restored by the cache step, it finished in 58 s.

The checks run on macOS, not Linux: the suites compile with the Mac's clang and the emulator is a macOS program. Every
test in the default run must pass, so the `checks` job is red when one of them fails, and no test is skipped in CI
by a list of names.

Four caches make a warm run quick:

- the pinned xmake binary, keyed by `xmakew` and `packages/x/xmake`;
- the package store `.cache/xmake-global`. The backports job keys it by the output of
  `./xmakew l -P . tools/keys.lua iphoneos-sdk ld64`, so only a change to those two packages makes a new key. The checks job
  keys its own store by the files that decide what it installs: the xmake recipes of the packages, the third-party
  packages the default tests build, `toolchain/modules/prebuilt.lua`, and the component files that declare requirements.
  A store is restored by its exact key, or else by the newest store with the same prefix (`restore-keys`), so xmake
  installs only the packages whose own build hash is new. A store is saved only when the configure log shows an install,
  so a warm run writes nothing back, and a store is saved after the configure has succeeded, never half-made;
- the iOS 6.0 inventory `.cache/dyld/6.0/classes_armv7.json`, keyed by the firmware code that writes it
  (`toolchain/plugins/firmware`, `objc.lua`, `dyld.lua` and `firmware.lua`). While it is present the checks job skips the
  Backports configure that installs the firmware tools, which takes five minutes or more. The swift job runs that
  configure only when the dyld cache misses, since only the `fetch` needs the tool;
- the generated skeleton `build/generated/backports`, keyed by the store key and the hashes of the five
  `frameworks/Backports/tools/` files that write it (`ast`, `facts`, `generate`, `skeleton`, `sdk`), and saved on the
  same condition;
- the objects `build/.objs`, their depfiles `build/.deps`, the libraries `build/iphoneos` and the source manifest
  `build/backports-sources.txt`. The key has two parts: the store key and the hashes of the toolchain folders the build reads (`toolchain/` without `tests/`), `packages/**`,
  `addons/**`, `xmake.lua`, `xmakew` and `frameworks/Backports/xmake.lua`, which must match exactly; and the hash of
  `frameworks/Backports/**`. When only the second part differs, the job restores the newest objects with the same first
  part. The manifest holds the git blob hash of every file under `frameworks/Backports` and of every generated
  skeleton file, and it is written once the build has succeeded and saved with the objects.

xmake recompiles a source whose mtime is newer than its depfile, and a restored cache has older depfiles than a fresh
checkout has sources. So the job first gives every tracked file one fixed mtime, and the skeleton writer rewrites a
generated file only when its text changed, so a restored skeleton keeps the mtime its objects were built against. After
the facts step, on a restored manifest, the backports job touches every file whose hash differs from the manifest, so
xmake recompiles those sources and, through their depfiles, the objects that include a changed header. The `checks` job
takes no fixed mtime, because it restores only the package store, which holds no `build/` objects: nothing it restores
is compared with a source's mtime.

The backports job's build step has a 60-minute limit and its configure step a 45-minute one. A cold build of the
component took 8 min 58 s and 7 min 42 s on two recent runs, and one hit 12 min 13 s after a cold package configure;
the limits cover a cold package store and a cold build, and a warm objects restore builds only the sources that
changed.

A warm run that restores its store writes nothing back. The backports job installs no LLVM from Homebrew: the
toolchain's `llvm` (its clang, which monocypher builds with) and `ld64` come from their prebuilt releases, and
`REVENANT_PREBUILT_ONLY` names the packages whose missing release is an error instead of a source build; `1` names all of them.

## Before a push: prepush

`./xmakew l -P . tools/prepush.lua` runs the host checks that CI would otherwise find only after its macOS jobs have started.
It needs no configure and no package, and with the caches warm it takes about 15 seconds. It runs every check and
prints each result, so one run lists all the failures:

- `tools/comments.lua check` and `test`: no comments in the tracked files, and the tool's own tests;
- `tools/layout.lua`, `tools/docs_commands.lua` and `tools/open_gaps.lua`: the layout, the commands the documents name, and
  the open gaps the Backports README names;
- `agent-skills/tests/credentials.lua test` and `copied_text.lua test`: their fixtures;
- `toolchain/tools/recipe_digests.lua`: the digests of the recipes are regenerated, and a `port/digest.lua` that differs
  from the committed one fails the run, so the change that moved an input commits its digest;
- `frameworks/Backports/tests/lowered_members_test.lua`: `frameworks/Backports/tools/lowered-members.txt` equals the
  members generated from `frameworks/Backports/src`. The generator reads the whole SDK header set, so the first run on
  a cold disk is the slow one; measured locally, the generation took about 30 seconds on warm files and the scratch
  cache returns the result in about 2 seconds;
- the negative shape: every test source that runs with `--negative` (the host tests declared in
  `frameworks/Backports/xmake.lua` and the emulator's negative targets) must read the flag, itself or through `check.h`,
  and a `check.h` test must return `revenant_finish()`. A test that ignores the flag runs its positive case under
  `--negative` and exits 0, which the host run reports as a failure only after its macOS job. The shape check cannot see a
  check that never fails; the host run does.

`./xmakew l -P . tools/prepush.lua test` tests the tool itself, and `repository/prepush` runs that test in the `repository` group.
The two log tools below are tested by prepush too.

## Verifying Swift here

The Swift configure of the `swift` job runs on this machine too. CI installs its packages; a checkout gets them by cloning the
main checkout's store into a private cache of its own, the `.cache` of the worktree (never the main checkout's). The clones are
APFS copies: they take no space until a configure writes to them, and removing them leaves nothing behind.

```sh
W=$PWD M=path/to/the/main/checkout
mkdir -p "$W/.cache/xmake" "$W/.cache/xmake-global/.xmake/packages" "$W/.cache/dyld" "$W/.cache/scratch"
cp -c -R "$M/.cache/xmake/." "$W/.cache/xmake/"
cp -c -R "$M/.cache/xmake-global/.xmake/repositories" "$W/.cache/xmake-global/.xmake/"
cp -c -R "$M/.cache/dyld/6.0" "$W/.cache/dyld/"
cp -c -R "$M/.cache/scratch/lowered-members" "$W/.cache/scratch/"
for n in ld64 iphoneos-sdk llvm micro-ecc apple-compat box2d lzfse zlib lz4 xz suitesparse-ordering libcxx zxing-cpp leptonica tesseract tessdata monocypher boringssl ggml ffmpeg-hevc libplist openssl ldid firmware-tools backports ffmpeg swift-bootstrap swift swift-runtime combine swiftui; do
    l=$(echo "$n" | cut -c1); mkdir -p "$W/.cache/xmake-global/.xmake/packages/$l"; cp -c -R "$M/.cache/xmake-global/.xmake/packages/$l/$n" "$W/.cache/xmake-global/.xmake/packages/$l/"
done
REVENANT_CACHE="$W/.cache" REVENANT_PREBUILT=kern0x1b/revenant REVENANT_PREBUILT_ONLY=llvm,swift,ld64,swift-runtime,libcxx ./xmakew f -P . -p iphoneos -a armv7 --component=Swift -y -v
./xmakew l -P . tools/prepush.lua
rm -rf "$W/.cache" "$W/build" "$W/.xmake"
```

The list is the set of packages that the `swift` job of CI installs (its log's `install <name> .. ok` lines). The configure
prunes the generations that the kept releases do not need, in this private store only. The Swift configure evaluates none of the
device Vision packages (zxing-cpp, tesseract, leptonica, tessdata); a device configure that selects `VisionBackports` requires
them by design, since `backports_requires` in `frameworks/Backports/tools/subset.lua` turns each archive into a requirement.
The removal line is the end of a task: the three folders are the worktree's own, and the main checkout's `.cache` is never
a target.

Measured on the replay change `e45fd10ba`, in a worktree with a fresh private cache, and set against run `41207675148` for
the CI column, since CI is not dispatched for this branch:

| | local | CI (run 41207675148) |
|---|---|---|
| clone of the store | 11 s, 4 MB of disk | none |
| Swift configure | 48 s, 34 package checks, nothing installed, 35 MB | `Configure the Swift component` 4 min 19 s, after 26 min 13 s of `Install the firmware tools` |
| prepush | 5 min 7 s: the lowered members 299 s, the other checks 8 s | the `quick` job did not exist yet |
| the round | 6 min 6 s for clone, configure and prepush | 41 min 25 s, of which the `swift` job 33 min 43 s |

The lowered members missed the cache: the worktree's Backports sources differed from the last run that the main checkout's
cache holds, and the check is keyed by the sources it reads. A hit takes about 2 seconds, measured on the main checkout's
cache. A configure that installed `combine` and `backports` again (the timed run after `-c`, offline) took 4 min 30 s.

Disk: `df` measured the clone and configure and prepush together at 48 MB, and the removal at 62 MB; `df` counts every writer
on the volume, so these are approximate. `du` reports the private cache at 7.6 GB, because it counts each clone at full size;
the blocks are shared with the main store.

## Reading a failed run

`./xmakew l -P . tools/ci_errors.lua <run-id|job-id>` reads the logs of a run, or of one job, through `gh api`, and for each
job that did not succeed prints the failed tests, the errors the log prints, and for each Swift module that failed its
first diagnostics. It keeps the probe output of configure and of the Swift overlay out of the list: the feature probes
under `build/.gens/**/probes`, the `libplist`, `-fuse-ld`, `generic.swift`, `libfoo.a` and `AR-NOTFOUND` lines of the
configure, and the `curl` 404 of a prebuilt that is looked up. Each saved log is in `.cache/scratch/ci/<job-id>.log`.
A test that expects a compiler to reject a file prints that rejection in a passing run too, so the failed tests list is what
says which errors matter.

`./xmakew l -P . tools/ci_swiftc_replay.lua <job-log> [module]` takes the `swiftc failed for <module> with:` line of a saved
log, maps the runner's paths to the local checkout and cache, sends the outputs to `.cache/scratch/swiftc-replay/<module>/`,
and runs the same compiler on the same arguments, so a Swift fix is checked in seconds. The compiler gets a fresh clang module
cache in that folder, as a runner starts with an empty one: the per-user cache of a developer's machine can hold two `.pcm`
variants of one module, and the compile then fails with `is defined in both`. It needs the local Swift package
and the lowered overlay `build/generated/backports/overlay/vfs.yaml` of the checkout, so it runs after the Swift component
has been configured here.

## Fetching a branch's artifacts

The latest run of a branch holds its artifact even when its `checks` job is red:

```
run=$(gh run list --workflow check.yml --branch <branch> --limit 1 --json databaseId --jq '.[0].databaseId')
gh run download "$run" --name backports-libraries --dir ".cache/scratch/ci/$run"
```

The download is scratch: delete it when the task ends. An artifact exists only for a run whose `backports` job reached
the upload, so a run that stopped earlier has none.

## What a warm push costs

Measured on one branch with no change to a package recipe, so every store and cache the jobs restore is a hit. The
baseline is the workflow as it was on `main`, and the after rows are the second run of the new workflow, when the
caches it creates are in place. The first run after a change to a cache key creates the new entries and costs more.

| Run | Wall time | macOS job-minutes | `checks` | `backports` | `swift` |
| --- | --- | --- | --- | --- | --- |
| baseline, `40044072531` | 14 min | 27 | 9 min 55 s | 7 min 40 s | 9 min 12 s |
| after, `40046661803` | 4 min 12 s | 10 | 4 min 12 s | 3 min 34 s | 2 min 13 s |

Before the gating, a push that changed only documentation still ran `checks` and `package` in full. Measured on
`40185450738` (a documentation-only change) the `checks` tests took 705 s and `package` took 1205 s, of which its
SwiftUI demo configure took 7 min 27 s and its build 11 min 18 s, so about 25 macOS minutes for a change that only
the repository checks read. Since the gating, such a push runs the `repository` job alone.

The baseline `checks` job spent 5 min 11 s in the firmware-tools configure, which installs nothing on a store hit: the
time is in the iOS configure itself, in a stretch where xmake prints nothing for about ten minutes on a host. The
change skips that configure when the inventory is cached, and `swift` skips it on a dyld hit, which removes it from
both jobs on a warm push. The first run after the change to the inventory and objects keys, `40045244974`, ran the
configure and the Backports build once; those entries are now cached.

## The emulator workflow

`.github/workflows/emulator.yml` runs the emulator on a runner, so boots, snapshots and measurements never fill a
local disk. It is dispatched by hand on `macos-26` and nothing else runs it: a worker dispatches a job, waits for it
once, and reads back the log and the numbers. GitHub dispatches only a workflow that is on the default branch, so
a branch's own edit to the workflow runs only after it is merged; a branch that is not merged yet cannot be dispatched.

Dispatch, wait once, and read the result, with the branch and the job:

```
gh workflow run emulator.yml --ref <branch> -f job=boot
run=$(gh run list --workflow emulator.yml --branch <branch> --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$run" --interval 600 --exit-status
gh run download "$run" --name "emulator-boot-$run" --dir ".cache/scratch/ci/$run"
```

The download is scratch: delete it when the task ends. A run is watched once, with that one command. A rerun is
dispatched again, never polled in a loop.

The jobs, chosen by `job`:

- `boot` boots the iPhone 4S on iOS 6.1.3 with `--time-scale 10 --perf-summary`, bounded by `ticks` CPU ticks (default
  `4000000000`, the bound of the boots in [the performance reference](../reference/emulator/performance.md)). The perf
  summary is `perf-summary.txt` and the emulator's stderr is `boot.log`.
- `measure` builds the emulator of `control` (a branch or a commit of `origin`, default `main`) in a worktree of the
  runner, then runs `rounds` pairs of boots of the control and of the branch, alternating which one goes first in each
  round. `measurement.md` has one row per boot: real, user and system seconds from `/usr/bin/time -l`, maximum RSS and
  peak footprint in MB. The table is also on the run's summary page, and each boot keeps its perf summary and log.
- `probe` runs the libdispatch connect probe (`emulator/tests/guest/connect_dispatch`) on the iPhone 4S with two guest
  cores and then with one. Each run keeps its log in `probe-cores-2` or `probe-cores-1` of the artifact, and the step
  prints the `connect_writable` lines. The step fails when the probe exits non-zero or prints nothing. The probe's guest
  package is configured against iOS 6.0, so before the probe the job restores the iOS 6.0 shared cache under the key
  `check.yml` uses, fetches it on a miss, and writes the iOS 6.0 inventory when it is missing.

The runner builds the emulator in release and takes the firmware it boots from the revenant `firmware` task: the iOS 6.1.3 shared
cache (key `dyld-shared-cache-6.1.3-armv7-v1`) and the root filesystem of the iPhone 4S (key
`firmware-rootfs-6.1.3-iphone4-1-v1`), under `.cache/dyld/6.1.3` and `.cache/firmware/rootfs/iPhone4,1`.
A boot clones the root filesystem, since the emulator writes its device state beside the one it boots.

The artifact `emulator-<job>-<run>` holds the logs, the perf summaries, the measurement table and any crash report of
the emulator. No run uploads the root filesystem or a snapshot. The steps print `df -h /` as they go, and the last
step measures the caches, so a run's disk use is read from its log.

The `snapshot` job (a save at N ticks, a restore and a comparison) and the `app` job (a guest bundle from an artifact)
are not in the workflow. The emulator has no restore of a machine state, only the design in
[the snapshot explanation](../explanation/emulator/snapshot.md), and `xmake emulate` installs only the packages of the
project's own targets, not a `.deb` from an artifact.
