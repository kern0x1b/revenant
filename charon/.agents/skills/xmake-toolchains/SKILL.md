---
name: xmake-toolchains
description: Use when switching compilers (gcc/clang/msvc/mingw), setting up cross-compilation for Android/iOS/embedded/wasm, or defining a custom toolchain.
---

# Xmake Toolchains

A toolchain bundles a compiler, linker, archiver, and related tools. You pick one per configure.

## Listing and switching

```bash
xmake show -l toolchains             # list available toolchains (~77 of them)
xmake f --toolchain=clang
xmake f --toolchain=gcc-11           # gcc-12 .. gcc-16 exist as well
xmake f --toolchain=mingw --mingw=/opt/llvm-mingw
xmake f --toolchain=msvc --vs=2022
```

Notable ones beyond the usual gcc/clang/msvc:

| Toolchain | For |
| --- | --- |
| `zigcc` | C/C++ through `zig cc`, a cross compiler with no sysroot — @see the `xmake-zigcc` skill |
| `zig` | Zig code |
| `muslcc` | musl-based cross toolchains, downloaded on demand |
| `emcc` / `wasi` | WebAssembly (emscripten / WASI) |
| `cosmocc` | build-once run-anywhere binaries |
| `dotnet` | C# and the .NET SDK |
| `cuda` | nvcc / nvc / nvc++ / nvfortran |
| `filc` | a memory-safe C/C++ implementation |
| `ascendc` | Huawei Ascend C (bisheng driver) |
| `armclang` / `iar` / `sdcc` | embedded compilers |

### Pointing at an sdk

```bash
xmake f --toolchain=clang --sdk=/opt/llvm-18            # the sdk root
xmake f --toolchain=gcc --bin=/opt/gcc/bin              # only the bin directory
xmake f --toolchain=clang --cc=clang-18 --cxx=clang++-18  # individual tools
```

`--sdk` is the standard knob: xmake derives `bin/`, `include/` and `lib/` from it.

In `xmake.lua`:

```lua
set_toolchains("clang")

target("app")
    set_toolchains("gcc-11")          -- override per target
```

## Cross-compilation

### Android

```bash
xmake f -p android --ndk=~/android-ndk-r26 -a arm64-v8a
xmake
```

Arch options: `armeabi-v7a`, `arm64-v8a`, `x86`, `x86_64`.

### iOS / macOS

```bash
xmake f -p iphoneos -a arm64
xmake f -p macosx -a arm64        # Apple Silicon
```

### Windows from Linux (mingw)

```bash
xmake f -p mingw --mingw=/usr/x86_64-w64-mingw32 -a x86_64
```

### WebAssembly

```bash
xmake f -p wasm --toolchain=emcc
```

### Generic cross-gcc

```bash
xmake f -p cross --sdk=/opt/my-sdk --cross=arm-linux-gnueabihf- -a arm
```

`--sdk` points to the SDK root; `--cross` is the tool prefix.

### musl cross toolchains

No sdk to download by hand — xmake fetches the toolchain itself:

```bash
xmake f -p linux -a arm64 --toolchain=muslcc
xmake f -p cross --toolchain=muslcc --cross=riscv64-linux-musl
```

### zig cc (no sysroot needed)

```bash
xmake f -p linux -a arm64 --toolchain=zigcc
xmake f -p freebsd --cross=x86_64-freebsd --toolchain=zigcc
```

zig cc carries its own libc for every target, so there is nothing to install. @see the
`xmake-zigcc` skill for the tuple mapping and its gotchas.

## Defining a custom toolchain

```lua
toolchain("my-cross")
    set_kind("standalone")
    set_sdkdir("/opt/my-sdk")
    set_toolset("cc",  "arm-linux-gnueabihf-gcc")
    set_toolset("cxx", "arm-linux-gnueabihf-g++")
    set_toolset("ld",  "arm-linux-gnueabihf-g++")
    set_toolset("ar",  "arm-linux-gnueabihf-ar")
    set_toolset("strip", "arm-linux-gnueabihf-strip")
toolchain_end()
```

```bash
xmake f --toolchain=my-cross -p cross -a arm
```

## Using a toolchain only for one target

```lua
target("firmware")
    set_toolchains("my-cross")
    set_plat("cross")
    set_arch("arm")
```

## Platform / mode probes

```lua
if is_plat("android", "iphoneos") then ... end
if is_arch("arm64", "arm64-v8a") then ... end
if is_host("windows") then ... end         -- the machine running xmake
```

## When to branch out

- Adding packages that also need cross-build → `xmake-packages`
- Target-level compile flags → `xmake-targets`
