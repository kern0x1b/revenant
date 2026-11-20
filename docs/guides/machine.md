# The machine: one cache, one clean

How a build uses this machine's disk, what the cache holds and how it is capped, and how to give space back.

## Two folders, two caps

Everything revenant writes outside its sources goes into two folders.

The **store** holds the packages: the pinned and patched xmake binaries and the package store (`XMAKE_GLOBALDIR`, with the
installs, the sources and the build folders of every package). It is one folder for the whole machine, `~/.revenant/store`
(`REVENANT_STORE` names another, as an absolute path), and every checkout and worktree reads and writes it, so a package
key is built once per machine and the absolute paths in an install never move (the section "The shared store" below).

The **cache** holds the rest: the shared caches of the firmware, the lowered caches, the emulator images, the token pool,
the scratch of each task. It is `.cache` in the main checkout and `.cache` in a linked worktree (git ignores both,
`.gitignore`); `REVENANT_CACHE` names another folder. `toolchain/modules/cache.lua` finds the checkout from any worktree
with `git rev-parse --git-common-dir`. `./xmakew` exports both folders it uses, so each tool and test it runs reads the
same ones, and it links `xmake` and `xmake-global` of the cache to the store, so a tool that reads
`<cache>/xmake-global/.xmake/packages` reads the store's.

The cache is capped at 50 GB, and the cap counts the build outputs as well: each `build/` and `.xmake/` that git ignores,
in the main checkout, in every worktree, and in every framework of each. `REVENANT_CACHE_GB` sets the cap in decimal
gigabytes. The store is capped at 80 GB (`REVENANT_STORE_GB`) and counts nothing else. The size is counted with `du`,
which counts an APFS clone at its full size although the clone takes no room; the count can be above what the disk holds,
so a write can be refused that would fit.

Each folder falls in one of these classes. The rows that begin `xmake/` or `xmake-global/` are folders of the store, the
others of the cache. Only the package, generation, source, scratch and build classes can be evicted, and only to make room for a write:

| Folder | What it is | Class |
| --- | --- | --- |
| `xmake/<key>` | the pinned and patched xmake, one folder per pin and patch set | kept |
| `xmake/<key>.build.*`, `xmake/<key>.log` | xmake's build folders and logs from `xmakew` | scratch |
| `xmake-global/.xmake/packages` | the package store: a package's folder, its link `<hash>`, and its install generations `<hash>.g<token>` | package, generation |
| `xmake-global/.xmake/cache/packages/<yymm>/<letter>/<package>` | the package sources and build folders, one folder per package | source |
| the rest of `xmake-global/.xmake/cache` | xmake's other caches | scratch |
| the rest of `xmake-global/.xmake` | the repositories and xmake's state, through `XMAKE_GLOBALDIR`, which `xmakew` sets to the store's `xmake-global` | kept |
| `roots/*.txt` of the store | the installs that other tools build against and that must stay (below) | kept |
| `scratch/<task>` | the scratch of one task, written by the task and deleted when it ends | scratch |
| `dyld/<release>` | the shared caches and libraries of each iOS release, taken out of decrypted firmware; 6.1.3 and 6.0 are kept, other releases are scratch | kept or scratch |
| `firmware/rootfs/<device>/<release>_<build>` | root file systems; 6.1.3 and 6.0 are kept, other releases are scratch | kept or scratch |
| `firmware/work` | extraction work | scratch |
| the rest of `firmware` | the firmware catalogue and downloads that resume | kept |
| `emulator/images.noindex/<owner>/<identifier>_<build>` | emulator images cloned from a golden root file system | scratch |
| `<worktree>/build`, `<worktree>/.xmake`, `<worktree>/frameworks/*/build` | the build outputs of each worktree, which git ignores | build, evicted like scratch |
| `emulator/cache.noindex/<device>_<build>` | the host cache of one emulator image, shared by every run of that image | scratch |
| `emulator/tmp.noindex` | TMPDIR folders left by older runs; runs now keep theirs in their run folder | scratch |
| the rest of `emulator`, including `golden.noindex` | golden images, which took a first boot to make | kept |
| `emulator-slots` | the lock files that bound how many emulators run at once; a held lock file must stay | kept |
| `devices` | which run holds which device | kept |
| `cache-index` | the index of `dyld`, which its readers find beside it | kept |
| `budget` | the token pool of the machine and its queue of waiting commands (`tools/budget.lua`); a held lock file must stay | kept |
| `corpus` | data read from applications and devices | kept |

