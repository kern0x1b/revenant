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

## Build each package once

A package's key is its build hash: the platform, the architecture, its configs and the toolchain names.
The large packages put a digest of the files that make their output into a readonly config, so the key
changes exactly when those files do:

| Package | Digest config | Made from |
| --- | --- | --- |
| `swift-runtime`, `libcxx` | `recipe` | `port/digest.lua` in each recipe folder, which `toolchain/tools/recipe_digests.lua` writes from the recipe and the modules it runs |
| `llvm`, `swift` | `recipe` | the recipe and its patches |
| `swift-bootstrap` | `recipe` | the recipe; the swift.org package is held by the version's sha256, outside the digest |
| `iphoneos-sdk` | `additions` | what the recipe adds to the SDK |

A change to documentation rebuilds nothing. `./xmakew l -P . tools/keys.lua [package ...]` prints each large
package's key and its digest configs; run it before and after a change to see what the change rebuilds.

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
LLVM and Swift cap their link jobs at one for each 10 GiB of memory (`toolchain/modules/parallel.lua`,
`REVENANT_LINK_JOBS` overrides it).
