# The emulator

**Revenant's emulator for legacy iPhone OS and iOS userlands, on macOS arm64.**

The emulator boots a firmware's own userland — launchd, the daemons, SpringBoard and the
applications — over an emulated XNU kernel, on a JIT-translated ARM CPU
([Dynarmic](https://github.com/MC-XiaoXiao/dynarmic), with our patches). It exists so that software built for
old iPhones, iPods and iPads can be started and tested on a Mac before it goes to
a real device.

## What it does

- Emulates the devices in `emulator profile --list`: iPhone 2G, 3G, 3GS, 4 and 4S,
  iPod touch 1, 2 and 4, iPad and iPad 2.
- Boots real firmware root filesystems from iPhone OS 3.0 through iOS 6.1.3 in
  Revenant's acceptance runs; the kernel ABIs it knows are listed by `emulator abi`.
- Draws the guest's OpenGL ES on a host Vulkan driver, plays its audio, delivers
  touch and button input, and answers the guest's IOKit, Mach and BSD calls itself.
- Publishes the hardware the firmware looks for — audio, baseband, display,
  keybag — the way the real devices do; the iPhone 4S's Voice audio device is
  described from a registry dump of a real one.
- Runs a test program inside the guest and hands back its result; that is how
  [toolchain](https://github.com/kern0x1b/revenant/tree/main/toolchain)'s `xmake emulate` uses it.

## How it works

`emulator boot` loads the root filesystem and starts `launchd` as the guest's first
process. The guest's CPU is translated to host code by Dynarmic; its system calls,
Mach messages and IOKit requests are answered by the emulator's own kernel model in
`src/kernel`, `src/mach` and `src/device_state`. Frameworks the emulated hardware
would serve — graphics, audio, telephony — are answered where they cross the
boundary, in `src/graphics`, `src/media` and `src/telephony`.

## Requirements

- macOS on Apple silicon, xmake 3.1.2 or later and a C++20 compiler (Apple clang).
- Every library comes as an xmake package, installed by the first configure: Dynarmic and Boost from revenant's
  `third_party` repository, OpenSSL, libplist and SwiftShader from Revenant's, libpng, libjpeg-turbo, the Vulkan headers, loader
  and memory allocator and the glslang library (for the shader compiler in `tools/glsl`) from xmake's; optionally SDL2 (a window) and FFmpeg (compressed
  audio).
- Nothing to install to draw: the build takes SwiftShader (Revenant's `swiftshader` package, a Vulkan driver on
  the CPU) and puts `libvk_swiftshader.dylib` beside the program, which loads it through the Vulkan loader by
  path, next to any driver the system has. Without a usable Vulkan driver a boot draws with the built-in
  reference renderer and logs one `[gles-renderer] Vulkan unavailable (...)` line saying why. The
  `swiftshader` package's first install builds SwiftShader with CMake, and the SPIRV-Tools inside it runs
  Python scripts to generate its tables; an install already in xmake's package store is reused as is.
- A root filesystem of the firmware to run, for example one unpacked by
  Revenant's `xmake firmware rootfs`.

## Build

The emulator is a member of revenant and builds from the top of revenant:

```sh
xmake f -y
xmake build emulator
xmake test
```

The options are `--emulator_vulkan` (on), `--emulator_sdl`, `--emulator_ffmpeg`, `--emulator_lto` (on, release only) and
`--emulator_dynarmic_test_emit_failure`, given to `xmake f`; `xmake f --menu` lists them. The guest probe in
`tools/guest` is built when `--emulator_guest_rootfs` and `--emulator_armv6_ld` name a root filesystem and an ARMv6
linker. Boost is the 1.81.0 release and needs no compiler flag with Apple clang 21.
Through the toolchain the build is the `emulator` package: `xmake emulate` builds and runs it.

## Usage

```sh
build/macosx/arm64/release/emulator profile --list
build/macosx/arm64/release/emulator boot --rootfs "$ROOTFS" --device iPhone4,1 --display headless --gles-backend software
```

`emulator --help` lists every verb: `profile`, `abi`, `inspect`, `catalog`,
`firmware prepare`, `disasm`, `boot`, `smoke` and `benchmark`. `--control-stdin`
reads commands such as `status`, `threads NAME` and `snapshot PATH` from
standard input while a guest runs, and `--gdb PORT` waits for a debugger; a guest
runs slower than a device, so `--time-scale 10` makes its clocks run at a tenth of
the host's, which the guest's own watchdogs need.

## Repository layout

| Path | Holds |
| --- | --- |
| `app/` | the `emulator` program: verbs, live control, the desktop window |
| `src/` | the library: kernel, Mach, device state, graphics, media, network, runtime |
| `xmake.lua`, `*/xmake.lua` | the build: one target per library, as the module folders are laid out |
| `tools/` | guest-side probes and the boot logo script |

The JIT core (Dynarmic, with our patches) and Boost are revenant's `dynarmic` and `boost` packages, in the
`third_party` package repository at the top of revenant.

## Documentation

| Document | About |
| --- | --- |
| [AGENTS.md](AGENTS.md) | the contributor guide |
| [CHANGELOG.md](CHANGELOG.md) | what changed |
| [THIRD-PARTY.md](THIRD-PARTY.md) | what is bundled or linked, and under which license |

## License

MPL-2.0, see `LICENSE`. Required notices are in `NOTICE`, and what is bundled or
linked is in `THIRD-PARTY.md`.

Built with Claude (Anthropic). This project is developed with AI assistance,
openly — see the commit history.
