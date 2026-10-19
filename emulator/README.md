# Shade

**Charon's emulator for legacy iPhone OS and iOS userlands, on macOS arm64.**

Shade boots a firmware's own userland — launchd, the daemons, SpringBoard and the
applications — over an emulated XNU kernel, on a JIT-translated ARM CPU
([Dynarmic](https://github.com/MC-XiaoXiao/dynarmic), with our patches). It exists so that software built for
old iPhones, iPods and iPads can be started and tested on a Mac before it goes to
a real device.

## What it does

- Emulates the devices in `shade profile --list`: iPhone 2G, 3G, 3GS, 4 and 4S,
  iPod touch 1, 2 and 4, iPad and iPad 2.
- Boots real firmware root filesystems from iPhone OS 3.0 through iOS 6.1.3 in
  Charon's acceptance runs; the kernel ABIs it knows are listed by `shade abi`.
- Draws the guest's OpenGL ES on a host Vulkan driver, plays its audio, delivers
  touch and button input, and answers the guest's IOKit, Mach and BSD calls itself.
- Publishes the hardware the firmware looks for — audio, baseband, display,
  keybag — the way the real devices do; the iPhone 4S's Voice audio device is
  described from a registry dump of a real one.
- Runs a test program inside the guest and hands back its result; that is how
  [Charon](https://github.com/kern0x1b/charon)'s `xmake emulate` uses it.

## How it works

`shade boot` loads the root filesystem and starts `launchd` as the guest's first
process. The guest's CPU is translated to host code by Dynarmic; its system calls,
Mach messages and IOKit requests are answered by Shade's own kernel model in
`src/kernel`, `src/mach` and `src/device_state`. Frameworks the emulated hardware
would serve — graphics, audio, telephony — are answered where they cross the
boundary, in `src/graphics`, `src/media` and `src/telephony`.

## Requirements

- macOS on Apple silicon, xmake 3.1.2 or later and a C++20 compiler (Apple clang).
- Every library comes as an xmake package, installed by the first configure: Dynarmic and Boost from hades'
  `third_party` repository, OpenSSL, libplist and SwiftShader from charon's, libpng, libjpeg-turbo, the Vulkan headers, loader
  and memory allocator and the glslang library (for the shader compiler in `tools/glsl`) from xmake's; optionally SDL2 (a window) and FFmpeg (compressed
  audio).
- Nothing to install to draw: the build takes SwiftShader (charon's `swiftshader` package, a Vulkan driver on
  the CPU) and puts `libvk_swiftshader.dylib` beside the program, which loads it through the Vulkan loader by
  path, next to any driver the system has. Without a usable Vulkan driver a boot draws with the built-in
  reference renderer and logs one `[gles-renderer] Vulkan unavailable (...)` line saying why. The
  `swiftshader` package's first install builds SwiftShader with CMake, and the SPIRV-Tools inside it runs
  Python scripts to generate its tables; an install already in xmake's package store is reused as is.
- A root filesystem of the firmware to run, for example one unpacked by
  Charon's `xmake firmware rootfs`.

## Build

Shade is a member of hades and builds from the top of hades:

```sh
xmake f -y
xmake build shade
xmake test
```

The options are `--shade_vulkan` (on), `--shade_sdl`, `--shade_ffmpeg`, `--shade_lto` (on, release only) and
`--shade_dynarmic_test_emit_failure`, given to `xmake f`; `xmake f --menu` lists them. The guest probe in
`tools/guest` is built when `--shade_guest_rootfs` and `--shade_armv6_ld` name a root filesystem and an ARMv6
linker. Boost is the 1.81.0 release and needs no compiler flag with Apple clang 21.
Through Charon the build is the `shade` package: `xmake emulate` builds and runs it.

## Usage

```sh
build/macosx/arm64/release/shade profile --list
build/macosx/arm64/release/shade boot --rootfs "$ROOTFS" --device iPhone4,1 --display headless --gles-backend software
```

`shade --help` lists every verb: `profile`, `abi`, `inspect`, `catalog`,
`firmware prepare`, `disasm`, `boot`, `smoke` and `benchmark`. `--control-stdin`
reads commands such as `status`, `threads NAME` and `snapshot PATH` from
standard input while a guest runs, and `--gdb PORT` waits for a debugger; a guest
runs slower than a device, so `--time-scale 10` makes its clocks run at a tenth of
the host's, which the guest's own watchdogs need.

## Repository layout

| Path | Holds |
| --- | --- |
| `app/` | the `shade` program: verbs, live control, the desktop window |
| `src/` | the library: kernel, Mach, device state, graphics, media, network, runtime |
| `xmake.lua`, `*/xmake.lua` | the build: one target per library, as the module folders are laid out |
| `tools/` | guest-side probes and the boot logo script |

The JIT core (Dynarmic, with our patches) and Boost are hades' `dynarmic` and `boost` packages, in the
`third_party` package repository at the top of hades.

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
