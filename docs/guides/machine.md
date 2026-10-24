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
| `emulator` | the emulator's image commands | golden images that took a first boot to make |
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
| `dynarmic` | `recipe` | the recipe and its patches |
| `swift-bootstrap` | `recipe` | the recipe; the swift.org package is held by the version's sha256, outside the digest |
| `iphoneos-sdk` | `additions` | what the recipe adds to the SDK |

A change to documentation rebuilds nothing. `./xmakew l -P . tools/keys.lua [package ...]` prints each large
package's key and its digest configs; run it before and after a change to see what the change rebuilds.

The build hash also ends with the digest of the xmake patch set the binary was built with. xmakew writes that digest to
`share/xmake/revenant-patch-set` beside the binary, and patch `0019` folds it into every variant of the hash, so a changed
xmake patch moves every package's key once. A binary without the file refuses to compute a build hash.
`toolchain/tests/addon/patch_set_test.lua` checks that a different digest moves a key, that a copy with the same digest
does not, and that a change to a package's description does not.

Open: the build hash leaves out a package's own recipe patch set unless the package has a `recipe` or `additions` digest
config. Two recipes with the same version and different patches then share one install, and the second project gets the
first one's patched files. The source directory is not the cause: a git checkout is reset and its patches are applied
again for each install. `toolchain/tests/addon/source_patch_test.lua` checks a digest-configured recipe, `dynarmic`, which
installs its own patches. Keying the build hash on each recipe's patch set is not made. Until it is, these packages have
no digest of their patches: `boringssl`, `farmdec`, `ffmpeg`, `iphoneos-sdk` (its 16.4 patch is outside its `additions`
digest), `ldid`, `openssl`, `swiftshader` and `xmake`.

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

Two crutches are left in the store generation work. A process that dies between the fetch that validates a staged
install and the fetch after its publish leaves the generation path in the detect cache until the next install of that
package (patch `0017`). The store race test (`toolchain/tests/addon/store_race_test.lua`) reads the include and library
folders only, so the bindir, rpath and pkgconfig paths of a package have no test.
LLVM and Swift cap their link jobs at one for each 10 GiB of memory (`toolchain/modules/parallel.lua`,
`REVENANT_LINK_JOBS` overrides it).
