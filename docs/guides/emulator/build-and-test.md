# Build, run and test the emulator

## Requirements

- macOS on Apple silicon, xmake 3.1.2 or later, and a C++20 compiler (Apple clang).
- Every library comes as an xmake package, installed by the first configure. Dynarmic and Boost come from
  revenant's `third_party` repository; OpenSSL, libplist and SwiftShader come from Revenant's packages; libpng,
  libjpeg-turbo, the Vulkan headers, loader and memory allocator, and the glslang library (the shader compiler of
  `tools/glsl`), come from xmake's. SDL2 (a window) and FFmpeg (compressed audio) are optional.
- Nothing to install to draw. The build takes SwiftShader (Revenant's `swiftshader` package, a Vulkan driver on the
  CPU) and puts `libvk_swiftshader.dylib` beside the program, which loads it through the Vulkan loader by path, next
  to any driver the system has. Without a usable Vulkan driver a boot draws with the built-in reference renderer and
  logs one `[gles-renderer] Vulkan unavailable (...)` line saying why. The first install of the `swiftshader`
  package builds SwiftShader with CMake; an install already in xmake's package store is reused.
- A root filesystem of the firmware to run, for example one unpacked by `./xmakew firmware rootfs`.

## Build

The emulator is a member of revenant and builds from the top of revenant:

```sh
./xmakew f -y
./xmakew build emulator
./xmakew test
```

The options are `--emulator_vulkan` (on), `--emulator_sdl`, `--emulator_ffmpeg`, `--emulator_lto` (on, release only)
and `--emulator_dynarmic_test_emit_failure`, given to `./xmakew f`; `./xmakew f --menu` lists them. The guest probe
in `tools/guest` is built when `--emulator_guest_rootfs` and `--emulator_armv6_ld` name a root filesystem and an
ARMv6 linker. Boost is the 1.81.0 release and needs no compiler flag with Apple clang 21.

Through the toolchain the build is the `emulator` package: `./xmakew emulate` builds and runs it.

The program is `build/macosx/arm64/release/emulator`.

## Run

```sh
build/macosx/arm64/release/emulator profile --list
build/macosx/arm64/release/emulator boot --rootfs "$ROOTFS" --device iPhone4,1 --display headless --gles-backend software
```

`emulator --help` lists every verb: `profile`, `abi`, `inspect`, `catalog`, `firmware prepare`, `disasm`, `boot`,
`smoke` and `benchmark`.

`--control-stdin` reads commands such as `status`, `threads NAME` and `snapshot PATH` from standard input while a
guest runs; [the control surface](../../reference/emulator/control-surface.md) lists them. `--gdb PORT` waits for a
debugger. A guest runs slower than a device, so `--time-scale 10` makes its clocks run at a tenth of the host's,
which the guest's own watchdogs need.
