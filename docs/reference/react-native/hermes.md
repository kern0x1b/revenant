# Hermes for the React Native host

`packages/h/hermes` is the Hermes engine React Native 0.86.3 runs by default, as `libhermesvm.a` and `libjsi.a` for armv7 iOS 6.0.

## Source

| Item | Value |
| --- | --- |
| Upstream | `https://github.com/facebook/hermes.git` |
| Version | 250829098.0.17 |
| Commit | `3477757eb2475555cf8d8df24bfb1deb0613880d`, tag `hermes-v250829098.0.17` |
| Pinned by | `sdks/.hermesv1version` of react-native 0.86.3, the default when `RCT_HERMES_V1_ENABLED` is not `0` |
| Companion compiler | `hermes-compiler` 250829098.0.17 of npm, whose bytecode header is identical to the hermesc built from the commit |
| Older line, not packaged | `hermes-v0.17.0` (`829dcd74f5b774d19a86ab1dc47e3dee9e44d190`), the `sdks/.hermesversion` pin used only with `RCT_HERMES_V1_ENABLED=0` |

The package carries three patches, applied in order:

| Patch | sha256 | Change |
| --- | --- | --- |
| `patches/sysroot-from-toolchain.patch` | `05ad39c3cae3f864853c8da08c7a87bdf016f97012835c1e2cbdc852f3b5cc0b` | Upstream sets `CMAKE_OSX_SYSROOT` from `HERMES_APPLE_TARGET_PLATFORM` without a guard, and the toolchain's SDK is replaced by an empty value when that variable is unset. The patch sets it only when the variable is given. |
| `patches/hermesvalue-align8.patch` | `a51b4cea850c7a6eeba742aca1466dbf39ea1ba61bdfaaeb45434022ac268770` | `HermesValueBase` gets 8-byte alignment, so the 64-bit `HermesValue` is aligned as it is in size. Needed by `HEAP_HV_64` on armv7, see [the engine decisions](../../explanation/react-native/hermes-engine.md) |
| `patches/truncate-int32-vfp.patch` | `603dcd9761d768ea98f10e28b72d6cb39cec567b500aaaf377255239400902ec` | On armv7, the helper `_sh_ljs_tryfast_truncate_to_int32` converts a number below 2^31 in magnitude with `vcvt` in VFP registers, without moving it through core registers. The helper is used by `ToInt32`, the bitwise and shift operators and `BitNot`; only `|0` was measured. See [the engine decisions](../../explanation/react-native/hermes-engine.md#the-interpreter-on-armv7) |

## Build products

Built for `iphoneos` `armv7`, deployment target 6.0, the iPhoneOS 26.2 SDK, and libc++ from `packages/l/libcxx`.

| Path in the package | Contents |
| --- | --- |
| `lib/libhermesvm.a` | the engine, one armv7 slice, 7.2 MiB (7 568 744 bytes) |
| `lib/libjsi.a` | JSI compiled from react-native's own `ReactCommon/jsi`, 119 KiB |
| `include/hermes/` | `API/hermes` headers, `Public`, `cdp`, `inspector` |

The package links `Foundation`, which backs Intl through `PlatformIntlApple.mm`. Intl needs no ICU on Apple.

## Configuration

The cross build runs through `@addon.revenant.apple.cmake`. Its flags, from `packages/h/hermes/xmake.lua`:

| Flag | Value | Reason |
| --- | --- | --- |
| `JSI_DIR` | react-native installdir `src/react-native/ReactCommon/jsi` | the JSI of react-native 0.86.3; Hermes's bundled `API/jsi` differs in `jsi.cpp`, `JSIDynamic.cpp` and `decorator.h`, so an engine built from it does not match the host |
| `IMPORT_HOST_COMPILERS` | `ImportHostCompilers.cmake` of a host build of `hermesc` | `lib/InternalJavaScript` compiles the built-in JavaScript with `imported-hermesc` when cross compiling |
| `HERMES_IS_MOBILE_BUILD` | `ON` | the mobile defaults; set explicitly because the platform variable that sets it also sets the SDK |
| `HERMES_ENABLE_INTL` | `ON` | Intl through Foundation |
| `HERMES_ENABLE_TEST_SUITE` | `OFF` | no test suite is built for the device |
| `HERMES_ENABLE_DEBUGGER` | `OFF` | release configuration |
| `HERMES_BUILD_SHARED_JSI` | `OFF` | `jsi` is a static archive |
| `HERMES_BUILD_APPLE_FRAMEWORK` | `OFF` | a static archive, not `hermesvm.framework` |
| `HERMES_ALLOW_BOOST_CONTEXT` | `0` | Boost.Context has no Mach-O ARM32 assembly: `ontop_apple.S` stops with `Invalid Apple arch`. `StackExecutor` takes its thread fallback, the one Catalyst builds use |
| `HERMESVM_HEAP_HV_MODE` | `HEAP_HV_64` | the 64-bit NaN-boxed `HermesValue`, the upstream default. Doubles stay unboxed, so arithmetic does not allocate. It runs on armv7 with `hermesvalue-align8.patch`; without it the runtime faults during start, see [the engine decisions](../../explanation/react-native/hermes-engine.md) |

The host `hermesc` is built with the host compiler from the same source tree, with `JSI_DIR` set and tests off.

The engine is built with `-O3 -DNDEBUG` from the release configuration, computed-goto dispatch and inline assembly for the register pinning on ARM. The recipe passes no `-mfpu` or `-mfloat-abi`, so the armv7 target's defaults apply. The build has no link-time optimisation; LTO has not been measured. The armv7 target is Thumb-2 by default; the ARM-mode build (`-marm`) was tried and is not adopted, see below.

## Measured on an iPhone 4S (iPhone4,1), iOS 6.1.3

The probe `toolchain/tests/packages/hermes/probe.cpp` runs `toolchain/tests/packages/hermes/bench.js`, compiled with `hermesc -O`, and prints wall-clock times and resident sizes. The micro-benchmark loops (`s = i | 0` and the others) and the `toint-check.js` correctness script are scratch files and are not committed.

### Same window, 2 November 2026: the ToInt32 change

The phone's speed changes between claim windows, so figures from different windows (the earlier table below) are not comparable with these. Within one window the variants ran in turn; the table gives the range of the runs where there were several.

| Measurement | `HEAP_HV_64` | with the ToInt32 patch |
| --- | --- | --- |
| `s = i \| 0`, the micro-benchmark loop | 478 ms | 406 ms (−15%) |
| `loop20M`: `s = (s + i * 3) \| 0`, 20 million iterations | 3920 to 3974 ms | 3694 to 3718 ms (about −6%) |
| `makeHermesRuntime` (one correctness run each) | 0.008 s | 0.009 s |

The other micro-benchmark loops (empty loop, `s = s + i`, `s = i * 3`, `s = i & 1023`, `s = s + 1.5` and the other `bench.js` items) were within run-to-run noise in this window. Their individual figures were not kept.

The ARM-mode build gave no measurable gain on this phone and is not adopted.

Correctness: the `toint-check.js` output (boundary values around ±2^31 and ±2^32, NaN, ±Infinity, −0, strings, `undefined`, `null`, fractions) through the integer operators is identical to Node's output for the base build, the ToInt32 build and the ARM build.

### Earlier window: `HEAP_HV_PREFER32` against `HEAP_HV_64`

Measured before the ToInt32 change, on an earlier build, one run per column. The `HEAP_HV_64` numbers are not comparable with the same-window table above.

| Measurement | `HEAP_HV_PREFER32` | `HEAP_HV_64` |
| --- | --- | --- |
| `makeHermesRuntime` | 0.011 to 0.020 s | 0.010 s |
| bytecode file read | 0.000 to 0.002 s (1856 bytes) | 0.000 s (1904 bytes) |
| resident size: process start, after runtime, after loading the bytecode | 1.0 MB, 1.9 MB | 1.0 MB, 1.9 MB |
| resident size after the benchmark | 62.0 MB | 85.2 MB |

| Item | `HEAP_HV_PREFER32` | `HEAP_HV_64` |
| --- | --- | --- |
| `loop20M`: `s = (s + i * 3) \| 0`, 20 million iterations | 11005 ms | 6674 ms |
| `alloc500k`: 500 000 objects with an array each | 5120 ms | 5092 ms |
| `str200k`: 200 000 string concatenations | 832 ms | 1365 ms |
| `sortmap200k`: sort and map of 200 000 numbers | 9731 ms | 8729 ms |
| `closure2M`: 2 000 000 closures created and called | 802 ms | 561 ms |
| `json`: 20 000 keys through JSON | 999 ms | 757 ms |
| `loop20M-again` | 10758 ms | 6788 ms |

The JavaScript-core figures the owner's benchmark gives for the same loop are about 0.4 s for `loop20M`, about 700 ns per closure call and about 1.5 µs per object with an array. Those are reported figures, not re-measured here.
