---
name: shade-boot
description: Build this Shade checkout and boot a firmware root filesystem with it to check that a change works — the CMake build, `shade profile --list`, a headless boot at `--time-scale 10`, and reading the log for fatal CPU faults, frames and started processes; attach gdb or drive the guest over `--control-stdin`. Use after changing Shade, or when asked to build, boot or debug it.
---

# Build Shade and boot a root filesystem

## 1. Build

```sh
git submodule update --init
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

The program is `build/shade`. Options: `SHADE_ENABLE_SDL2`, `SHADE_ENABLE_VULKAN`,
`SHADE_ENABLE_IPO`. `build/shade --help` lists the verbs.

## 2. Pick a device and a root filesystem

```sh
build/shade profile --list                      # the device profiles, e.g. iPhone4,1
build/shade profile --device iPhone4,1          # one profile's details
```

A root filesystem comes from charon's `xmake firmware --device=ID rootfs RELEASE` (unpacked under
`$HOME/.charon/firmware/rootfs/<device>/`). Boot a clone, never the shared tree:

```sh
run=.agent-work/runs/<name>; mkdir -p $run
cp -c -R "$HOME/.charon/firmware/rootfs/<device>/<release_build>" $run/rootfs
```

## 3. Boot headless

```sh
perl -e 'alarm 300; exec @ARGV' build/shade boot --rootfs $run/rootfs --device iPhone4,1 \
    --display headless --gles-backend software --time-scale 10 > $run/boot.log 2>&1
```

A boot runs until it is stopped: the `alarm` bounds it (`--ticks N` bounds it in CPU ticks).
`--verbose` adds every trace line; without it only the lifecycle lines below are printed.

## 4. Read the log

```sh
grep -a '\[cpu\] fatal' $run/boot.log                 # a guest process died on a CPU fault
grep -a '\[display\] frame=' $run/boot.log | tail -3  # the frame counter: rising means drawing
grep -a '\[process\] spawn-setexec' $run/boot.log     # which programs launchd started
```

A working boot has no `[cpu] fatal` line for a system process, a frame counter that keeps rising,
and `SpringBoard` among the spawned programs.

## 5. Debug and drive

- `--gdb PORT` starts the gdb remote stub and waits for a debugger; threads are `pPID.TID`.
- `--control-stdin` reads commands from standard input while the guest runs: `help`, `status`,
  `ps`, `threads NAME`, `snapshot PATH`, `tap X Y [HOLD_MS]`, `home`, `quit`.
- `--display sdl` opens a window (a build with SDL2).

## Traps

- `xmake emulate` (charon) does not use this checkout: it builds and runs its own pinned copy through the `charon@shade` package.
- Without `--time-scale 10` the guest's watchdogs expire: iOS 6.1.3 loses SpringBoard every 100 s to a mediaserverd timeout.
- The emulator writes `.shade-device-state` beside the root filesystem it boots: boot a clone in the run directory, not the shared rootfs.
- The `[cpu] fatal`, `[display] frame=` and `[process] spawn-setexec` lines are what charon reads: do not reword them without changing its reader.
