# Why Hermes is built this way on armv7 iOS 6

The React Native host runs the application's JavaScript on JavaScriptCore today. Hermes is the engine React Native itself runs by default, so the owner's goal is to run it on the iPhone 4S as well. Its bytecode is compiled on the Mac by `hermesc` and mapped on the phone, which avoids the source parse and the bytecode cache that JavaScriptCore needs.

## The version

React Native 0.86.3 has two Hermes lines. Its `sdks/.hermesv1version` (250829098.0.17) is the default, and `sdks/.hermesversion` (0.17.0) applies only when `RCT_HERMES_V1_ENABLED=0`. The package builds the V1 line, because the `hermes-compiler` that React Native depends on is that same version. The bytecode a compiler writes must be read by the engine of the same version, and the bytecode headers of the two compilers match byte for byte.

## JSI from React Native, not from Hermes

Hermes carries its own copy of JSI, and that copy differs from the one of React Native 0.86.3 in `jsi.cpp`, `JSIDynamic.cpp` and `decorator.h`. The host calls the engine through React Native's JSI, so the engine is compiled against React Native's copy. This is also how React Native builds Hermes for iOS.

## No Boost.Context on Apple ARM32

Hermes runs some code on a separate stack through Boost.Context. Boost has assembly for Mach-O on arm64 but not for ARM32, so the build with the flag left on stops at `ontop_apple.S`. Writing that assembly is a port of its own. The package uses the fallback Hermes already has for Catalyst and sanitizers, which runs the same work on a thread. The cost of that fallback is not measured yet.

## The heap encoding

`HERMESVM_HEAP_HV_MODE` picks how a value is stored in the heap. `HEAP_HV_64`, the upstream default, is a 64-bit NaN-boxed encoding: doubles stay unboxed and a pointer sits in the low 32 bits on armv7. `HEAP_HV_PREFER32` stores 32-bit values on 32-bit systems and boxes every double outside the int32 range, which allocates and collects under the Hades heap. The package uses `HEAP_HV_64`.

## Why `HEAP_HV_64` faulted on armv7, and the fix

With `HEAP_HV_64` the armv7 runtime faulted while it started: a read of address 0 in `Interpreter::handleCallSlowPath`, during `runInternalJavaScript`, so an object reference reached the interpreter with a null payload.

The cause is alignment, not the encoding. The iOS armv7 clang target has no `i64` entry in its data layout, so a 64-bit integer gets an ABI alignment of 4 while its size is 8. `HermesValueBase` took that alignment. Hermes's `JSObject::numOverlapSlots` and `JSObject::directPropsOffset` count the direct property slots from `alignof(GCSmallHermesValue)` and divide by `sizeof`, and they assume the two are equal, which holds on every target that the layout was written for. On armv7 a field of a derived class, `ArrayImpl::indexedStorage_` at offset 36, falls inside the direct slot that occupies 36 to 43. The metadata builder reports the overlap (`fields should not overlap`, which a release build compiles out). When the array's pointer is cleared, the low word of that slot is cleared too and its object tag stays, which is a value with a null payload.

`patches/hermesvalue-align8.patch` gives `HermesValueBase` 8-byte alignment, so the alignment is the size again. With the patch the runtime starts and the benchmark runs to the end on the phone. The probe's crash output and the overlap report both came from a debug build of the package with asserts on. Under `-m debug` the package's CMake build still used `CMAKE_BUILD_TYPE=Release`, which compiles the asserts out, so the Debug build was made by hand in the package's build directory. The fix for that is on `work/pkg-is-debug`.

With `HEAP_HV_PREFER32` the same overlap cannot happen, because its slot is 4 bytes and alignment and size agree.

## The interpreter on armv7

The benchmark loops are interpreter-bound: a `for` loop of `s = (s + i * 3) | 0` is a handful of bytecode instructions per iteration, and the time goes to dispatching them. Three things were measured on the phone.

