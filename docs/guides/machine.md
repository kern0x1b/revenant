# The machine: one cache, one clean

How a build uses this machine's disk, what the cache holds and how it is capped, and how to give space back.

## Two folders, two caps

Everything revenant writes outside its sources goes into two folders.

The **store** holds the packages: the pinned and patched xmake binaries and the package store (`XMAKE_GLOBALDIR`, with the
installs, the sources and the build folders of every package), and the lowered SDK overlays (`lowered/<digest>`, one per
input, built once for the machine, so the packages that link one all point at the same absolute path). It is one folder for the whole machine, `~/.revenant/store`
(`REVENANT_STORE` names another, as an absolute path), and every checkout and worktree reads and writes it, so a package
key is built once per machine and the absolute paths in an install never move (the section "The shared store" below).

The **cache** holds the rest: the shared caches of the firmware, the emulator images, the token pool,
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
| `lowered/<digest>` and `lowered/<digest>.lock` of the store | the lowered SDK overlay of one input and the lock held while it is built; an overlay that is gone is built again by the next call | scratch |
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
The list of open files is a snapshot, so eviction also takes the entry's lock files (`<installdir>.lock`, `<sourcedir>.lock`) for
the moment of removal: an entry whose lock another process holds, an install or a source folder in use, is skipped and the
next candidate goes instead.
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
the store has files, and in one process at a time (`<store>/.trim.lock`: a process that finds it held leaves the trim to the
holder). A store that cannot be brought under `REVENANT_STORE_GB`, because what is left is pinned or in use, is reported
and the build goes on; only the room for the worktree's own build can stop it.

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
`<store>/xmake/<key>` once for the machine (under a lock on `<store>/xmake/<key>.lock`, so launchers that ask at once wait for
one build and use it), runs it with `XMAKE_GLOBALDIR=<store>/xmake-global`, and links `xmake` and
`xmake-global` of the cache to those. A launcher that waits for another's build says so every 30 seconds (`REVENANT_XMAKE_BUILD_POLL`),
naming the process that holds the lock (the builder records its number, the time it began and the time that process
started in `<store>/xmake/<key>.holder`, written whole and moved into place, so a number that another process has taken since is
not taken for the builder), how long it has held it and
where its log is, and stops with an error after 1800 seconds (`REVENANT_XMAKE_BUILD_WAIT`), so a hung build does not block
every launcher of that key without a word; both variables take whole seconds of at least 1. Stop the process it names and its
children (`make`, the compiler) and run it again. A linked worktree takes `<worktree>/.cache` for its cache when `REVENANT_CACHE` is
unset, and any folder `REVENANT_CACHE` names, empty or not, with no marker. What it holds is small: the token pool, the
scratch of its tasks, and (when a task needs them) `dyld` and `firmware`.

**The cache and the store are two folders, and the cache is never the store or inside it.** The cache is trimmed to
`REVENANT_CACHE_GB` (50), and a trim that takes the store for the cache evicts the store's installs, oldest generations
first. On 2026-11-22 a worker set `REVENANT_CACHE=~/.revenant/store` for one lint, after reading the xmakew of an older
checkout that kept the packages in the cache, and the trim removed five old generations (boringssl, leptonica, tesseract,
zxing-cpp, libcxx) from the shared store. `./xmakew` now refuses to start when `REVENANT_CACHE` is the store, a folder
inside it, or a link into it (the paths are compared after resolving links, also for folders that do not exist yet), and
`cache.root()` and `cache.reserve()` raise in the same case, naming `REVENANT_CACHE`, the store and `REVENANT_STORE`, before
anything is evicted. The one trim that may name the store is the store's own (`cache.guard` marks it `shared`). A store
somewhere else than `~/.revenant/store` is `REVENANT_STORE`, never `REVENANT_CACHE`.

**Start every build with the `xmakew` of the checkout whose recipes it builds** (`$REVENANT_PATH/xmakew`), not with one found
on `PATH` or in another checkout. On 2026-11-22 two Classicgram workers ran the `xmakew` of the main checkout, a detached
head of 2026-10-27, with `REVENANT_PATH` naming the pinned checkout: the recipes were the pin's, the launcher and its xmake
were October's, so the packages went into a private store inside Classicgram's own git work tree, and xmake's `git apply`
of the recipe patches ran inside that repository, where git skips every patch without an error (`Skipped patch`, exit 0,
"install ok"). glslang, spirv-cross and apple-compat then failed with `'absolute' is unavailable: introduced in iOS 13.0`
because the patch that removes `std::filesystem` never applied, and the same run built libcxx from source and fetched
SuiteSparse again, which the shared store already held. Two things now keep that from looking like a platform defect.
`./xmakew` sets `GIT_CEILING_DIRECTORIES` to the cache and the store, so git never looks above them. And
`@addon/revenant/apple-ios` checks at load (`toolchain/modules/launch.lua`) that `REVENANT_STORE` is set, which only the
launcher of the shared store does, and that the package sources under `XMAKE_GLOBALDIR` do not lie inside a git work tree
that a ceiling does not hide (it walks up looking for `.git`, the way git does, without starting a process, because xmake's
description scope has none); otherwise it prints the reason, naming the `xmakew` to use, and ends the load before any
package is installed. xmake's description scope has no `raise`, so the load ends with an `unknown interface` error after
the printed reason. An install that applied fewer patches than its recipe lists cannot be detected afterwards without
patching xmake, which would move the xmake key of every checkout, so the check removes the condition instead.

