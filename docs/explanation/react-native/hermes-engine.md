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

`patches/hermesvalue-align8.patch` gives `HermesValueBase` 8-byte alignment, so the alignment is the size again. With the patch the runtime starts and the benchmark runs to the end on the phone. The probe's crash output and the overlap report both came from a debug build of the package with asserts on. Under `-m debug` the package's CMake build still used `CMAKE_BUILD_TYPE=Release`, which compiles the asserts out, so the Debug build was made by hand in the package's build directory.

With `HEAP_HV_PREFER32` the same overlap cannot happen, because its slot is 4 bytes and alignment and size agree.

## The benchmark

[The reference](../../reference/react-native/hermes.md) has the figures. Against `HEAP_HV_PREFER32`, `HEAP_HV_64` runs `loop20M` in 6.7 seconds instead of 11.0, `closure2M` in 0.56 instead of 0.80 and `json` in 0.76 instead of 1.0, and the boxing of doubles is gone. `alloc500k` is unchanged. `str200k` is slower, 1.37 seconds instead of 0.83. The likely reason is that every number is now a double, so `s += i` converts each integer through the double path where `PREFER32` converts an int32 directly; this is not measured.

## What is open

- `loop20M` is still about 6.7 seconds against about 0.4 seconds in JavaScriptCore, so the boxing was not the whole cost. The interpreter path of that loop has not been profiled on the phone. A candidate is the conversion of the double result by `| 0`.
- `str200k` regressed with `HEAP_HV_64`. The number-to-string path for doubles has not been measured separately.
- The integration of the engine as a selectable executor of the React Native host, and the export of bytecode in place of the JavaScriptCore bundle. The JavaScriptCore bundle export is on `work/rn-jsc-bundle`.
