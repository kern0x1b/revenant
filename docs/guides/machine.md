# The machine: one cache, one clean, one pool

How a build uses this machine's disk, cores and memory, and how to give them back.

## One root for everything a build can make again

Everything a build can make again lives under `~/.revenant/cache`:

| Folder | What it is | Who writes it |
| --- | --- | --- |
| `xmake/<key>` | the pinned and patched xmake, one folder per pin and patch set | `xmakew` |
| `xmake-global/.xmake` | the package store (`packages`), the package sources and build folders (`cache`), the repositories | xmake, through `XMAKE_GLOBALDIR`, which `xmakew` sets |
| `ccache` | the compiler cache of every heavy build | `tools/heavy.lua` points `CCACHE_DIR` at it |
| `objects`, `lift`, `*.tsv`, `*.json`, others | caches of tools such as the lift, the corpus and the symbol tables | the tool that reads them |
| `machine` | scratch of an agent's measurement; nothing keeps it | whoever made it, who also deletes it |

`xmakew` exports `XMAKE_GLOBALDIR=$HOME/.revenant/cache/xmake-global` unless the caller set it already,
so every `./xmakew` installs packages into `~/.revenant/cache/xmake-global/.xmake/packages`, not into
`~/.xmake`. The packages installed before the move are still in `~/.xmake/packages`; the borrow
plugin copies them into the new store as clones, so they cost no second copy on APFS and need no build:

    ./xmakew borrow --from ~/.xmake

Once the new store has what the builds use, `~/.xmake` can go. That is the owner's call, and only the
coordinator removes it.

## The data that is not a cache

Everything under `~/.revenant` that is not `cache` is data. No clean touches it, at any level:

| Folder | What writes it | Why it is not a cache |
| --- | --- | --- |
| `dyld` | `toolchain/modules/apple/firmware.lua` (`firmware.ensure`, which `apple-backports` calls) | the shared caches and libraries of each iOS release, taken out of decrypted firmware; a band's build reads them, and making them again means fetching and decrypting firmware |
| `firmware` | `toolchain/modules/apple/firmware.lua` and the `firmware` plugin | the firmware catalog, the root file systems (`rootfs`), the work folders of a decryption, and `next`, a download that resumes |
| `emulator` | the emulator's own image commands | golden images that took a first boot to make; the emulator prunes its own `images.noindex` |
| `devices` | `toolchain/modules/device.lua` | the leases of the devices: which run holds which device |
| `cache-index` | `toolchain/tools/cache-index/build.lua`, from `dyld` | an index that can be built again from `dyld`; it stays beside `dyld` because its readers name that place, and moving it under `cache` is a change for its owner |
| `ipsw`, `extract`, `deps` | not this repository's code today | not this repository's to remove |

The rule: a folder belongs in `~/.revenant/cache` if, and only if, removing it costs only time and
nothing outside the machine. Every other folder is data, lives beside `cache`, and is removed only by the
tool that owns it.

## One clean

    ./xmakew l tools/clean.lua [--dry-run]
    ./xmakew l tools/clean.lua --packages [--dry-run]
    ./xmakew l tools/clean.lua --all [--dry-run]

| Level | Removes | Keeps |
| --- | --- | --- |
| default | each worktree's ignored `.xmake` and `build` (at the root, in each member, in each `frameworks/*`), every tool cache, the package sources and build folders of the store, the scratch, xmake's leftover build folders | the package store, ccache, the xmake binaries |
| `--packages` | the same and the package store | ccache, the xmake binaries |
| `--all` | everything under `~/.revenant/cache`; the xmake binaries go last and are built again on the next `./xmakew` | nothing under `~/.revenant/cache` |

It refuses while a heavy job is running, since that job is using what it would remove (`--force` overrides
this), and it prints what it freed and the folders it never touches. Only ignored and untracked build
folders are removed: `git check-ignore` decides, and a tracked `build` folder is left alone.

### Opt in: a volume with a quota

An APFS volume mounted at `~/.revenant/cache` caps the cache and makes wiping it a single step. It shares
free space with the rest of the container, so it reserves nothing.

    ./xmakew l tools/clean.lua --volume          prints the plan, changes nothing
    ./xmakew l tools/clean.lua --volume=120g     the same with another quota
    ./xmakew l tools/clean.lua --volume=80g --create

`--create` runs when no heavy job is running. It moves the current cache aside to
`~/.revenant/cache.before-volume` and runs:

    diskutil apfs addVolume disk3 APFS RevenantCache -quota 80g -mountpoint ~/.revenant/cache
    mdutil -i off ~/.revenant/cache
    tmutil addexclusion ~/.revenant/cache

Then it copies the xmake binaries back and prints the line that mounts the volume there at every boot. You
add that line to `/etc/fstab` with `sudo vifs`:

    UUID=<Volume UUID from diskutil info ~/.revenant/cache> /Users/<you>/.revenant/cache apfs rw