**A project's `xmake-requires.lock` names the revenant repository of the `xmakew` that builds it.** With
`set_policy("package.requires_lock", true)` xmake takes the recipes of every `revenant@...` package from the repository and
commit the lock records, not from `REVENANT_PATH`. Classicgram's lock named the main checkout at 198a8d1ee (2026-10-27)
while its `REVENANT_PATH` was a pin of 2026-11-22: the toolchain was the pin's and the recipes October's, the October ld64
was not in the store, `apple-compat` raised "the ld64 956.6 package is required but has no install folder", and one
worker compiled the October llvm for an hour for nothing. `./xmakew` now reads the `xmake-requires.lock` of the project
it is asked to build (`-P`, `--project`, else the checkout itself) and refuses, before anything starts, when a `revenant@`
entry names a local repository other than this checkout (paths compared after resolving links) or any repository at a
commit other than the checkout's `HEAD`; an entry that names the published repository by address is held to the commit
only. The message names the lock's repository and commit and this checkout. The fix is the same each time the pin moves:
delete the lock, run the build once so that xmake writes a new one with this checkout as the repository, commit it with
the pin. A lock without `revenant@` entries is not read further, and `--patchset` and `--build-xmake` do not check it.

Two builds of one package key never run at once, because the install is locked by its folder (`<installdir>.lock`); two
different keys of one package, built at once by two processes, each patch and build in their own copy of the sources
(`checkout.keyed`, [ADR 0018](../explanation/decisions/0018-source-folder-per-build.md)).

**A cache from before the store is refused**, because a real `xmake-global` in it would be read by the tools that read it
beside the store's, and it is not the store's. `xmakew` stops before it makes anything (no store, no link) and names two ways
out: remove `xmake` and `xmake-global` of that cache (the installs come again from the prebuilt releases or are built once),
or make that cache the store while the store does not exist yet, which keeps its installs and the generation names a roots
file pins. The second is run with an xmake binary of the old cache, because `./xmakew` would build one into the store and
the seeding refuses a store that has anything in it; `xmakew` prints the whole command on a line that starts with
`xmakew: seed:`:

```
cd <checkout> && <old cache>/xmake/<key>/bin/xmake l -P . tools/private_cache.lua ~/.revenant/store --from <old cache> --only xmake,xmake-global
```

After it, remove `xmake` and `xmake-global` of the old cache; the next `./xmakew` links the cache to the store.

The tool clones the two folders `--only` names with APFS clones (without `--only` it clones the whole cache) and rewrites every absolute link, every `CMakeCache.txt` and the text state under
`xmake-global/.xmake/cache` to name the store, then writes its `.private-cache` marker. It refuses a destination that exists
and is not empty, inside the source or holding it, or on another volume. A clone is only as warm as its source: choose the
cache that holds the packages the pins and the tasks need, and read `status` of the store before using it. Its older
`xmake/<key>` binaries come with it, and the key of this `xmakew` is built beside them on first use.

### What a new cache lacks

A new cache has no `dyld` and no `firmware`; a task that reads them fetches them (the iOS 6.0 shared cache, the firmware
catalogue), or the worker clones them from a cache that has them with `cp -c -R -p` (an APFS clone) before the first run
(`dyld` clones itself, see "Which cache to clone"):

- `<source>/dyld/6.1.3/classes_armv7.json` exists. The Backports generator decides from that file which SDK classes get a
  proxy and stops without it; a cache that has only `dyld/6.0` once produced a skeleton from the wrong release's inventory
  (a `MapKit` proxy that the 6.1.3 device does not need).
- For the device runtime tests, `<source>/firmware/rootfs/iPhone4,1/6.1.3_10B329` exists. A cache without it runs every
  `backports_runtime` case as failed (measured 2026-11-19, all cases of the group), because the emulator has no root file
  system to boot. A missing one is cloned from a cache that has it with `cp -c -R -p` (an APFS clone, no second copy on
  disk), before the first run.
- `df -h /System/Volumes/Data` after a clone: a clone costs little until it is written to, and the floor of the disk rule
  holds.

### Which cache to clone

`dyld` is the one part of a new cache that clones itself. `tools/dyld_caches.lua`, and the first thing every prepush run does,
gives the checkout each release folder it lacks: a folder of `.cache/dyld` of the main checkout, then of `.cache*/dyld` of
every other worktree (`git worktree list`), that holds a `dyld_shared_cache_<arch>` with its `.source` note (the harvest writes
the note right after the cache, so a folder whose harvest is still running does not count) or a `libraries_<arch>` folder is
cloned into this checkout's `.cache/dyld` with an APFS clone (no second copy on disk, no network). The first source that holds a
release wins. A release this checkout already holds is left as it is; a folder here that holds no cache, while a source holds
that release, is reported and not overwritten (an unfinished fetch may be writing it); a source folder that holds no cache is
not a release. The clone goes through a staging folder next to `dyld` and a lock: two runs that clone the same release at once
put one clone in place and the other's copy is removed, and a staging folder an aborted run left is removed an hour later.

```
./xmakew l -P . tools/dyld_caches.lua
```

