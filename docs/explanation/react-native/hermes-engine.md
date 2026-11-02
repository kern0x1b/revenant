# Why Hermes is built this way on armv7 iOS 6

The React Native host runs the application's JavaScript on JavaScriptCore today. Hermes is the engine React Native itself runs by default, so the owner's goal is to run it on the iPhone 4S as well. Its bytecode is compiled on the Mac by `hermesc` and mapped on the phone, which avoids the source parse and the bytecode cache that JavaScriptCore needs.

## The version

React Native 0.86.3 has two Hermes lines. Its `sdks/.hermesv1version` (250829098.0.17) is the default, and `sdks/.hermesversion` (0.17.0) applies only when `RCT_HERMES_V1_ENABLED=0`. The package builds the V1 line, because the `hermes-compiler` that React Native depends on is that same version. The bytecode a compiler writes must be read by the engine of the same version, and the bytecode headers of the two compilers match byte for byte.

## JSI from React Native, not from Hermes

Hermes carries its own copy of JSI, and that copy differs from the one of React Native 0.86.3 in `jsi.cpp`, `JSIDynamic.cpp` and `decorator.h`. The host calls the engine through React Native's JSI, so the engine is compiled against React Native's copy. This is also how React Native builds Hermes for iOS.

## No Boost.Context on Apple ARM32

Hermes runs some code on a separate stack through Boost.Context. Boost has assembly for Mach-O on arm64 but not for ARM32, so the build with the flag left on stops at `ontop_apple.S`. Writing that assembly is a port of its own. The package uses the fallback Hermes already has for Catalyst and sanitizers, which runs the same work on a thread. The cost of that fallback is not measured yet.

## The 32-bit heap encoding

`HERMESVM_HEAP_HV_MODE` picks how a value is stored in the heap. The default, `HEAP_HV_64`, is a 64-bit encoding. The option text says `HEAP_HV_PREFER32` is the encoding for 32-bit systems, which uses 32-bit values and boxes doubles.

With `HEAP_HV_64` the armv7 runtime faults while it starts. The fault is a read of address 0 in `Interpreter::handleCallSlowPath`, while the runtime runs its built-in bytecode in `runInternalJavaScript`, so an object reference reaches the interpreter as null. The `HermesValue` encoding itself keeps pointers in its data bits through `uintptr_t`, which looks portable, so the cause is elsewhere in the runtime and has not been found.

With `HEAP_HV_PREFER32` the runtime starts and runs, but every double outside the 32-bit integer range is a heap object. That is the cost behind the benchmark in [the reference](../../reference/react-native/hermes.md): the loop that only does integer work takes about 11 seconds, against about 0.4 seconds in JavaScriptCore, and the reason is the boxing of intermediate doubles, which allocates and collects under the Hades heap.

## What is open

- The null object reference under `HEAP_HV_64` on armv7. Tracing it means a debug build of the runtime with the probe's crash frames, and checking how the built-in bytecode's first calls create their objects on a 32-bit target.
- Whether the boxed-double path can be made cheaper within the 32-bit encoding, as the owner asked for compiler and runtime work to beat Apple's code where it was never tuned for the A5.
- The integration of the engine as a selectable executor of the React Native host, and the export of bytecode in place of the JavaScriptCore bundle. The JavaScriptCore bundle export is on `work/rn-jsc-bundle`.