`REVENANT_EMULATOR_ROOT` and `REVENANT_CORPUS_ROOT` name folders elsewhere for the emulator and the corpus; those folders
are not counted in the cap.

## When a write does not fit

Before a large write, the code that makes it reserves its bytes first: a prebuilt download (its `Content-Length`), a
prebuilt install (the size it unpacks to, from `xz --robot -l`), a firmware download (the firmware's size, for each
attempt), a root file system (three times the firmware, since the image expands), and an emulator clone (the size of the
image it copies, a conservative figure since a clone takes no room).

If the write would take the cache past the cap, entries are evicted whole, in this order, least recently used first
within each group, and stopping as soon as the write fits:

1. package generations that are not their package's current install;
2. the sources of packages, one package folder at a time;
3. scratch;
4. the build outputs of each worktree;
5. installed packages, last, and only when the groups before them cannot make room.

An evicted entry takes its lock files with it, and each folder of the package store that it leaves empty, so that nothing
is left for xmake to take for an install. An entry with a file open in some process is never evicted, and if `lsof` cannot list the open files nothing is evicted.
If the write still does not fit once nothing more can go, it fails before anything is removed. The message names the
write, the cap, and the five biggest entries.

The package store keeps at most one previous generation of each package, and the firmware keeps only 6.1.3 and 6.0, and
only armv7 within them. The daily sweep and `tools/cache.lua prune` remove what is beyond that, in the store and in the
cache.

The store has its own cap and the same order of eviction, and it never evicts what a roots file names. A tool that builds
against particular installs (the Bazel build of Telegram links the ones in its `bazel/store-pins.txt`) gives the store a
file `roots/<name>.txt`, one install per line, the path under `xmake-global/.xmake/packages` (`s/swift-runtime/6.4.0/<hash>.g<token>`
for one generation, `s/swift-runtime/6.4.0/<hash>` for a package and its current generation), blank lines and `#` comments
allowed. A listed generation, or a package, is pinned: neither eviction nor `prune` removes it, and `status` marks it
`(pinned)`. A symbolic link `roots/<name>.txt` to the tool's own file keeps the list in the tool's repository. If a write
could be made to fit only by evicting a pinned install, it fails and removes nothing of it.

## A build and an emulator run

Before a build starts (`./xmakew f -P .`, `build`, `rebuild`, `test`, `install`, `run`, `package`, `deb`), `xmakew` runs
`tools/cache.lua guard`. It reserves the room the build is expected to add: the size its worktree's build outputs had
after the last build, less what is there now, and 2 GB before the first build. A build that cannot get that room
does not start. After the build, `tools/cache.lua record` stores the worktree's build-output size for the next guard. A
build that grows beyond its reservation is caught at its next start. The guard also keeps the store within its cap, at
most once in ten minutes (the stamp `.cap-checked` in the store), because counting the store with `du` takes as long as
the store has files.

An emulator run clones the golden root file system, which reserves the full size of the image first, so a run whose
clone would pass the cap does not start. Its TMPDIR is `tmp` inside its run folder. When the run ends, pass or fail,
its root file system clone, its TMPDIR and its runtime folders are removed, unless `--keep` is given; the run folder
keeps its results and verdict. `emulator.remove` makes the files writable before it removes them, and a removal that
fails raises.

## Status and prune

    ./xmakew l -P . tools/cache.lua status
    ./xmakew l -P . tools/cache.lua prune [--dry-run]

`status` prints the cache and then the store: the folder, the cap, what is used, and each entry with its size, class, last
use, `(in use)` when a process has files open in it, and `(pinned)` when a roots file names it. `prune` removes the package
generations beyond the one previous, and the firmware the configured releases do not need.

## One clean

    ./xmakew l -P . tools/clean.lua [--dry-run]
    ./xmakew l -P . tools/clean.lua --packages [--dry-run]
    ./xmakew l -P . tools/clean.lua --all [--dry-run]

| Level | Removes | Keeps |
| --- | --- | --- |
| default | each worktree's ignored `.xmake` and `build`, every tool cache and scratch folder of the cache | the store, the kept folders |
| `--packages` | the same | the store, the kept folders |
| `--all` | everything under the cache, the kept folders included, and its links to the store | the store |