The whole release folder comes with the cache: `classes_<arch>.json` (the inventory the Backports generator reads), the
selectors and the libraries outside the cache. A clone taken while another checkout is writing `classes_<arch>.json` (the
`firmware classes` command writes it after the harvest) can hold a truncated file: remove the release folder here and clone it
again. Nothing is fetched: a release no checkout holds is still fetched with
`./xmakew firmware -P . --arch=armv7 fetch <release>`, and `firmware/rootfs` is cloned as the section above says.

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
| `llvm` | `recipe` | `packages/l/llvm/port/inputs.lua` (the url, version, commit, every flag of git and cmake, the cmake targets) and the bytes of the patches it lists; not the recipe text |
| `swift` | `recipe` | the recipe and its patches |
| `dynarmic` | `recipe` | the recipe; its patches are in the build hash, see below |
| `swift-bootstrap` | `recipe` | the recipe; the swift.org package is held by the version's sha256, outside the digest |
| `iphoneos-sdk` | `additions` | what the recipe adds to the SDK |

`llvm`'s digest is of what its build reads, so an edit that only lays the build code out differently keeps the key, and
the one-hour build with it. The recipe's `on_download` and `on_install` take every value from `port/inputs.lua` and only
expand it, and `toolchain/tests/addon/llvm_inputs_test.lua` fails on a flag, a cmake target, a url or a commit written
in them, so none can change the compiler without moving the key. The test reads the end of each of those functions by
counting `function`, `if`, `do`, `repeat` and `end`, `until` outside strings and comments, so a nested block or another
indent hides nothing, and it fails on a second Lua file in the recipe's folder or on a module the recipe names beyond
`port/inputs.lua` (a flag read from a helper file would not be in the digest). It reads files only: run it alone, without
any package installed, with `./xmakew l -P . toolchain/tests/light_suites.lua llvm_inputs_test` (the one argument names a
light suite; `./xmakew test -P .` configures every requirement of `toolchain/tests/xmake.lua`, `llvm` with `libraries = true`
among them, first). A change to what the build installs that is no flag (a
step added, removed or reordered) raises `procedure` in the table by hand. The values in braces are filled in by the
build: `{build}` (the cmake build folder), `{install}`, `{arch}` (the host's), `{link_jobs}`, `{patch}` (one patch's
file), `{clang}` (the clang just built), `{host_linker}`, `{llvm_cmake_dir}`, `{resource_install}` (where the iOS
builtins go) and `{sysroot}` and `{sdk_version}` (the iPhoneOS SDK).

`llvm_recipe_aliases` in `port/inputs.lua` keeps the installs that were made before the digest came from the table: an
entry is a statement that the inputs whose digest is the entry's key produced the install whose `recipe` config is its
value, and it is used only when the digest of the inputs is exactly that key. Today it names the llvm of recipe
`4c6acdde` (installed as `82efc6d6`, the `libraries = false` build that `apple-ios` programs use), so those programs
build and fetch no llvm after the change. Delete the entry, and do not edit its key, in the change that first alters an
input: a flag, a patch, the url, the version, `procedure`. That llvm is a new key then, and the test fails until the
entry is gone. The alias does not look at the `libraries` config: the `recipe` config's default is computed when the
recipe is read, before any config is known, so a `libraries = true` build of these inputs gets recipe `4c6acdde` too. That
is harmless, since `libraries` is part of the build hash as well, so the `true` install is a different directory with its
own key, but no `libraries = true` install was ever made under the old key, and the alias says nothing about one.

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
`libcxx` and `swift-runtime` are installed by the iphoneos guest, so when the project is not configured for iphoneos `keys.lua`
prints their guest keys, marked `iphoneos-arm64` (`apple_minimum 7.0`, `library_evolution` for `swift-runtime`, the packages
`XL_SWIFTOBJC_LIBS` names), and not a host key that no archive is released under. It configures a scratch project for them in
`<cache>/scratch/<task>/keys-guest`, in that folder's own `.xmake` (a configure with `-P` writes the `.xmake` of the folder it is
run from), requires only what the `apple-ios` include does with `apple_compat_only` (the SDK, `ld64` and `llvm`, taken prebuilt
and never built from source, so nothing when they are installed) and not the two packages, and takes about two seconds on a
machine that has them; `keys.lua guest` prints the keys for any configuration. `toolchain/tests/addon/keys_test.lua` holds the two keys measured on 2026-11-21 (`libcxx` 16275d93,
`swift-runtime` 9270db93), so a change that moves them fails there until the new archives are published.

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
unmarked patch moves none. A binary without the file refuses to compute a build hash. One patch is marked: `0025`, which sorts the strings of a
build hash by byte instead of by the locale's collation ([decision 0017](../explanation/decisions/0017-build-hash-sorts-by-byte.md));
it moved every key once. The others are not marked: the
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

`run` exits 0 when the command it starts passes, the command's status when it fails, and 3 when the budget refuses to start
it at all. A refusal prints the disk reading and the floor; the command was never run, so its status is not a failed check.
`status` and `test` do not take tokens and never refuse. The runs that `test` and prepush's own tests start pin
`REVENANT_BUDGET_DISK_GB=0` in their environment, so the tests pass at any free space; a list of `envs` given to
`process.openv` replaces the whole environment of the child, so the pin has to be in that list, and a floor set in the
environment of the test does not reach it.

