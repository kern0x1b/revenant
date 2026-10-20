---
name: emulator-session
description: Use when a task needs an emulated iOS device instead of a phone: build the emulator in emulator/ and boot a firmware root filesystem with it to check a change to it, or run a port on the emulator with `xmake emulate` (install, run a command, launch an app and tap it, debug it, read its log, take its last frame). Says what the emulator can and cannot prove. For real hardware, use the device skill.
---

# Emulator

macOS arm64 hosts only. The name covers two things: the emulator program built from `emulator/`, and `xmake emulate`, which runs a port on the emulator that `packages/emulator/emulator/xmake.lua` pins. That package builds the pinned commit of the emulator from git, not the working tree, so a change to `emulator/` reaches `xmake emulate` only through a new pin.

## Build and boot the emulator

From the top of revenant:

- `./xmakew f -y`, then `./xmakew build emulator`, then `./xmakew test`.
- The program is `build/macosx/arm64/release/emulator`; below, EMU stands for it. `EMU --help` lists the verbs.
- Options to `./xmakew f`: `--emulator_sdl=y` for a window (`--display sdl`), `--emulator_vulkan` (on by default), `--emulator_lto`.
- `EMU profile --list` lists the device profiles, `EMU profile --device iPhone4,1` shows one.

A root filesystem comes from `./xmakew firmware --device=iPhone4,1 rootfs 6.1.3`, unpacked under `$HOME/.revenant/firmware/rootfs/<device>/<version>_<build>`. Boot a clone, never the shared tree, since the emulator writes `.emulator-device-state` beside the rootfs it boots:

    run=$HOME/.revenant/cache/<task>/boot
    mkdir -p "$run"
    cp -c -R "$HOME/.revenant/firmware/rootfs/iPhone4,1/<version>_<build>" "$run/rootfs"
    perl -e 'alarm 300; exec @ARGV' EMU boot --rootfs "$run/rootfs" --device iPhone4,1 --display headless --gles-backend software --time-scale 10 > "$run/boot.log" 2>&1

- `--time-scale 10` is required. At 1 the guest's watchdogs expire, and iOS 6.1.3 loses SpringBoard every 100 s to a mediaserverd timeout.
- A boot runs until it is stopped. `alarm` bounds it in wall time, `--ticks N` in CPU ticks.
- The build carries SwiftShader beside the program and the emulator loads it through the Vulkan loader, with no environment variable. The log names the renderer on `[gles-renderer] selected ...`. Without a usable driver it says `[gles-renderer] Vulkan unavailable (...)` and draws with the reference renderer.
- `--verbose` adds every trace line.

Read the log:

- `grep -a '\[cpu\] fatal' "$run/boot.log"`: a guest process died on a CPU fault. A system process here means a failed boot.
- `grep -a '\[display\] frame=' "$run/boot.log" | tail -3`: a frame counter that keeps rising means it draws.
- `grep -a '\[process\] spawn-setexec' "$run/boot.log"`: the programs launchd started. A working boot starts SpringBoard.

Drive and debug:

- `--control-stdin` reads commands while the guest runs: `help`, `status`, `ps`, `threads NAME`, `snapshot PATH`, `tap X Y [HOLD_MS]`, `home`, `quit`. `docs/reference/emulator/control-surface.md` has the rest.
- `--gdb PORT` waits for a gdb remote client (`emulator/src/debug/`).

## Run a port on the emulator: `xmake emulate`

Inside revenant, `./xmakew` stands for `xmake`. The port's `xmake.lua` includes the emulate addon after apple-ios; the include requires `revenant@emulator`, `swiftshader` and `emulator-guest`:

    includes("@addon/revenant/apple-ios")
    includes("@addon/revenant/emulate")

Run these from the port's directory, after configuring it (`xmake f -p iphoneos -a armv7 -y`), because `install` copies packages from the store:

