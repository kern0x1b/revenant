# The machine: one cache, one clean

How a build uses this machine's disk, and how to give it back.

## One root for everything a build can make again

Everything a build can make again lives under `~/.revenant/cache`:

| Folder | What it is | Who writes it |
| --- | --- | --- |
| `xmake/<key>` | the pinned and patched xmake, one folder per pin and patch set | `xmakew` |
| `xmake-global/.xmake` | the package store (`packages`), the package sources and build folders (`cache`), the repositories | xmake, through `XMAKE_GLOBALDIR`, which `xmakew` sets |
| `<task>` | scratch of one task, deleted when the task ends | the task |

## The data that is not a cache

Everything under `~/.revenant` that is not `cache` is data, and no clean touches it:

| Folder | What writes it | Why it is not a cache |
| --- | --- | --- |
| `dyld` | `toolchain/modules/apple/firmware.lua` | the shared caches and libraries of each iOS release, taken out of decrypted firmware |
| `firmware` | `toolchain/modules/apple/firmware.lua` and the `firmware` plugin | the firmware catalog, the root file systems, a download that resumes |
| `emulator` | the emulator's image commands | golden images that took a first boot to make; `REVENANT_EMULATOR_ROOT` names another folder for all of it |
| `emulator-slots` | `toolchain/modules/emulator.lua`, on every emulator start | the lock files that bound how many emulators run at once on this machine; removing a lock file that is held lets a second emulator start, so it is not a cache |
| `devices` | `toolchain/modules/device.lua` | which run holds which device |
| `cache-index` | `toolchain/tools/cache_index/build.lua`, from `dyld` | an index its readers find beside `dyld` |
| `corpus` | the corpus tools | data read from applications and devices; `REVENANT_CORPUS_ROOT` names another place |

A folder belongs in `~/.revenant/cache` if, and only if, removing it costs only time.

## One clean

    ./xmakew l -P . tools/clean.lua [--dry-run]
    ./xmakew l -P . tools/clean.lua --packages [--dry-run]
    ./xmakew l -P . tools/clean.lua --all [--dry-run]

| Level | Removes | Keeps |
| --- | --- | --- |
| default | each worktree's ignored `.xmake` and `build`, every tool cache and scratch folder, the package sources and build folders of the store, xmake's leftover build folders and logs | the package store, the xmake binaries |
| `--packages` | the same and the package store | the xmake binaries |
| `--all` | everything under `~/.revenant/cache`; the xmake binaries are built again on the next `./xmakew` | nothing |

Only ignored and untracked build folders are removed: `git check-ignore` decides.

## Scratch: kept while it is used, removed when it is not

`./xmakew` sweeps the scratch of finished tasks by itself, at most once a day, and prints what it freed:

    ./xmakew l -P . tools/clean.lua --scratch [--dry-run]

The sweep is `--scratch`, and it is safe while workers run. It removes a folder `cache/<name>` only when all three hold:

- no live worktree is named after it: the names come from `git worktree list` of the checkout, and the checkout's own
  name is always kept;
- nothing in it was modified in the last 7 days (`find -mtime`);
- no process has a file open in it (`lsof -F n` lists every open path once, and the folder is matched against them).

It never touches `cache/xmake` or `cache/xmake-global` (the binaries, the package store and its locks), nor the data
folders under `~/.revenant`. If `lsof` fails, nothing is removed. The sweep records its run in `cache/.scratch-swept`,
and the wrapper runs the sweep again only when that file is more than a day old.

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

## Build each package once

A package's key is its build hash: the platform, the architecture, its configs and the toolchain names.
The large packages put a digest of the files that make their output into a readonly config, so the key
changes exactly when those files do:

| Package | Digest config | Made from |
| --- | --- | --- |
| `swift-runtime`, `libcxx` | `recipe` | `port/digest.lua` in each recipe folder, which `toolchain/tools/recipe_digests.lua` writes from the recipe and the modules it runs |
| `llvm`, `swift` | `recipe` | the recipe and its patches |
| `dynarmic` | `recipe` | the recipe; its patches are in the build hash, see below |
| `swift-bootstrap` | `recipe` | the recipe; the swift.org package is held by the version's sha256, outside the digest |
| `iphoneos-sdk` | `additions` | what the recipe adds to the SDK |

A change to documentation rebuilds nothing. `./xmakew l -P . tools/keys.lua [package ...]` prints each large
package's key and its digest configs; run it before and after a change to see what the change rebuilds.

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