- Size. The pool holds at most the cores less two. Room is recomputed on every poll, never from a sample taken once at
  admission or from a patience timeout. CPU headroom uses the largest of three measurements: the one-minute runnable load
  (`sysctl vm.loadavg`); the runnable threads of the pool's own holders, read from `ps` state `R` over the descendant tree
  of each holder pid, so a command's children count and a caller's unrelated process group is never included; and the
  tokens granted in the last minute, stamped one per slot into the pool's slot files under the slot lock when a grant is
  published and read by every later request. A stamp contributes one token times the share of the minute still left, so
  an N-token grant counts as N, never N squared, and is never added on top of a load average that already reflects it —
  the largest of the three wins. Tokens are not assumed to be runnable threads: a holder blocked on I/O contributes
  nothing, and a holder whose build spawns many compilers contributes all of them. Memory headroom comes from the
  kernel's own measure of available memory and pressure. Available memory is `kern.memorystatus_level` percent of
  `hw.memsize`, less the 2 GB reserve, in tokens of 1.5 GB but at least one. The 2026-11-21 budget memory measurement,
  saved with its raw series and exact maxima in `coordination/measurements/budget-memory-2026-11-21.txt`, sampled
  `memory_pressure -Q`, the level sysctl and `vm_stat` every second on this Mac: the level equalled `memory_pressure`'s
  "System-wide memory free percentage" at every paired sample, while a `vm_stat` free + speculative + inactive +
  purgeable sum was about half of it, so the level is the signal that tracks macOS's own view of available memory and
  is the one used here. Inactive and purgeable pages are inside that share; active file-backed pages are not subtracted
  separately because the level already accounts for them, and the measurement shows it tracks `memory_pressure`.
  Between successive samples a rate guard clamps to one token when pageouts exceed 1 MB/s or compressor pages grow by
  more than 512 MB/s: these are byte rates scaled by the page size read from `vm_stat`, so they do not assume 16 KB pages.
  The measurement saw quiet pageouts peak near 10 pages/s and background compression near 304 MB/s, so normal churn does
  not clamp, while the roughly 750 MB/s compressing state the load audit treated as pressure does. Critical pressure
  grants none, warning pressure grants one token. A request gets no fewer tokens than its `--min`: if the room cannot
  hold the minimum it
  waits and re-checks, with no patience after which the load stops mattering. When the minimum fits but the room is smaller
  than `--jobs`, it starts with fewer jobs, up to what memory and CPU allow. As a progress guarantee, when the pool has no
  live holder the oldest waiting ticket is granted its minimum in full even under high outside load, provided memory
  headroom is at least that minimum; less than the minimum of memory headroom, including critical pressure, makes it wait
  rather than start short, and the disk floor still stops it. In guarantee mode an older live ticket blocks the grant only
  when its minimum fits the available memory headroom, so class order and age pick the first eligible ticket and a ticket
  that cannot fit its own memory minimum does not hold up the queue; in ordinary mode a small request can still backfill.
  The slot locks give the guarantee to one ticket at a time, and once it holds, later tickets wait for headroom again.
- Need. A command asks for `--min` tokens (one by default), or for the tokens its `--mb` needs when that is more (a 2.5 GB class
  takes two), and for up to `--jobs`; the minimum is a hard floor and a request that cannot meet it is never started short.
  It runs with `XMAKE_MAX_JOBS` set to the tokens it got.
- Order. Waiting commands queue by class: `critical` (the checks before a push), `normal` (the default, which every `./xmakew`
  build, test, configure, install, run, package and deb uses) and `background`. Within a class the first to wait goes first.
  A small request backfills past an earlier one whose minimum does not fit the current headroom, so a large request that
  cannot be granted does not hold up the queue behind it. A request that has waited ten minutes (`REVENANT_BUDGET_AGING_S`)
  marks itself aged in the queue; from then on it also blocks any *later* backfill whose minimum it could have used, so a
  stream of small requests cannot starve it without two aged requests blocking each other. The marker is removed with a
  dead ticket, so a crashed request cannot block the queue forever. A request whose process died is removed from the queue.
- Nice. `critical` keeps its priority, `normal` runs under `nice -n 5`, `background` under `taskpolicy -b` and `nice -n 15`.
- Release. A token is a lock on a slot file, and the kernel releases it when its process ends, `kill -9` included. The command
  is started with the descriptors of the slot files closed, since a child that kept one would keep the token after its parent died.
  A budget run also ends with the process that started it: a small shell watcher, started with the run, checks once a second that
  the run is still the child of the process that started it (a process that is reparented to launchd has lost its parent, whether
  or not anybody has reaped the dead one yet), and when the parent is gone (a `kill`, a closed terminal, a crash; `kill -9` included, where no handler can run) it
  sends TERM to the budget run and everything below it, and KILL two seconds later. So prepush killed in the middle of a heavy
  step, or of its batch of light checks, leaves no `budget run` and no command holding tokens at ppid 1. The watcher is a shell
  and not a signal handler because xmake runs a Lua handler only between two Lua instructions, never while it waits for a child.
