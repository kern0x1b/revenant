# Run a port on an emulated device

`xmake emulate` runs a port on an emulated iPhone or iPad with a firmware's own userland, on a macOS arm64 host. This guide shows how to test a library on it, how to launch an application, and how to read a crash. The verbs and the verdicts are in the [commands reference](../../reference/toolchain/commands.md); the reasons for the design are in [the explanation](../../explanation/toolchain/design.md#why-there-is-an-emulator).

## Include the emulator

A port that runs on the emulator includes it after the `apple-ios` include:

    set_config("apple_minimum", "6.0")
    includes("@addon/revenant/apple-ios")
    includes("@addon/revenant/emulate")

The include requires the emulator package, the guest programs `revenant-runner` and `revenant-sblaunch`, and SwiftShader for OpenGL ES.

## Test a library

A device test of a library is a program that prints its own result and exits with the number of failures. It needs no UIKit and no SpringBoard:

    -- xmake.lua of the test port
    add_repositories("revenant /path/to/revenant")
    add_addons("revenant latest")
    set_config("apple_minimum", "6.0")
    add_deps("FoundationBackports")
    includes("@addon/revenant/apple-ios")
    includes("@addon/revenant/emulate")

    target("backports-test")
        set_kind("binary")
        add_rules("@addon/revenant/daemon")
        add_files("test.m")
        add_deps("FoundationBackports")
        add_frameworks("Foundation")
        set_values("revenant.version", "1.0")
        set_values("revenant.control", "packaging/control")

Then, from the test port:

    xmake f -p iphoneos -a armv7 -y
    xmake emulate -d iPhone3,1 -r 6.0 install
    xmake emulate -d iPhone3,1 -r 6.0 run /usr/libexec/backports-test

`add_repositories` points at a working copy of the repository, so an edit under `modules/` or in a package reaches the test only once it is committed in that copy; see [the contributing guide](contributing.md#traps). `run` reports `pass`, `fail(exit N)`, `timeout`, `crash(signal N)` or `boot-blocked(...)` as its verdict, and its exit status is the same verdict.

A test that needs a longer budget takes `-s` (the deadline of the command, in guest seconds) and `-t` (the wall-clock limit of the whole boot). A device test that must hold its own clock sets `set_values("emulate.timing", "strict")`, and the run then refuses any scale but 1.

## Launch an application

`launch` installs the application and has SpringBoard start it, so that its `application:didFinishLaunchingWithOptions:` runs; `run` cannot do that, because a program started by `run` is outside SpringBoard.

    xmake emulate -d iPhone4,1 -r 6.1.3 launch com.example.app tap 160 240 home

The steps after the bundle identifier are in points: `tap X Y`, `drag X1 Y1 X2 Y2`, `home`, and `until-exit`. After each step the emulator settles the screen and writes a snapshot. `until-exit` holds the guest until the application has ended, so an application that produces its result over time is given the time to produce it; the verdict says in `held` whether the application's own end or the run's budget came first.

Read what the run wrote with `xmake emulate log [TEXT]`, and the last frame with `xmake emulate shot [FILE]`. An application that writes into `/var/revenant` leaves its files in the run folder, which `launch` names.

The guest has no network unless `-n` or the target's `emulate.network` names `loopback` or `host`.

## Read a crash

A program that crashes on the guest says only where it stopped. `debug` starts it as the guest's first process, so the report holds only the program and what it loads, and stops where it crashes:

    xmake emulate debug /usr/libexec/crasher

    /usr/libexec/crasher stopped with signal 11 on iPhone3,1 6.0 (10A403)
      #0  pc     0x0000bf86  crasher`_wrong + 0x6
      #1  lr     0x0000bf7d  crasher`_main + 0x34
      #2  return 0x36e20b20  libdyld.dylib + 0x1b20

The frames are the chain the frame pointer holds, named by dyld's own list of images, with the nearest symbol of each image the toolchain holds as a file. The whole reading, registers and images included, is left beside the log as `debug.json`.

A boot that never ran the command says where it stopped: the emulator, a process that keeps crashing, SpringBoard, or the data migration. The reports the guest wrote are copied beside the verdict, and the first one names why its daemon was killed.

## Devices and releases

`-d` names the device; without it, the first device the emulator has a profile for, of the configured architecture, that runs the release. `-r` names the release; without it, `apple_minimum`. The emulator runs the earliest firmware not older than the release, and refuses a device without a profile, or a release whose Darwin it does not emulate, with the reason. Device names are as the firmware catalogue names them: `iPhone3,1`, `iPhone4,1`, `iPad2,1`.

The first run of a device and release unpacks its root filesystem, marks Setup Assistant done, and boots it once past the data migration. The result is a golden image under `~/.revenant/emulator/golden.noindex/`, keyed by device, build and the emulator package. Each run after that clones it, so the first run is slow and the rest are not. A golden image of an older emulator package is removed when the new one is made.

To unpack a root filesystem by hand:

    xmake firmware --device=iPhone3,1 rootfs 6.0

Several ports and sessions emulate at once. A boot takes one of the machine's slots, which number `max(1, min(cores // 3, RAM // 5 GB))` (at least one, even on a small machine), and a second session waits for a golden image being built rather than building it again.

## Time

The guest's clock runs slower than the host's. `--scale` is how many host seconds one guest second takes, and it defaults to 10. Raise it for a slow test; lower it only with a reason. The scale is printed by each run and recorded in the verdict, with `guest_seconds` beside `host_seconds`, so a test that measures time can convert them.

## Clean up

    xmake emulate clean          this port's images
    xmake emulate clean -a       every image and golden image

Images unused for `--prune-hours` (default 24) are removed by the next `xmake emulate` run.