- `xmake emulate install`: the port's packages into the emulated image, and registers its apps with SpringBoard.
- `xmake emulate run COMMAND`: runs COMMAND in a fresh clone of the image. The verdict is pass, fail, crash, timeout or boot-blocked. Daemons (`@addon/revenant/daemon`, no `UIApplicationMain`) are what `run` is for.
- `xmake emulate launch BUNDLE-ID [tap X Y | drag X1 Y1 X2 Y2 | home | until-exit] ...`: installs, registers and launches the app through SpringBoard, prints its stdout and stderr, and writes `app-N.png` snapshots: one once the app is frontmost and settled, one after each step.
- `xmake emulate debug COMMAND`: COMMAND as the first guest process, under the debugger.
- `xmake emulate log [TEXT]`: what the last run left, filtered.
- `xmake emulate shot [FILE]`: the last frame.
- `xmake emulate clean [--all]`: see below.

Options: `-d DEVICE` (default: the first catalog device of the configured architecture that the emulator profiles and that runs the release; `-d iPhone4,1` names the 4S), `-r RELEASE` (default `apple_minimum`), `-s` guest seconds the start or the app may take (default 60), `-t` the wall-clock limit of a whole boot (default 900 s), `-k` keeps the rootfs of the run, `-n isolated|loopback|host`, `--scale` (default 10). The first use of a device and release fetches its firmware and boots a golden image, which is slow.

Launching an app:

- `xmake emulate -d iPhone4,1 -r 6.1.3 launch org.example.app tap 160 260`.
- The app needs a `CFBundleIdentifier`, set with `set_values("app.plist", "CFBundleIdentifier=...")`. `launch` refuses an identifier the port's packages do not install and lists the ones they do.
- Steps are in points, portrait, status bar included: 320x480 on an iPhone, 768x1024 on an iPad. A view at y in its controller is at y + 20 on the screen.
- `until-exit` holds the app until it ends, then takes one more frame. That frame is the screen after SpringBoard takes it back, so the app's own frame is the one before it. Use it for an app that produces its result over time, such as the SwiftUI snapshot bundle. The hold ends at `held: exited`, or at `held: deadline` when the `-s` budget ran out while the app still ran. For `deadline` raise `-s` and `-t` together (`-t` must cover `-s` times the scale). Never read `deadline` as success.
- A pass says the app ran and drew, not that it drew the right thing. Look at the snapshot.
- The run folder is under `~/.revenant/emulator/images.noindex/`, and the log line names it. Copy what you need into `$HOME/.revenant/cache/<task>/`. Files the app writes under `/var/revenant` come out in the run folder.

`xmake emulate clean` removes this port's images and also the emulator's shared `tmp.noindex` and `cache.noindex`, so every port's next run starts cold. `--all` removes every port's images and golden images. Each run also removes images unused for 24 hours (`--prune-hours`).

## What it proves and what it does not

- The emulator draws through SwiftShader, not a device GPU. UIKit text, collection layout, gestures, timing and GPU behaviour are checked on a real device (the `device-session` skill).
- A UIKit app started by `run` never reaches `application:didFinishLaunchingWithOptions:`, and the frames are SpringBoard's. Use `launch` for an app.
- There is no audio daemon. `kAudioSessionNotInitialized` there is the emulator's, not the code's.
- A device without an emulator profile, or a release whose Darwin the emulator does not emulate, is refused with the reason. Nothing is substituted.
- Files in the image are not the bytes `xmake build` wrote: `install` strips and signs them. Compare sizes, and read the per-file lines `install` prints. Never compare a hash against `build/`.

## Traps

- `fail(spawn error 2)`: the command is not in the image. Run `install` first.
- `checking for Xcode SDK ... no` is xmake's check of the host. It prints in every configure and is not a failure.
- `package(<name>) is being accessed by other processes, please wait!` is a wait for the shared package store, not a failure. The run has not configured until the wait ends.