- Who holds. A held token names its holder: the pid of the budget run, its worktree and its command, written into the slot file
  with the grant, and a waiting request's ticket names the same about itself. `status` prints a line for each holder
  (`pid 123 holds 2 token(s) for 4m in <worktree>: <command>`) and for each waiting request, and a request that has to wait
  says so at once, `budget: waiting for N token(s), <class> class; held by:` with the holders' lines (or that nobody holds
  a token, so the machine's load or memory is the limit), and again every five minutes (`REVENANT_BUDGET_ANNOUNCE_S`) while it waits.
- Nesting. A command under a budget gets its count in `REVENANT_BUDGET_HELD`. A budget run below it takes no tokens of its own,
  so a `./xmakew` started by a build waits for nothing and is bounded by the build's tokens.
- Disk. No command starts while the volume of the checkout has less than 100 GB free (`REVENANT_BUDGET_DISK_GB`). The
  refusal is per command: `run` exits 3 and prints the reading before the command starts. A command already admitted can
  fail for its own reasons even if the disk drops below the floor while it runs, and that failure is not a refusal.

A command run straight with `xmake`, and not through `./xmakew` or a budget run, takes no tokens.

`./xmakew l -P . tools/prepush.lua` reports a refusal from any budgeted step as its third outcome: it prints
`prepush: budget refused; this is not a failed check, free the space and rerun` and exits 3, without counting any check
as failed and without remembering a refusal as a pass. Exit 0 means every check passed, a failed check makes the tool
raise, and exit 3 means the disk stopped it; a caller scripting prepush can tell the three apart.

Prepush writes each line as it happens and flushes it (`say` in `tools/prepush.lua`), so a run redirected to a log
(`> prepush.log 2>&1 &`) shows each line when it is written and does not depend on how the output is buffered; the 2026-11-22
probe saw this xmake write a short `print` line to a redirected file or a pipe at once, and the flush keeps it so. A check
prints `start <name>` when it begins and `ok <name> <n>s` or `FAIL <name> <n>s` when it ends, and the line is in the file at that
moment. The work before the first check says what it is doing too, so a log is never empty while prepush is only reading:
`prepush: reading the state of the tree` and `prepush: <n> files, <m> of them uncommitted or untracked (<s>s)`, then
`prepush: reading the installed toolchain …` (once, when a key needs it) and `prepush: computing the keys of <n> checks`
and `prepush: keys done in <s>s, <k> of <n> checks have a remembered verdict`; the first line of the log is one of these,
and a `start` line never comes before the keys line. A log that stays at 0 bytes for more than a few seconds means prepush
itself is stuck, not that it is working quietly. What kept an earlier run silent for two hours was the wait, not the buffer: the batch of light checks is a budgeted
child that queued behind the holders and printed nothing; it now says who holds the tokens. The light checks (comments, layout, digests and the like) run first; when one is red the run stops there, before any
heavy check is queued on the budget, names the check (`prepush: <name> failed; the run stops here, and no heavy check was
started`) and fails; `--keep-going` runs on and says so. When every light check is green it says `the light checks are green;
starting the heavy ones` before the first heavy one. Anything that waits on the budget, the batch of light checks included
(it is a budgeted child of its own), says who holds the tokens (the lines of `budget status`) instead of waiting in silence.

## Checks that remember their result

`./xmakew l -P . tools/prepush.lua` remembers each check that passed, in the shared store (`<store>/memo/<check>/<key>`, the 40
newest of each check), under the key of what the check reads. Where it is in doubt whether something is an input it goes into the
key, because a rerun costs seconds and a verdict that no longer holds costs a push; what stays out is listed after the key. The key is

- the check's name and version, the xmake that runs it, the host, and the code that runs the checks: `tools/prepush.lua` and
  `tools/budget.lua` are read by every check, so a change to how a check is run runs it again;
- every `REVENANT_*` variable that is set and not empty, and `XMAKE_GLOBALDIR`, for every check, and the variables a check
  names (`LC_COLLATE` for `layout`). Not part of a key: `REVENANT_CACHE`, which is the folder of one worktree, and the budget's
  own `REVENANT_BUDGET_*` variables, which say when a command may start, not what it finds;
