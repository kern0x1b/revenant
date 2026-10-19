---
name: emulate-port
description: Run a charon port (a daemon, a test probe, an application, a package) on an emulated iOS device with `xmake emulate` instead of a phone — install, run, launch an app through SpringBoard and tap it, debug, log, shot, clean — and know what the emulator can and cannot prove. Use when a device is busy or not needed, for a fast loop on daemon-shaped code, to see an app's screen and output, or when asked to "run it in shade / the emulator".
---

# `xmake emulate`

macOS arm64 hosts only. The emulator is Shade, built by the `charon@shade` package (pinned by
commit, patches under `packages/s/shade/patches/`); the `shade` repository is its source, not what
this command runs.

## Setup in the port's xmake.lua

```lua
includes("@addon/charon/apple-ios")
includes("@addon/charon/emulate")      -- after apple-ios; requires charon@shade, charon@swiftshader, charon@emulator-guest
```

## Commands (from the port's project directory)

```
xmake emulate install                          # the port's packages into the emulated image; registers its apps with SpringBoard
xmake emulate [-s 60] [--scale 10] run COMMAND # verdict: pass, fail, crash, timeout or boot-blocked
xmake emulate launch BUNDLE-ID [tap X Y | drag X1 Y1 X2 Y2 | home | until-exit ...]
                                               # install + register + SpringBoard launch; app output and app-N.png snapshots
xmake emulate debug COMMAND                    # COMMAND as first guest process, under the debugger
xmake emulate log [TEXT]                       # what the last run left
xmake emulate shot [FILE]                      # its last frame
xmake emulate clean                            # this port's images and every port's shared tmp and cache (--all: every image and golden image)
```

Options: `-d DEVICE` (e.g. `iPhone3,1`; default the first catalog device of the configured
architecture that Shade has a profile for), `-r RELEASE` (default `apple_minimum`),
`-t/--timeout` (900 s for a whole boot), `-k/--keep` (keep the booted rootfs beside the log),
`-n isolated|loopback|host`, `--scale` (guest time scale, default 10).

- `fail(spawn error 2)`: the command is not in the image — `xmake emulate install` first.
- Configure the port (`xmake f -p iphoneos -a armv7 -y`) before `install`: the packages it copies
  must already be installed in the store.
- Pass `-d`: the default device is the first of the catalog, for armv7 an iPhone2,1, whose firmware
  is downloaded (about a gigabyte) and booted into a golden image first if it is not in `~/.charon`
  yet. `-d iPhone4,1 -r 6.1.3` is the fleet's 4S and has a golden image.

## Launching an application

```
xmake emulate -d iPhone4,1 -r 6.1.3 launch org.example.app tap 160 260
```

- The app needs a `CFBundleIdentifier` (`set_values("app.plist", "CFBundleIdentifier=...")`); `launch`
  refuses a bundle identifier the port's packages do not install and names the ones they do.
- It prints the app's standard output and error (`printf` + `fflush`, and `NSLog`), then one
  `app-N.png` per snapshot: `app-0.png` once the app is frontmost and Shade reports the screen still
  (`settle`, 60 display periods of guest time), then one after each step, settled the same way.
  They stay in the run folder; the log line names it.
- Steps are in points (320x480 on an iPhone, 768x1024 on an iPad), portrait, the status bar
  included: a view at y in its controller is at y + 20 on the screen.