Only ignored and untracked build folders are removed: `git check-ignore` decides. The store is shared by every checkout
of the machine, and a build in another worktree may be using a source or build folder in it, so `clean` never removes
from it; `tools/cache.lua prune` and the cap remove from it, and never what a process has open or a roots file names.

## Scratch: kept while it is used, removed when it is not

`./xmakew` sweeps the scratch of finished tasks by itself, at most once a day, and prints what it freed:

    ./xmakew l -P . tools/clean.lua --scratch [--dry-run]

The sweep is `--scratch`, and it is safe while workers run. It removes a folder `scratch/<name>` only when all three hold:

- no live worktree is named after it: the names come from `git worktree list` of the checkout, and the checkout's own
  name is always kept;
- nothing in it was modified in the last 7 days (`find -mtime`);
- no process has a file open in it (`lsof -F n` lists every open path once, and the folder is matched against them).

In the same run it removes the package generations beyond the one previous, and the firmware the configured releases do
not need (`tools/cache.lua prune`), with the same open-file check. It touches nothing else: not the xmake binaries, the
package store and its locks, or the kept folders. If `lsof` fails, nothing is removed. The sweep records its run in
`.cache/.scratch-swept`, and the wrapper runs the sweep again only when that file is more than a day old.

Seven days: a paused task, a weekend, or a worker that has come back to a branch keeps its scratch; a folder that no
live worktree names and that nothing has touched for a week is rebuilt in minutes if it is needed again.

The freed size is the change in free space on the volume, read with `df` before and after the sweep, not the sum of
`du`. Clones share their blocks, so `du` counts a clone's full size although it frees nothing. Measured on this volume
with a 300 MB file:

| Copy | Free space it took | `du` reports |
| --- | --- | --- |
| `cp -p` | 300 MB | 300 MB |
| `cp -c -p` (clonefile) | 0 MB | 300 MB |
| `ditto` on the same volume | 0 MB | 300 MB |
| `cp -c` from a mounted disk image | 5 MB | not measured |

So a clone is made only on the same volume, and a copy from a disk image is always real. Every emulator image is a
clone (`emulator.clone` is `cp -c -R`), and the files the emulator copies into its image use `cp -c -p` too. The
firmware's root filesystem is copied once per release out of its disk image, with `ditto`, and no clone can be made
from there; each emulator image after that is a clone of it.

## The shared store

**There is one package store per machine, and a worktree needs no clone of it.** Until 2026-11-20 each worktree had a
cache of its own with a store inside, made by cloning another one with `tools/private_cache.lua`: 75 stores on one machine,
the same keys built two to four times (libcxx three times in a morning), 16 million files that every create and delete
passed through the file-system event daemon, and a cold build of every package, 63 minutes on 2026-11-16, when a cache was
made by hand. The store is one folder at a fixed path, so an install's absolute paths (a CMake cache, a manifest, a
pkg-config file) are the same for every worktree and never need to be rewritten.

`./xmakew` takes the store from `REVENANT_STORE` (an absolute path) or `~/.revenant/store`, builds the pinned xmake into
`<store>/xmake/<key>` once for the machine, runs it with `XMAKE_GLOBALDIR=<store>/xmake-global`, and links `xmake` and
`xmake-global` of the cache to those. A linked worktree takes `<worktree>/.cache` for its cache when `REVENANT_CACHE` is
unset, and any folder `REVENANT_CACHE` names, empty or not, with no marker. What it holds is small: the token pool, the
scratch of its tasks, the lowered caches, and (when a task needs them) `dyld` and `firmware`.

Two builds of one package key never run at once, because the install is locked by its folder (`<installdir>.lock`); two
different keys of one package, built at once by two processes, each patch and build in their own copy of the sources
(`checkout.keyed`, [ADR 0018](../explanation/decisions/0018-source-folder-per-build.md)).

**A cache from before the store is refused**, because a real `xmake-global` in it would be read by the tools that read it
beside the store's, and it is not the store's. `xmakew` stops and names two ways out: remove the folder (the installs come
again from the prebuilt releases or are built once), or make that cache the store while the store does not exist yet,
which keeps its installs and the generation names a roots file pins:

```
REVENANT_CACHE=<an empty folder> ./xmakew l -P . tools/private_cache.lua ~/.revenant/store --from <the old cache> --only xmake,xmake-global
```