- the content of every tracked file and every untracked file git does not ignore that the check reads (its blob id, or its
  content when it differs from the index). The uncommitted files are read with `git status -z` into a file and read back as
  bytes, not through `os.iorunv`: xmake decodes an output that holds NULs as UTF-16, so anything longer than two entries came
  back as one record without its boundaries (2026-11-22: a 3.5 MB list became one 5.3 MB "path", the glob `**/*.md` took hours on
  it, and the content of the uncommitted files was in no key). The list goes to a file under `.cache/scratch/prepush-lists/` (the
  checkout's cache, not the system temp folder), which is removed on every path, errors included. The list is checked: a git
  that exits non-zero (a corrupt index, a folder it cannot enter, a bad `GIT_*`), a list whose records and boundaries do not
  match, a record longer than a path, a record that is no status line, or digests that do not match the files fail the run at
  once with `could not be read cleanly`, before any key is computed or any remembered verdict is looked at; an empty list is
  believed only when git exited zero.
  The private folders of a worktree (`.cache*`, `build`, `.xmake`, `.claude/worktrees`) are left out of the list by pathspec,
  so a private cache of any name never enters a key (`.gitignore` has `/.cache-*/` for the same reason);
- for `comments`, the content of the local `.git/info/attributes` and of the global attributes file, which `git check-attr` reads
  to classify a file;
- for `recipe digests`, `lowered members`, `lowered exports`, `light suites`, `backports build`, `backports exports` and `backports device imports`, which run against what is
  installed: the Xcode and SDK probes, where `git`, `rsync`, `cmake`, `ninja`, `xcrun`, `clang`, `cc`, `make` and `sh` resolve and the
  first line of what each prints for `--version`, every install of `llvm`, `swift`, `swift-bootstrap`, `swift-runtime`, `libcxx`, `apple-compat`, `iphoneos-sdk`, `ld64` and
  `ldid` in the store with the digest of its `manifest.txt`, and the content key of the iPhoneOS SDK (every file of it, with
  the Xcode tools, about 6 s once per run);
- for `backports build`, `backports exports` and `backports device imports`, besides the installed facts, the identity of every
  complete device cache under `.cache/dyld`: for each file of each release folder its name, its size and its sha256 (the size
  only from 32 MiB up, the shared cache itself). The generator reads the class inventory of iOS 6.1.3 and the import check reads
  the system libraries of the oldest release the Backports libraries run on, so a build or a verdict is remembered only for the
  caches it saw. The facts are read after prepush has cloned the caches this checkout lacked ("Which cache to clone"); when no
  checkout holds a release, `backports device imports` fails with the command the deb writer's fetch is
  (`./xmakew firmware -P . --arch=armv7 fetch <release>`). These steps read everything the build reads (`reads` is the whole tree);
  `dyld caches test` reads the tool, its module and `toolchain/modules/*.lua`.

What a key does not see, and the remembered `ok` can therefore outlive a change that a fresh run would report: an install replaced in
place with the same name and manifest, and a tool replaced in place with the same version line; the host's own frameworks and tools
that a check calls without naming them in a key (`assets_extract_test` reads the host's CoreUI and runs `plutil` and `assetutil`,
`emulator_source_test` runs `locale -a`); the wall clock (`credentials` reads `os.time()` against a fixture that expires in 2100, so it
cannot change its answer before then); the external `find` that `copied_text` and `credentials` run; a file git ignores inside a
folder a check reads (`agent-skills/tests/data/`: an ignored fixture that changes does not run those two again); the network. A
change of the host's macOS or of any of those is the case for `--fresh`, which runs every check and records the verdicts.

The commit, the folder and the rest of the environment are not part of a key, so a rebase, an amend, another worktree or another
shell with the same files takes the verdict from the store, and a file a check does not read does not run it again. A check that
failed is never remembered, and one that left no verdict (the process that runs the in-process checks was refused by the budget or
died) fails. A run prints where each verdict came from, `ok layout memo (ran 3 s in xl-source-lock at 4825472b6, 12 min ago)`
when it was remembered and `ok layout 3s` when it ran; `--fresh` runs every check regardless and records the verdicts.

What a check reads is declared on the check in `tools/prepush.lua` (`reads`, a list of files, directories ending in `/`, and globs with
`*` inside a directory and `**` across them, and `skips`, which takes files out). A check that declares nothing reads every file,
so an undeclared check is slower, never stale. The narrow ones: `comments test` (`tools/comments.lua`, `tools/comments/`), the
tests of `tools/private_cache.lua`, `tools/ci_errors.lua` and `tools/ci_swiftc_replay.lua` (the tool, its folder and the addon
modules), `credentials` and `copied_text` (`agent-skills/tests/`), `negative shape` (the Backports tests and `emulator/`),
`dyld caches test` (`tools/dyld_caches.lua`, `toolchain/modules/apple/dyld_caches.lua` and the addon modules),
`recipe digests` (the inputs the recipes list in `toolchain/modules/digest.lua`, the digest files and the addon modules), and
`lowered members` and `lowered exports`, which skip `docs/`, Markdown files, `.agents/` and `agent-skills/`. `backports build` skips
nothing, because the copy it builds in holds every file, and `backports exports` and `backports device imports` skip nothing because they read that copy's build (and the baseline data, or the device caches). A check that starts to read a file outside its declaration, or an ignored
file, must say so there; an ignored file is not part of a key.

The checks that run inside xmake (`comments`, `layout`, `docs_commands`, `recipe digests` and the rest of the cheap ones) and
whose verdict is not remembered run together in one xmake process behind one admission of the budget: before, each took its
own process and waited its own turn for a token (80 to 372 s each on a busy machine, 0 to 10 s when run directly). The checks that
build or need their own process (`host install test`, `isolate test`, the heavy ones) keep their own.

`backports build` configures the Backports component for iphoneos armv7 and builds every one of its libraries, with the flags
of the package, so a source the `backports` package cannot compile (a `-Werror` of `frameworks/Backports/xmake.lua`, a missing
header, a link error) stops the push and not the build of an application that requires the package. The check works in a copy of
the checkout, `build/backports-gate/tree`, which `rsync -a --delete` brings up to date from the checkout on every run (git, `.xmake`,
`build`, the caches, `.claude/worktrees` and every file git ignores, `build/backports-gate/ignored.txt`, stay out, so that the tree holds
the files the key covers and no others), so the host configuration of the checkout stays what it was and
`./xmakew test -P .` still runs. The copy keeps its own `.xmake` and `build`, so a later run compiles only what changed. A shared
`XMAKE_CONFIGDIR` would not do: the configure starts nested xmake processes that inherit it and wait on the project lock the
configure holds. The check takes the prebuilt `llvm`, `swift` and `ld64` of `REVENANT_PREBUILT` and `REVENANT_PREBUILT_ONLY` when the
environment names them (`kern0x1b/revenant` and `llvm,swift,ld64` otherwise), and fails rather than building them from source. It reads
the package store and the lowered overlays of the store, and the iOS 6.0 shared cache of `REVENANT_CACHE`, which are caches and not part of its key (the installs it builds against are). On
a failure it prints the compiler's errors and the path of the whole log, `build/backports-gate/prepush.log`. The first run builds
all libraries (about six minutes on a 12-core Mac), a later one only what changed, and a run on an unchanged tree is remembered like the
others. `./xmakew l -P . tools/ci_local.lua backports` runs the same build from a fresh configuration and goes on to the Backports
tests, the probe app and the exports check. `ci_local` hands the light suites to the `checks` job when the memo already holds them: just before that job starts (after the quick job, in a
serial run, so the prepush that job ran counts; right after it makes the job's clone, in a parallel one) it asks the memo
(`prepush.lua --recall "light suites"`, which prints the line and `key <hash>`) and, when prepush holds the verdict, writes the line, the key, the path
of the tree the job tests (the clone, or the checkout in a serial run), its own process number and start time and the folder of its run to
`light-suites-<pid>-<nonce>.verdict` in that folder, under a nonce made for that run, and exports `REVENANT_LIGHT_SUITES_VERDICT=<nonce>@<that file>`.
A suite of the light target takes its verdict from the file only when all of this holds: the nonce in the variable is the one in the file; the
file is where it says it is and is named for the process and the nonce it says (a copy in another folder, or under another name, is not taken); the
file names the checkout the suite is running in (by its real path); the process that wrote it is still running, started when the file says and is a
`ci_local` (its command line says so; a run that was killed, a process number another process has taken and a shell of someone who typed the file
are not trusted); and the memo store holds an `ok` verdict of `light suites` under the key in the file (a look at `<store>/memo/light-suites/<key>`,
not the word of whoever wrote the file). It then prints the line that says where the verdict came from and runs the rest; anything else (a string
typed into the variable, a leftover of another shell, a file of another run, folder or checkout, a key the memo does not hold) is no verdict and the
suites run. Nothing is remembered between the suites: each looks again, with one `ps` and one `pwd -P` and two file reads, so a refused verdict is
refused again and a verdict the memo has dropped stops being taken.


What this does not do: it does not compute the key of the checkout again in the suite (that is the 11 seconds of prepush's key, once for each of the
fifty-odd suites). The key in the file is the one the memo gave when `ci_local` asked, in the run that is alive, so an edit of the checkout between that
moment and the start of the tests is not seen, and a file written by hand that satisfies every condition above, with a key the memo holds for some
earlier inputs, is taken. The conditions keep out accidents (a stale file, a copied file, another checkout, a killed run, a typed value), and not a
person who sets out to forge a verdict; anyone who can do that can also leave the tests out. `ci_local` deletes the file when its run ends (not when it is
first read, because every suite reads it). `toolchain/modules/recalled.lua` holds the writing and the reading, `toolchain_light/recalled_test` its cases,
and `prepush`'s own test that it reads the memo the way `prepush` writes it.

Order and flags. The cheap checks run first and the heavy ones (`lowered members`, `lowered exports`, `light suites`,
`backports build`, `backports exports`, `backports device imports`) last, and the run stops at the first check that fails, so a two-second `layout` failure does not wait
behind a build. `--keep-going` runs every check regardless (the old behaviour), `--list` prints the names with the heavy ones
marked, and `--only <check,...>` runs just those (names with a space are quoted: `--only "layout,light suites"`) for iterations;
an unknown name is an error, and a run with `--only` says that a push needs all checks. The full run before a push stays
without flags. Keep the caches (`.cache`/`REVENANT_CACHE`, `build/backports-gate`) between runs: a cold `backports build`
took 48 minutes on 2026-11-16 and a warm one 58 seconds, and a deleted cache leaves references in the checkout's `.xmake`
that make a later check fail, so remove `.xmake` together with a cache it names. The gate's copy stays per checkout: its
own `.xmake` records the cache paths of the run that configured it, so a copy shared between checkouts would point at another
checkout's cache.

The compile cache. A fresh worktree has no `build` folder, so its first `backports build` compiled every source again (2954 of them: 27 minutes
on a loaded machine, six on an idle one) although another worktree had compiled the same files an hour before. xmake's builtin cache (the
`cache compiling` lines of the log) could not help: it lives in the tree's own `build/.build_cache`, and its key is the compiler's flags and
the preprocessed text, both of which carry the absolute path of the tree (`-I<tree>/...`, `-ffile-prefix-map=<tree>=/port`, the `# 1 "<tree>/..."`
line markers). Another tree at another path, seeded with 2776 objects of the first one, hit none of them. So the Backports targets (the rule
`backports.cached` of `frameworks/Backports/xmake.lua`) compile through ccache when it is installed. `toolchain/modules/apple/ccache.lua` gives
each target a generated shim in place of its four compilers, `<store>/ccache/shim/<key>/clang`, which execs `ccache <the clang of the llvm
package>` with its settings in its own environment: `CCACHE_BASEDIR` the parent of the main checkout, so that every worktree under it hashes the
same paths, `CCACHE_NOHASHDIR`, `CCACHE_COMPILERCHECK=content`, the folder `<store>/ccache/cache` capped by `REVENANT_CCACHE_GB` (4 by default),
and a `CCACHE_CONFIGPATH` of its own, so the user's `ccache.conf` is neither read nor edited and a machine without one behaves the same. The shim also clears every other
`CCACHE_*` variable of the invoking shell, except `CCACHE_LOGFILE`, `CCACHE_DEBUG`, `CCACHE_DEBUGDIR` and `CCACHE_DISABLE`, which only observe or
switch off: an ambient `CCACHE_IGNOREOPTIONS=-D*`, which a user may keep for another project, would otherwise answer a compile with another `-D`
from the cache. It turns
xmake's builtin cache off for the target, so that one cache owns the compile and nothing is wrapped twice. The only sloppiness is
`include_file_ctime,include_file_mtime`, which a fresh checkout needs because its files are younger than the compile: `system_headers` would let
an edit of `neon/include`, which the toolchain passes as `-isystem`, leave a stale hit, and `time_macros` would cache what depends on the clock.
Measured on 14 recorded compiles, each run at two paths: all 13 that ccache accepts hit from the other path (direct mode), in 1.1 s against 7.1 s
of compiling, and the objects were the same bytes at both paths and held no path of either tree. xmake gives the compiler its sources relative to the
project, so an object ccache made equals one clang made on its own here (a source named by an absolute path would differ, because ccache hands clang
the source relative to its working directory and `__FILE__` then reads differently). The 5% of the compiles that pass `-ivfsoverlay` (the generated `build/generated/backports/overlay/vfs.yaml`) are not cached:
ccache refuses them without the `ivfsoverlay` sloppiness, which would make it ignore the overlay's content; the overlay is content-keyed
(`lowered/<digest>`), so putting its digest into the key would let them be cached safely, and that is left to a later change. Measured on the
whole gate (2954 compiles, one machine under other jobs): a first tree at a fresh path took 49 minutes (configure 251 s, build 2928 s; 2750 misses,
87 hits), and a second tree at another path, with the cache warm, 6 minutes (configure 74 s, build 286 s of which 244 s is the compiling): all 2837
compiles ccache accepts hit, 2747 in direct mode and 90 through the preprocessed text, and the 117 compiles that pass `-ivfsoverlay` ran.
All 2954 objects of the second tree are the same bytes as the first tree's. A tree compiled with `REVENANT_CCACHE=off` (xmake's builtin cache) differs in
one place: the `sdk` field of the version load command of its objects reads `n/a` where ccache's reads `26.2` (702 objects of 30 targets
compared, 2 bytes each); the linked dylibs of those targets are the same bytes as the ccache tree's, so the difference does not survive the link.
After that gate the ccache folder held 131 MB. The store trim counts `<store>/ccache/cache` as scratch, the only part of the `ccache` folder the cap can evict, and keeps the
shims and the settings, which a running build executes. `REVENANT_CCACHE=off` compiles without ccache; without ccache installed nothing changes.

