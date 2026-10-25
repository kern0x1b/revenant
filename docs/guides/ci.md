# Continuous checks

`.github/workflows/check.yml` runs on every push to any branch, and on demand from the Actions tab or with
`gh workflow run check.yml --ref <branch>`. All of its jobs but one run on `macos-26`: an `ubuntu-latest` job named `changes`
decides from the diff against the merge base with `main` which of them a branch push needs, and a public repository
runs five macOS jobs at a time, so a job whose inputs did not change is skipped:

- a change that touches only `docs/` or a Markdown file at the top of the repository runs `repository` alone, which is
  `./xmakew test -P . 'repository/*'`: the layout and documentation checks that read those files;
- `checks` runs for every other change;
- `backports`, `package` and `swift` run only when the change reaches the native builds: a change outside `docs/`,
  `emulator/`, `recompiler/`, `toolchain/tests/emulate/` and Markdown. Those folders never reach the native builds.

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
  missing release of either is an error.

The checks run on macOS, not Linux: the suites compile with the Mac's clang and the emulator is a macOS program. Every
test in the default run must pass, so the `checks` job is red when one of them fails, and no test is skipped in CI
by a list of names.

Four caches make a warm run quick:

- the pinned xmake binary, keyed by `xmakew` and `packages/x/xmake`;
- the package store `~/.revenant/cache/xmake-global`. The backports job keys it by the output of
  `./xmakew l -P . tools/keys.lua iphoneos-sdk ld64`, so only a change to those two packages makes a new key. The checks job
  keys its own store by the files that decide what it installs: the xmake recipes of the packages, the third-party
  packages the default tests build, `toolchain/modules/prebuilt.lua`, and the component files that declare requirements.
  A store is restored by its exact key, or else by the newest store with the same prefix (`restore-keys`), so xmake
  installs only the packages whose own build hash is new. A store is saved only when the configure log shows an install,
  so a warm run writes nothing back, and a store is saved after the configure has succeeded, never half-made;
- the iOS 6.0 inventory `~/.revenant/dyld/6.0/classes_armv7.json`, keyed by the firmware code that writes it
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

## Fetching a branch's artifacts

The latest run of a branch holds its artifact even when its `checks` job is red:

```
run=$(gh run list --workflow check.yml --branch <branch> --limit 1 --json databaseId --jq '.[0].databaseId')
gh run download "$run" --name backports-libraries --dir "$HOME/.revenant/cache/ci/$run"
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
gh run download "$run" --name "emulator-boot-$run" --dir "$HOME/.revenant/cache/ci/$run"
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

The runner builds the emulator in release and takes the firmware it boots from the revenant `firmware` task: the iOS 6.1.3 shared
cache (key `dyld-shared-cache-6.1.3-armv7-v1`) and the root filesystem of the iPhone 4S (key
`firmware-rootfs-6.1.3-iphone4-1-v1`), under `~/.revenant/dyld/6.1.3` and `~/.revenant/firmware/rootfs/iPhone4,1`.
A boot clones the root filesystem, since the emulator writes its device state beside the one it boots.

The artifact `emulator-<job>-<run>` holds the logs, the perf summaries, the measurement table and any crash report of
the emulator. No run uploads the root filesystem or a snapshot. The steps print `df -h /` as they go, and the last
step measures the caches, so a run's disk use is read from its log.

The `snapshot` job (a save at N ticks, a restore and a comparison) and the `app` job (a guest bundle from an artifact)
are not in the workflow. The emulator has no restore of a machine state, only the design in
[the snapshot explanation](../explanation/emulator/snapshot.md), and `xmake emulate` installs only the packages of the
project's own targets, not a `.deb` from an artifact.
