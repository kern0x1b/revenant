---
name: firmware
description: Get Apple's files for the app's iOS releases onto the user's own Mac with Revenant's `xmake firmware` — the dyld shared cache the import check reads for the lowest release, the root filesystem the emulator boots for each device and release to check, and the Objective-C class inventory of a release — downloaded from Apple's servers on the user's machine, never shipped. Says where they land, what they cost in disk and download, and how to check what is already held. Use after install and before the first build, when a build says the imports cannot be checked without a release's libraries, before the first emulator run, or when asked whether a class or symbol exists on a release.
---

# Apple's files, fetched on the user's machine

The import check and the emulator read Apple's own system files: the release's dyld shared cache
(every library the device has) and a device's whole root filesystem. Nothing of Apple's may be
copied into the project, this plugin or a package. The toolchain fetches them from Apple's firmware
servers on the user's machine, into a cache outside the project that every project shares.

Read `PROJECT.md` first: the lowest release (`apple_minimum`), the architectures, the devices
and the releases to check. The commands below are tasks of the revenant addon, so they run in the
project directory after the skill `install` wrote the pin and the `apple-ios` include into
`xmake.lua`.

## Where things land

Under `~/.revenant` (or `$REVENANT_HOME` if the user set it):

| What | Path | Size (armv7, iOS 6) |
| --- | --- | --- |
| a release's shared cache | `~/.revenant/dyld/<release>/dyld_shared_cache_<arch>` | about 230 MB |
| its selectors and classes | beside it: `selectors_<arch>.txt`, `classes_<arch>.json` | a few MB |
| a release before 3.1 (no cache) | `~/.revenant/dyld/<release>/libraries_<arch>/` | |
| a device's root filesystem | `~/.revenant/firmware/rootfs/<device>/<version>_<build>/` | about 1.2 GB |
| the firmware catalog | `~/.revenant/firmware/catalog.json` | small |

Downloads: the catalog comes from api.ipsw.me and theapplewiki.com; the firmware itself from
Apple's servers. Only the system image inside the IPSW is downloaded, by byte ranges; for an
armv7 iOS 6 firmware the whole IPSW is 0.8–0.9 GB, so plan for up to that per release. The
system images of iOS 2 to 9 are decrypted with the keys theapplewiki publishes, then mounted with
`hdiutil` to copy the files out. Temporary work goes to `~/.revenant/firmware/work/` and is removed.

## 1. See what is held

```
xmake firmware list
```

One line per release: the release, then the architectures whose libraries are held, e.g.
`6.0  armv7 armv7s`. For root filesystems: `ls ~/.revenant/firmware/rootfs/<device>/`.

## 2. The libraries for the import check

The check reads the **earliest release of each architecture not older than `apple_minimum`**:
armv7 with `apple_minimum` 6.0 reads 6.0; an armv7 build for 6.1.3 reads 6.1.3. Fetch it:

```
xmake firmware -y --arch=armv7 fetch 6.0 > .logs/firmware-6.0.log 2>&1
```

How to know it worked: the last line is
`<home>/.revenant/dyld/6.0/dyld_shared_cache_armv7: iOS 6.0 for armv7`. When the release is already
held, it prints that line at once and downloads nothing.

- A universal app (`armv7` and `arm64`) is checked per slice: the arm64 slice reads 7.0, so fetch
  `--arch=arm64 fetch 7.0` as well.
- Without this step the first build asks to fetch it itself (with `-y` it accepts); answered no,
  it stops with `the imports of this armv7 build cannot be checked without the libraries
  of iOS 6.0; run xmake firmware --arch=armv7 fetch 6.0`.

## 3. The root filesystem for each device and release to check

The emulator boots a device's own userland. For every device and release pair in `PROJECT.md`
that will be checked in the emulator:

```
xmake firmware -y --device=iPhone3,1 rootfs 6.0 > .logs/rootfs-iPhone3,1-6.0.log 2>&1
```

How to know it worked: the last line is
`<home>/.revenant/firmware/rootfs/iPhone3,1/6.0_10A403: iPhone3,1 iOS 6.0 (10A403)`. It takes the
device's earliest firmware not older than the release, so the folder name says which build it
really is. A pair already unpacked prints its line at once.

The first `xmake emulate` run of a device and release unpacks this by itself if it is missing;
doing it here moves the download out of the emulator step and shows early whether the firmware
exists for that device. Which pairs the emulator can boot is the skill `emulate`'s business
(iOS 7 is declared and has never been booted; iOS 8 and 9 cannot be emulated; a real device
checks those).

## 4. The class inventory (optional, for writing code)

To answer "does this class exist on this release", write the release's Objective-C inventory
somewhere you can read it:

```
xmake firmware -y --arch=armv7 --output=.logs/classes-6.0.json classes 6.0
```

It prints `…/classes-6.0.json: the Objective-C classes of iOS 6.0 for armv7`. The JSON has
`release`, `architecture` and `classes`: each class with `superclass`, `image`, `instance` and
`class` methods and `protocols`, categories merged in. Look a class up in it (for example with
`jq`) before using it on that release. Without `--output` it goes beside the
cache as `classes_<arch>.json`. The SDK's headers are iOS 16.4 and do not tell what a release
has; this file and the import check do.

## 5. Record it

In `PROJECT.md` under `## Progress`, the firmware line: each release and architecture held (the
`xmake firmware list` line) and each root filesystem folder, with the log paths.

Then follow the skill `project`.

## Traps

- Copying a `dyld_shared_cache` from a jailbroken device into `~/.revenant/dyld` → fetch it with
  `xmake firmware`. Reason: a cache taken from a running device holds pointers the device slid;
  The toolchain refuses it and says to fetch the release from the firmware.
- Putting a cache, a root filesystem, an extracted library or an SDK header into the project, a
  commit or a package → never. They are Apple's; each user fetches them on their own machine.
- Running `xmake firmware` outside the project → run it where `xmake.lua` has the pin and the
  `apple-ios` include. Reason: the task comes from the addon the project pins, and it needs the
  project's `revenant-firmware` tool (`the project requires no firmware-tools` otherwise).
- Deleting `~/.revenant` to "refresh" it → do not; a held release never changes. Every project on
  the machine reads the same files, and the emulator keeps its booted images under
  `~/.revenant/emulator/`, which would be rebuilt from scratch.
- Fetching every release "to be safe" → fetch the lowest release per architecture and the
  device/release pairs to check. Each release is another download of up to a gigabyte.