Without that line macOS mounts the volume under `/Volumes/RevenantCache` after a reboot, and
`~/.revenant/cache` is an empty folder again. Wipe everything in one step with:

    diskutil apfs eraseVolume APFS RevenantCache ~/.revenant/cache

What changes with a volume:

- A clone (`cp -c`, `clonefile`) does not cross volumes. Borrowing from `~/.xmake` into a store on the
  volume makes real copies, and so does any tool that clones between `~/.revenant/cache` and the rest of the
  home folder.
- The volume shares the container with the system, so free space is shared too: the quota is a cap, not
  a reservation.
- The quota ends a build that outgrows it with `No space left on device`. `--packages` or `--all` frees it.

Whether to make the volume is the owner's decision; nothing makes it without `--create`.

## One pool of cores

Every heavy job goes through one pool:

    ./xmakew l tools/heavy.lua <command ...>
    ./xmakew l tools/heavy.lua --exclusive <command ...>
    ./xmakew l tools/heavy.lua --status

`coordination/heavy.sh` forwards to it with the caller's `XMAKE_GLOBALDIR` and
`XMAKE_ADDONS_SOURCEDIRS`, so a caller outside this repository keeps its own.

The pool is a GNU make jobserver over a named pipe: it holds one token for each core less a reserve
(`FLEET_HEAVY_RESERVE`, 2), and every heavy job, and every tool inside it, takes tokens from the same pipe:

- `MAKEFLAGS=--jobserver-auth=fifo:<pipe>` is in each job's environment. ninja 1.13 and newer reads it when it is
  given no `-j`, GNU make 4.4 reads it, and the pinned xmake reads it for the package builds it runs
  (patch `0008`): ninja and meson are run without `-j`, and make, autoconf and cmake's Makefiles take
  the tokens that are free and pass `-j` with that many. Apple's `/usr/bin/make` 3.81 ignores the option.
- `XMAKE_MAX_JOBS` is the token count, and the pinned xmake takes its default job count from it.
- LLVM and Swift cap their link jobs with `LLVM_PARALLEL_LINK_JOBS` and `SWIFT_PARALLEL_LINK_JOBS`:
  one link for each 10 GiB of memory (`REVENANT_LINK_JOBS` overrides this). `toolchain/modules/parallel.lua`
  holds those numbers, so changing them does not change a package's key.

Admission:

- A job starts when no older ticket of its class is waiting. If other jobs are running, it also waits
  until `kern.memorystatus_level` is at least `FLEET_HEAVY_MIN_FREE` (20).
- The fast lane (`build-gate.lua`, `release-split.lua`, `run_light_tests.lua`) takes no token and has
  `FLEET_HEAVY_FAST_SLOTS` (2) places.
- The bulk lane (`lift-remeasure`, `emulate`, `run-emu`) takes a token and has
  `FLEET_HEAVY_BULK_SLOTS` (3) places.
- Every other job is in the slow lane and takes a token.
- `--exclusive` waits until nothing else is running, keeps everything else out, and gives up after
  `FLEET_HEAVY_EXCL_WAIT` seconds.
- A job started inside a job runs at once on its parent's tokens.

`--status` prints the pool, and `FLEET_HEAVY_LOG` (`/tmp/fleet-heavy/jobs.log`) has one line per job: its lane,
how long it waited and ran, and its exit code.

## Build each package once

A package's key is its build hash: the platform, the architecture, its configs and the toolchain names.
The heavy packages put a digest of the files that make their output into a readonly config, so the key
changes exactly when those files do:

| Package | Digest config | Made from |
| --- | --- | --- |
| `apple-backports` | `sources` | its `.c`, `.h`, `.m` and `.mm`, the registry, `spec/**`, `tools/gen/**`, `tools/found/**.lua`, the modules it runs, the corpus files it reads, the addon recipe, `revenant-coding`'s headers |
| `swift-runtime`, `libcxx` | `recipe` | `digest.lua`, which `toolchain/tools/recipe-digests.lua` writes from the recipe and the modules it runs, comments stripped |
| `llvm`, `swift` | `recipe` | the recipe and its patches |
| `swift-bootstrap` | `recipe` | the recipe, and the swift.org package by its sha256 |
| `iphoneos-sdk` | `additions` | what the recipe adds to the SDK |

None of them reads a document, so a change to documentation does not rebuild anything.
`./xmakew l tools/keys.lua [package ...]` prints each heavy package's key and its digest configs; run
it before and after a change to see what the change rebuilds.

Two requests for one package build it once. xmake locks each package's cache folder while it fetches,
downloads or installs, and after the lock it checks again whether the package is installed. Patch `0009`
does the same for a reinstall that a changed dependency causes. Patch `0010` waits for a lock without
stopping the process's other jobs, so two configures that each hold one lock and want the other's
continue instead of waiting forever.