Where a cold `backports build` spends its time (2026-11-16, 63 minutes by the install times of the packages): the packages
46 minutes (`libcxx` 10, `tessdata` with every language 12, `openssl-host` 5, `tesseract`, `leptonica`, `zxing-cpp`,
`ffmpeg-hevc` and `boringssl` about 12 together, `ld64` 2.5), the Backports libraries 17. Only `llvm`, `swift`, `ld64` and `libcxx` of
these have a prebuilt hook (`docs/guides/prebuilt.md`); the rest build from source on a machine without the cache, which is why a
warm cache is kept.

`recipe digests` is remembered like the others, by the files its recipes list, the digest files and the SDK facts, so a second
prepush on the same tree runs no check, and an edit of a document runs only the checks that read documents. `./xmakew l -P . tools/prepush.lua test`
checks the keys and the memo (3, 10, 1,000 and 30,000 untracked files are all in the manifest with git's own digests, a changed
one changes the key of a check that reads everything, a file of a private folder changes none, a list git's output cannot give
cleanly and a git that fails are refused and leave no list file behind, names with a space, a newline, Cyrillic, a leading dash,
quotes and a tab and a staged rename that is edited again keep their own digests, and the ignored list of the Backports gate
keeps every entry): an edit, an untracked file, a deleted file and a named environment variable each change the keys of the
checks that read or name them, restoring them restores the keys, another folder or a new commit with the same files has the same
key, a file a check does not read leaves its key, a failing check runs again, the checks of one process run in one batch, and
`--fresh` runs them all. Its live tests start real prepush runs that hold budget tokens and are then signalled with TERM, INT
and KILL; they pin the budget's disk floor (`REVENANT_BUDGET_DISK_GB`) to 0 for those runs, because below the floor (100 GB)
the budget refuses every heavy command and the run would hold nothing (this made the TERM case fail on every run while the
disk was under 100 GB, 2026-11-22: it was the disk, not timing). A run with a floor no disk meets is checked to be refused.