A native sampler in the probe (`argv[2] == "profile"`) suspends the engine's thread every millisecond, reads its program counter and symbolizes it with `lldb`'s image lookup. The release objects have no line table, so the same source was compiled with `-g` for line numbers; the code generation is the same. The profile of the ToInt32 build of `loop20M` has 3 328 samples, 55 of the 60 hot program counters map to a symbol, and it shows:

- Dispatch dominates. The hottest program counters are handler entries, where the computed-goto indirect jumps land. The single hottest one, the entry of the `Mov` handler, takes 15.7% of the samples (523 of 3 328), the next 10.1%, then 8.1%, 7.9% and 7.5%.
- The double handlers (`AddN`, `Mul`) and the compare-and-jump (`JCond Less`) spend much of their samples on VFP load-after-store stalls: a double is written to the register file and read back into a VFP register straight after.
- The `ToInt32` handler takes 8.3% of the samples, and about 19% of the samples fall in interpreter code the line table does not map.
- There are no GC or runtime samples. The GC write barrier is not a hot spot in these loops.

The `ToInt32` finding is the one that was acted on. On armv7 the generic path converts a double to int32 through core registers: the range check goes through `vcmp` and `vmrs`, and the value is moved from VFP to core registers and back. The patch `patches/truncate-int32-vfp.patch` checks the exponent in the high word, and for a magnitude below 2^31 truncates with `vcvt.s32.f64` and `vcvt.f64.s32` in VFP registers. Anything else takes the generic path as before. The helper is shared by `ToInt32`, the bitwise and shift operators and `BitNot`, so they get the same path; only `|0` was measured. In the same window on the phone, `s = i | 0` went from 478 ms to 406 ms (−15%), and `loop20M` from 3920 to 3974 ms to 3694 to 3718 ms (about −6%). The other items were within run-to-run noise. The output of the integer operators over boundary values is identical to Node's.

The armv7 target can build in ARM mode (`-marm`) instead of Thumb-2. In the same window it gave no measurable gain on the Cortex-A9, so the default stays Thumb-2.

Two things in the generated bytecode cost dispatches but are not runtime faults, and they are left alone here: `hermesc -O` leaves a `Mov` after `ToInt32` where the copy could be coalesced, and it sinks `LoadConstZero` into the loop body, so the zero is loaded again on each iteration.

Not measured: link-time optimisation, the number-to-string path behind `str200k`, and the `HEAP_HV_PREFER32` comparison in the same window as the figures above.

## The benchmark

[The reference](../../reference/react-native/hermes.md) has the figures. In an earlier window, `HEAP_HV_64` ran `loop20M` in 6.7 seconds against 11.0 for `HEAP_HV_PREFER32`, `closure2M` in 0.56 against 0.80 and `json` in 0.76 against 1.0, and the boxing of doubles is gone. `alloc500k` was unchanged. `str200k` was slower, 1.37 seconds against 0.83. The likely reason is that every number is now a double, so `s += i` converts each integer through the double path where `PREFER32` converts an int32 directly; this is not measured. The phone's speed varies between windows, so these earlier figures are not comparable with the same-window ones above.

## What is open

- `loop20M` is about 3.7 seconds on the ToInt32 build, against about 0.4 seconds in JavaScriptCore (a reported figure, not re-measured). The profile above puts the rest in interpreter dispatch and VFP stalls on double values.
- `str200k` was slower with `HEAP_HV_64` in the earlier window. In the same window the base and ToInt32 builds did not differ beyond noise, so that comparison shows no regression within `HEAP_HV_64`; the `HEAP_HV_PREFER32` comparison has not been repeated in the same window, and the double-to-string path has not been profiled.
- Link-time optimisation has not been measured.
- The integration of the engine as a selectable executor of the React Native host, and the export of bytecode in place of the JavaScriptCore bundle. The JavaScriptCore bundle export is on `work/rn-jsc-bundle`.