- `until-exit` is the one step the emulator is not sent: it holds the guest until the application has
  ended, then settles and takes one more frame. Use it for an application that produces its result
  over time (Eidolon's snapshot bundle renders 37 scenarios and then quits). The frame it takes is the
  screen as it was after the application ended — SpringBoard takes the screen back — so the frame of the
  application itself is the one before it. The hold ends at the first of two things, and the verdict
  and the last lines of the log say which: `held: exited` (the application ended, after N guest seconds
  from being frontmost) or `held: deadline` (the application's budget, `-s` guest seconds from the
  moment it was frontmost, was spent while it still ran). A run that needs longer raises `-s` (and `-t`,
  the host limit of the whole boot, which has to cover `-s` times the time scale: 2400 for `-s 240` at
  the default scale) rather than reading
  `deadline` as success. The runner's `verdict.json` is not what ends the hold: it is written when
  `charon-sblaunch` returns, at launch. The whole run folder is kept
  beside the log, and `/var/charon` is in it, so whatever the application wrote there comes out of the
  guest — that is how a port's own result files are read.
- `-s` is how many guest seconds `charon-sblaunch` waits for SpringBoard to take the launch and make
  the app frontmost (at the default scale that is ten times as many host seconds) and, with `until-exit`,
  how many the application may then run (counted by the host's clock at the time scale, from the moment
  it is frontmost). While the screen
  is locked, `launch` unlocks it over the control channel on its own. Its states carry guest seconds:
  on an idle machine SpringBoard took the launch of 6.1.3 at 15 s; on one loaded far past its cores
  it was not ready in 60, since a starved guest does less in each guest second. Raise `-s` (and `-t`)
  there rather than read the refusal as the app's.
- An animation that never stops never settles: the run ends at `-t` without the snapshot.
- A failure names its cause: SpringBoard's refusal code, the signal or status the app ended with, or
  that its process never started. Look at the snapshot before believing a pass: the verdict says the
  app ran and drew, not that it drew the right thing.

## What it proves and what it does not

- Daemons (`@addon/charon/daemon`, no `UIApplicationMain`) run: use it for them.
- A UIKit app started by `run` never reaches `application:didFinishLaunchingWithOptions:` — it
  bypasses SpringBoard's launch, and the frames drawn are SpringBoard's. Use `launch` for an app,
  which goes through SpringBoard but is not a tap on the icon: it runs with an environment of its
  own (`CFLOG_FORCE_STDERR=1`, `NSUnbufferedIO=YES`) and its output redirected to files.
  Anything living inside an app (text views, collection layout, gestures) is checked on hardware
  (workspace skill `device-session`): the emulator draws through SwiftShader, which is not the
  oracle for UIKit text or collection layout. What depends on timing or the GPU is held to hardware too.
- No audio daemon: `kAudioSessionNotInitialized` there is the emulator, not the code.
- Without a time scale the guest's own watchdogs expire (SpringBoard is lost to a mediaserverd
  timeout); keep the default `--scale 10`.
- A device without a Shade profile, or a release whose Darwin Shade does not emulate, is refused
  with the reason — not replaced by another.
- Images, and a rootfs kept with `-k`, live in the emulator root beside the dyld caches
  (`~/.charon/emulator`), not in the project; copy the log and verdict you need into
  `.agent-work/runs/`. Do not run `xmake emulate clean` while other sessions use the emulator: it
  always removes the shared `tmp.noindex` and `cache.noindex` too, and every other port's next run
  starts cold.
- `checking for Xcode SDK ... no` is not a failure. It is xmake's check of the *host* platform, which
  it prints once before it switches to the target, and it is there in every configure that succeeds.
  The SDK and the linker a guest build uses come from `charon@iphoneos-sdk` and `charon@ld64` through
  the addon's `apple-ios` toolchain, and `xmake show -t <target>` reads the paths: look for
  `-isysroot ~/.xmake/packages/i/iphoneos-sdk/...` and `-fuse-ld=~/.xmake/packages/l/ld64/.../ld`.
  There is no Xcode on this machine and a port does not need one; `set_allowedplats`/`set_allowedarchs`
  are what main's own guest ports write, but a project with only
  `set_defaultplat`/`set_defaultarchs` lands on the same addon toolchain - measured on a scratch
  `daemon` port, which configured and produced those flags with neither pair.
- `package(<name>) is being accessed by other processes, please wait!` is a run **waiting for the
  shared store**, not failing: the last line of the log, and then nothing, for as long as the other
  build holds the lock. The lock is `~/.xmake/cache/packages/<xy>/<name>/<version>/package.lock` and
  `lsof` on it names the holder. Nothing in a port changes it; a configure that is waiting must not
  be left running, and a run whose log ends on that line has not configured.
- A hash of the file in the image is not the hash of what `xmake build` wrote, and must not be compared.
  Wrong: `shasum` of `rootfs/usr/libexec/<name>` against `build/<plat>/<arch>/<mode>/<name>`, read as
  "the image is stale". Right: compare the **sizes**, and read the per-file lines `install` prints.
  Reason, measured on `tests/backports/host/dragdroprouting` on 2026-09-28: the build output is
  166296 B and the installed file 125776 B, because `platform.install_placed` copies the target file
  into the stage and then `finish`es **that copy** - `xcrun strip -x` and `ldid -S` - leaving the
  build output raw. And the installed file's hash can never be compared at all: two `ldid -S`
  signatures of one input are the same size and different bytes. An install cannot leave an older file
  behind either - `clone()` removes the image rootfs before copying the golden into it, and
  `emulator.place` removes each target before copying - so a size that differs is the finishing, not
  staleness.