The tool clones the two folders `--only` names with APFS clones (without `--only` it clones the whole cache) and rewrites every absolute link, every `CMakeCache.txt` and the text state under
`xmake-global/.xmake/cache` to name the store, then writes its `.private-cache` marker. It refuses a destination that exists
and is not empty, inside the source or holding it, or on another volume. A clone is only as warm as its source: choose the
cache that holds the packages the pins and the tasks need, and read `status` of the store before using it. Its older
`xmake/<key>` binaries come with it, and the key of this `xmakew` is built beside them on first use.

### What a new cache lacks

A new cache has no `dyld` and no `firmware`; a task that reads them fetches them (the iOS 6.0 shared cache, the firmware
catalogue), or the worker clones them from a cache that has them with `cp -c -R -p` (an APFS clone) before the first run:

- `<source>/dyld/6.1.3/classes_armv7.json` exists. The Backports generator decides from that file which SDK classes get a
  proxy and stops without it; a cache that has only `dyld/6.0` once produced a skeleton from the wrong release's inventory
  (a `MapKit` proxy that the 6.1.3 device does not need).
- For the device runtime tests, `<source>/firmware/rootfs/iPhone4,1/6.1.3_10B329` exists. A cache without it runs every
  `backports_runtime` case as failed (measured 2026-11-19, all cases of the group), because the emulator has no root file
  system to boot. A missing one is cloned from a cache that has it with `cp -c -R -p` (an APFS clone, no second copy on
  disk), before the first run.
- `df -h /System/Volumes/Data` after a clone: a clone costs little until it is written to, and the floor of the disk rule
  holds.

`tools/private_cache.lua` is now the way to seed the store once, and nothing a worktree does at its start. Without `--only` it
takes the whole of the source cache except five folders that hold the state of the machine and of the tasks that were running in the source:
`budget` (the token pool), `devices` (which run holds which device), `emulator-slots` (the locks that bound how many
emulators run at once), `scratch` (the scratch of the tasks running there) and `sizes` (the measured sizes of the source's
paths, which would be wrong for the clone). The new store therefore claims no device and no emulator slot of the source.

An absolute link into the source is pointed into the clone; a relative link, or a link to a path outside the cache, is kept.
A link into one of the five left-out folders stays dangling in the clone, and the tool reports those apart from the links
that were already dangling in the source. A `CMakeCache.txt` has every source path replaced with the clone's path. Other
files that name the source are copied unchanged, since the tool does not look for them. After the rewrite it checks that no
link and no CMake cache still names the source; if one does, it removes the clone and fails.

The tool refuses a destination that exists and is not empty, one inside the source or holding it, and one on another volume,
where a copy would take the full size of the source. The destination is the store, so the roots file of a project that pins
generations by name (Telegram's `bazel/store-pins.txt`, linked into `<store>/roots/`) keeps naming installs
that exist in it.

```
./xmakew l -P . tools/private_cache.lua --remove <folder>
```

removes a folder only when it holds the `.private-cache` marker that the tool wrote, and never the folder that holds the
checkout. Never run it on the store while a roots file names its installs: `tools/cache.lua` drops a part no root names when
the cap is reached, and nothing else deletes from the store. Apple's directories are copied read-only, so removal makes the
directories writable before it deletes them, and it does not follow links.

## Build each package once

A package's key is its build hash: the platform, the architecture, its configs and the toolchain names.
The large packages put a digest of the files that make their output into a readonly config, so the key
changes exactly when those files do. Regenerate the digests as the last step before a commit: a digest is a
function of its inputs at the time it runs, so an input edited afterwards (a source, a tool, or a generated list
such as `frameworks/Backports/tools/lowered-members.txt`) leaves it stale, and `digest_test` fails. The packages that carry one:

| Package | Digest config | Made from |
| --- | --- | --- |
| `swift-runtime`, `libcxx` | `recipe` | `port/digest.lua` in each recipe folder, which `toolchain/tools/recipe_digests.lua` writes from the recipe and the modules it runs |
| `llvm`, `swift` | `recipe` | the recipe and its patches |
| `dynarmic` | `recipe` | the recipe; its patches are in the build hash, see below |
| `swift-bootstrap` | `recipe` | the recipe; the swift.org package is held by the version's sha256, outside the digest |
| `iphoneos-sdk` | `additions` | what the recipe adds to the SDK |

`swift-runtime`'s digest does not take the whole member set (`lowered-members.txt`, `device-members.txt`). The runtime
builds against the SDK headers lowered for iOS 6, and most members lower headers it never reads, so a member of an
unrelated framework would rebuild it for nothing. The digest holds what the build reads instead:
`toolchain/src/swift-runtime/reads/lowered-reads.txt` lists every SDK header the runtime build reads, lowered or not (one
SDK-relative path a line), and the digest hashes the lowered text of exactly those headers (and of the lowered
`.apinotes` files) next to the recipe and its modules. A header that is outside the list and lowers at all is replaced in
the runtime's overlay by an `#error` that names it, so a read the list lacks fails the build and cannot go unkeyed. The
Swift overlays (`Foundation`, `AVFoundation`) are lowered from the pinned swift sources by looking names up in the member
set: `toolchain/src/swift-runtime/reads/swift-overlay-reads.txt` lists every lookup the lowering makes (`name <key>` or `type <key>`),
the digest hashes the answers to exactly those, and a lookup outside the list fails the build. A build of the armv7
runtime also fails when a listed lookup was never made (the arm64 build skips `AVFoundation`, so it does not check), so
the list cannot keep a lookup the lowering has dropped. After a change that
adds a read, run the runtime build once with `REVENANT_RUNTIME_READS_RECORD=<folder>` to record the lookups, copy
`swift-overlay-reads.txt` from the folder into `toolchain/src/swift-runtime/reads/`, add the header the `#error` named to `lowered-reads.txt`, and
run `toolchain/tools/recipe_digests.lua`, which needs the SDK package and takes about a minute the first time for a changed member set
(the lowered text of the listed headers is cached under `runtime-reads/` in the cache home, keyed by the SDK's content and
not by its path). The recording switches the lookup check off, so `prebuilt.pack` refuses to pack an install made with
`REVENANT_RUNTIME_READS_RECORD` set: build it again without the variable before releasing.

A change to documentation rebuilds nothing. `./xmakew l -P . tools/keys.lua [package ...]` prints each package's
version and the key its prebuilt archive is released under, `prebuilt-<package>-<key>`. The key is computed by
`prebuilt.key` in `toolchain/modules/prebuilt.lua`, the function that fetches and archives the package, and it follows
the project's configuration: configure as CI does before asking for `swift-runtime` or `libcxx`, with
`./xmakew f -P . -p iphoneos -a armv7 --component=Swift -y`. Run it before and after a change to see what the change rebuilds.

`swift` is outside `swift-runtime`'s key, although `swift-runtime` is built with it. `swift-runtime` takes `swift` as a
host, private dependency (`packages/s/swift-runtime/xmake.lua`), and the key hashes only library dependencies, which for
`swift-runtime` are `apple-compat` and `libcxx`. Its digest covers its own recipe and sources, not `swift`'s. Both pin the
same version, 6.4.0, and a swiftmodule is accepted only by the compiler whose version string it carries, so a swift
change that leaves serialization and the runtime ABI alone leaves what `swift-runtime` builds where it was. A swift patch
that changes serialization or the runtime ABI would bring `swift` in: `swift-runtime` would then take `swift` as a
library dependency, so its archive moves with the compiler it was built for.

The build hash has three more terms, one for the xmake that builds the packages, one for the addons a build runs
under, and one for each package's own patches.

The first covers revenant's xmake patches. Each patch in `packages/x/xmake/patches` declares in its header whether it
can change what a build produces, with `Changes-build-output: yes` or `no`; `xmakew` takes the xmake
commit and the patches that say `yes` and writes the digest to `share/xmake/revenant-patch-set` beside the binary,
and patch `0020` folds it into every variant of the hash. A patch marked `yes` moves every package's key once, so an
unmarked patch moves none. A binary without the file refuses to compute a build hash. No patch is marked now: the
addon patches `0001` to `0003` and `0005` to `0007` change which addon version a build loads, which the second term
keys, and `0015` publishes an install under its generation path, which is the store's design and the same for every
build with a key; the others change locks, job counts, warnings, process waits, manifest checks, exports, fetches, the
Lua parser or the keys, and no build output.

The second term, from patch `0022`, covers the addons a build runs under. A package's recipes run the code of the addon
version the project pins: the installed addons which the process pins are in the hash, by name and version, for
example `revenant@v0.8.10` for a project that locks that release. An addon from a folder of the project, as this
repository's `xmake.lua` declares revenant (`add_addons("revenant", {sourcedir = "toolchain"})`), has no version and
adds nothing, and a process which pins nothing keeps its keys. Two versions of one addon therefore build two installs.
A project which locks an installed addon moves its keys once; a normal build of this repository loads the folder and
moves none.

The third term covers each package's own patches: the sha256 of every patch the package applies at its version, in
order, from patch `0021`. A package with patches moves when one changes, and a package without patches does not.
Before this term, two recipes at one version
with different patches shared one install, and the second project got the first one's patched files. The source
directory was never the cause: a git checkout is reset and its patches are applied again for each install.

At the latest version the packages with patches are `boringssl`, `combine`, `dynarmic`, `farmdec`, `ffmpeg`, `ldid`,
`openssl`, `rellume`, `swiftshader`, `webkit` and `xmake`. `iphoneos-sdk`'s patch applies to 16.4 only. `llvm`, `swift`,
`swift-runtime` and `libcxx` declare no `add_patches`, so the term leaves their keys alone.
`toolchain/tests/addon/patch_set_test.lua` checks the digest against the recipe's marked patches, the moves and the
refusal, the per-package term, including a patch declared without a sha256, and the addon term: a pinned version moves
the key, an installed addon which nothing pins and a folder of the project do not.

Two requests for one package build it once: xmake locks each package's cache folder while it fetches or
installs, and checks again after the lock whether the package is installed (patch `0009` does the same for a
reinstall a changed dependency causes; patch `0010` waits for a lock without stopping the process's other jobs).
An install builds into a generation folder beside the package's folder, `<hash>.g<token>`, and publishes it by
swapping the link `<hash>` to it in one rename (patch `0015`). A reader of the store takes no lock, and what it may
assume depends on how it reads. A reader that resolves `<hash>` once and reads every file of the install from the
generation it resolved sees the old install or the new one, whole, for as long as its reads last within the grace
period below. A reader that resolves `<hash>` again for each file can read files of two generations across a publish,
so a reader that needs one install resolves it once. A failed install leaves the published one as it was.
The generation a publish replaces stays for a grace period, `REVENANT_GENERATION_GRACE` seconds (an hour by default),
counted from the time it was replaced. So a path into it still reads through two publishes that come within the grace.
After the grace it is removed at the next publish, and reading a file under it fails with "cannot open file" rather
than returning old files. A consumer that keeps a generation's path, such as a CMake config it cached, must reconfigure
once the grace has passed after two installs of the package. The hour is the longest CI run on main, 48 minutes, with
margin; a read longer than the grace is not protected. Export copies the files the link names (patch `0016`), and
import publishes them the same way, so an exported package imports whole.

The emulator's golden images under `golden.noindex` follow the same design (`toolchain/modules/generations.lua`). That
module is a copy of the store's design in its own words, not shared code: the store's code is methods of xmake's package
instances, which a toolchain module cannot call, so the two are kept to one design by the tests rather than by one
implementation. Two things differ on purpose. A golden image's build lock `<name>.build.lock` goes with its name once
nothing of the name is left; a session that was blocked on the old lock file when it went can build the same golden
image once more, and since each build holds its generation's lock from its start to its publish, a sweep does not remove
that build's generation, and the publish stays atomic, so no reader sees a partial image. A real golden folder from
before generations keeps its reader lock, `<name>.lock`, which moves aside with the folder, so a reader that holds it
keeps it.

Two crutches are left in the store generation work. A process that dies between the fetch that validates a staged
install and the fetch after its publish leaves the generation path in the detect cache until the next install of that
package (patch `0017`). The store race test (`toolchain/tests/addon/store_race_test.lua`) reads the include and library
folders only, so the bindir, rpath and pkgconfig paths of a package have no test.
LLVM and Swift cap their link jobs at one for each 10 GiB of memory (`toolchain/modules/parallel.lua`,
`REVENANT_LINK_JOBS` overrides it).

## The Telegram 13.0.0 chain

Telegram 13.0.0 for iOS 6.1.3 on armv7 (iPhone 4S) is built by the Bazel overlay in telegram-build, and the chain it
rests on runs through this checkout in five links.

1. **The Swift runtime.** `packages/s/swift-runtime` builds the runtime's libraries and overlays from pinned sources:
   the compiler from swiftlang/swift at `b8189d766`, and the overlays of CoreMedia, Photos, AVFoundation, MediaPlayer and
   CoreAudio from the uikit checkout at `swift-5.2.5-RELEASE` (`71d85a7c`), a sparse checkout of those directories. The Photos overlay
   declares `PHChange` at the build's minimum, not at the release the SDK gives it (`build_overlay` in the recipe);
   the armv7 Photos interface copy in `toolchain/modules/apple/lowered.lua` does the same, from the triple.
2. **The lowering.** `toolchain/modules/apple/lowered.lua` writes the armv7 copy of the SDK headers and Swift interfaces
   (the members listed in `frameworks/Backports/tools/lowered-members.txt`), so the code that Telegram compiles sees
   the backported declarations. The lowered VFS is generated per SDK.
3. **The dyld check.** `toolchain/modules/apple/runtime_guards.lua` names, for every symbol a dylib imports that the
   device's iOS 6 cache lacks, the source that provides it. A strong import must resolve in the device cache; a weak
   import needs a guard row. Frameworks the device lacks are linked weak (`-weak_framework`).
4. **The generator.** `tools/bazel-overlay.lua` in telegram-build lowers the SDK from the revenant commit being built:
   the HEAD of the revenant checkout, or the commit `REVENANT_COMMIT` names. That commit must be on a remote branch,
   because the snapshot and the generated files name it; `tools/revenant_commit.lua` refuses an unpushed one. The
   swift-runtime install used is the one whose `references.txt` names the snapshot (`tools/store_reference.lua`), so a
   newer install built from another commit is never picked up.
5. **Bazel.** `tools/bazel-build.lua` builds the targets listed in an absolute file (`BAZEL_TARGETS`); pass 53 is
   `//Telegram:Telegram`. A build succeeded only when the log ends with `bazel exit 0`; the wrapper's own exit code is
   not the result.

Each recipe's `port/digest.lua` is regenerated by `toolchain/tools/recipe_digests.lua`, and `tools/prepush.lua` checks
the digests, the lowered members and the comments before a push.

## The budget: one pool of tokens for the machine

A token is one core and 1.5 GB (`TOKEN_MB` in `tools/budget.lua`). The heavy commands of every worktree take their tokens from
one pool, kept in `.cache/budget` of the main checkout whatever `REVENANT_CACHE` names, so the pool is the same for all of them:

    ./xmakew l -P . tools/budget.lua run [--class critical|normal|background] [--jobs N] [--min N] [--mb M] -- <command> [args...]
    ./xmakew l -P . tools/budget.lua status
    ./xmakew l -P . tools/budget.lua test

- Size. The pool holds at most the cores less two. A request is granted no more than the room the machine has: the free and
  inactive memory (`vm_stat`) less 2 GB, in tokens, and the cores `top` reports idle plus the tokens already held. A command
  starts with one token even on a saturated machine. After five minutes of waiting (`REVENANT_BUDGET_PATIENCE`, in seconds)
  the idle cores no longer hold it back; the memory still does.
- Need. A command asks for `--min` tokens (one by default), or for the tokens its `--mb` needs when that is more (a 2.5 GB class
  takes two), and for up to `--jobs`. It runs with `XMAKE_MAX_JOBS` set to the tokens it got.
- Order. Waiting commands queue by class: `critical` (the checks before a push), `normal` (the default, which every `./xmakew`
  build, test, configure, install, run, package and deb uses) and `background`. Within a class the first to wait goes first.
  A request waits behind a live request ahead of it; a request whose process died is removed from the queue.
- Nice. `critical` keeps its priority, `normal` runs under `nice -n 5`, `background` under `taskpolicy -b` and `nice -n 15`.
- Release. A token is a lock on a slot file, and the kernel releases it when its process ends, `kill -9` included. The command
  is started with the descriptors of the slot files closed, since a child that kept one would keep the token after its parent died.
- Nesting. A command under a budget gets its count in `REVENANT_BUDGET_HELD`. A budget run below it takes no tokens of its own,
  so a `./xmakew` started by a build waits for nothing and is bounded by the build's tokens.
- Disk. No command starts while the volume of the checkout has less than 100 GB free (`REVENANT_BUDGET_DISK_GB`).

A command run straight with `xmake`, and not through `./xmakew` or a budget run, takes no tokens.

## Checks that remember their result

`./xmakew l -P . tools/prepush.lua` remembers each check that passed, in `.cache/prepush`, under the key of the check's inputs:
the commit `HEAD`, every tracked file and every untracked file that git does not ignore (its blob id, or its content when it
differs from the index), the environment except the shell's bookkeeping (`PWD`, `OLDPWD`, `SHLVL`, `_`, `COLUMNS`, `LINES`,
`TERM_SESSION_ID`, `SECURITYSESSIONID`), the xmake that runs the check, the host, and the check's name. A check runs again
when any of them changes; a check that failed is never remembered. None of the checks reads a file that git ignores, so an
ignored file is not part of a key; a check that starts to read one must say so in `tools/prepush.lua`.

`backports build` configures the Backports component for iphoneos armv7 and builds every one of its libraries, with the flags
of the package, so a source the `backports` package cannot compile (a `-Werror` of `frameworks/Backports/xmake.lua`, a missing
header, a link error) stops the push and not the build of an application that requires the package. The check works in a copy of
the checkout, `build/backports-gate/tree`, which `rsync -a --delete` brings up to date from the checkout on every run (git, `.xmake`,
`build`, the caches and `.claude/worktrees` stay out), so the host configuration of the checkout stays what it was and
`./xmakew test -P .` still runs. The copy keeps its own `.xmake` and `build`, so a later run compiles only what changed. A shared
`XMAKE_CONFIGDIR` would not do: the configure starts nested xmake processes that inherit it and wait on the project lock the
configure holds. The check takes the prebuilt `llvm`, `swift` and `ld64` of `REVENANT_PREBUILT` and `REVENANT_PREBUILT_ONLY` when the
environment names them (`kern0x1b/revenant` and `llvm,swift,ld64` otherwise), and fails rather than building them from source. It reads
the package store, the iOS 6.0 shared cache and the lowered cache of `REVENANT_CACHE`, which are caches and not part of its key. On
a failure it prints the compiler's errors and the path of the whole log, `build/backports-gate/prepush.log`. The first run builds
all libraries (about six minutes on a 12-core Mac), a later one only what changed, and a run on an unchanged tree is remembered like the
others. `./xmakew l -P . tools/ci_local.lua backports` runs the same build from a fresh configuration and goes on to the Backports
tests, the probe app and the exports check.

Order and flags. The cheap checks run first and the heavy ones (`lowered members`, `lowered exports`, `light suites`,
`backports build`) last, and the run stops at the first check that fails, so a two-second `layout` failure does not wait
behind a build. `--keep-going` runs every check regardless (the old behaviour), `--list` prints the names with the heavy ones
marked, and `--only <check,...>` runs just those (names with a space are quoted: `--only "layout,light suites"`) for iterations;
an unknown name is an error, and a run with `--only` says that a push needs all checks. The full run before a push stays
without flags. Keep the caches (`.cache`/`REVENANT_CACHE`, `build/backports-gate`) between runs: a cold `backports build`
took 48 minutes on 2026-11-16 and a warm one 58 seconds, and a deleted cache leaves references in the checkout's `.xmake`
that make a later check fail, so remove `.xmake` together with a cache it names. The gate's copy stays per checkout: its
own `.xmake` records the cache paths of the run that configured it, so a copy shared between checkouts would point at another
checkout's cache.

Where a cold `backports build` spends its time (2026-11-16, 63 minutes by the install times of the packages): the packages
46 minutes (`libcxx` 10, `tessdata` with every language 12, `openssl-host` 5, `tesseract`, `leptonica`, `zxing-cpp`,
`ffmpeg-hevc` and `boringssl` about 12 together, `ld64` 2.5), the Backports libraries 17. Only `llvm`, `swift`, `ld64` and `libcxx` of
these have a prebuilt hook (`docs/guides/prebuilt.md`); the rest build from source on a machine without the cache, which is why a
warm cache is kept.

`recipe digests` is never remembered: it regenerates the digests and compares them with the committed ones, so it runs on
every prepush, and a second prepush on the same tree runs only that check. `./xmakew l -P . tools/prepush.lua test` checks the
keys: an edit, an untracked file, a deleted file, an environment variable and a new commit each change a key, restoring them
restores it, and a failing check runs again.
