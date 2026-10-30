# Swift C++ interoperability on iOS 6

Status: armv7 iOS 6.0 builds and links with `-cxx-interoperability-mode=default` against the bundled libc++ (LLVM 23.1.1
shared pair), once the `swift-runtime` carries the `CxxStdlib` overlays. The `std::string`, container and `std::function`
probe is `toolchain_device/swift_cxx_test`. On `main`'s runtime (`99d684eb`) it stops at the `std.string` initializer, and no
installed runtime carries the overlays yet. The `thread_local` probe is `toolchain_device/swift_cxx_thread_local_test`:
on the patched compiler it compiles with the consumer flags and imports `___emutls_get_address` and not `__tlv_bootstrap`
(host-checked; the device run has not happened). arm64 is not covered.

## What makes it work

- `swift-runtime` builds the `Cxx` and `CxxStdlib` overlays for armv7 and offers them as `libswiftCxx.dylib` and
  `libswiftCxxStdlib.dylib` beside the other overlays in `lib/swift/iphoneos`. The SDK has neither overlay for iOS 6, so
  `import CxxStdlib` failed before this. The flags are the ones the Swift stdlib build gives them (`BuiltinModule`,
  `Lifetimes`, `AllowUnsafeAttribute`, `-strict-memory-safety`, `-empty-abi-descriptor`).
- The `std::string` initializers of the `CxxStdlib` overlay spell the three-parameter `basic_string` constructor on every
  platform. libc++ 23 declares only that form, with a defaulted allocator Swift does not import, so the two-parameter form
  the overlay used on Apple has no match. The patch is `packages/s/swift-runtime/patches/the-cxx-string-overlay-passes-the-allocator-on-every-platform.patch`.
- Overlay and consumer must see one libc++ header set. The runtime compiles the overlays against the bundled
  `include/c++/v1` with `-Xcc -nostdinc++ -Xcc -isystem`, and the Swift rule passes the same flags for every target that
  carries the runtime. Measured: with the SDK's headers on one side only, a `CxxStdlib` build fails with
  `redefinition of module 'std'`, and a consumer built against the bundled headers while the overlay used the SDK's
  crashed the frontend (`ModularizationError` in `SILDeserializer`).
- Emulated TLS: iOS 6 armv7 has no TLS, so the toolchain sets `emulated_tls` for it, as it does for the C and CMake builds.
  The value comes from `apple.architectures`' `emulated_tls`, the function the apple-ios toolchain's `on_load` calls. The
  Swift rule passes `-Xcc -femulated-tls` through `swift.runtime_flags`, but that flag works only with the compiler patch
  in `packages/s/swift/patches`. The table below shows both compilers.
- C++ interop: `swift.runtime_flags` adds `-cxx-interoperability-mode=default` when `cxx_headers` is set. The Swift rule
  always sets `cxx_headers` for a target that carries the runtime, so every such target compiles with C++ interoperability.
  Measured on both compilers: a plain Swift file and one with `import Foundation` compile the same with and without the flag.
  The overlay build sets the flag itself (`packages/s/swift-runtime/xmake.lua`). Without it a module that says
  `requires cplusplus` is refused with `requires feature 'cplusplus'`.

## Supported surface

Measured in `toolchain/tests/swift_cxx/main.swift`, which compiles and links for armv7 iOS 6.0:

- `std::string` to `String` and back (`String(cxxText)`, `std.string("...")`).
- Functions returning `std::string`, `std::vector<std::string>` (iterated with `for ... in`), `std::optional<int>`
  (`hasValue`), `std::map` and `std::unordered_map` (`size()`, subscript).
- `std::shared_ptr<T>` (`pointee`) and C++ classes with member functions.
- `std::function<int(int)>` returned from C++ and called from Swift, and passed back into C++.
- `thread_local` static members of a class template in a C++ header (`toolchain/tests/swift_cxx/thread_local`): compiled
  with the consumer flags on the patched compiler; the device run is pending.

## Not supported, measured

- A Swift closure passed where a C++ `std::function` is expected: `closure passed to parameter of type 'std.function<...>'
  that does not accept a closure`, and an explicit `std.function<...>(closure)` gives `couldn't instantiate a C++ class template`.
- `std::unique_ptr`: `pointee` and `get()` are not imported (the SDK and the bundled headers agree).
- `std::vector` has no `map`, `count`, `isEmpty`, `first` or `lazy`; use `for ... in`, `size()` and subscripts.
- `std::map` subscripts return an optional: unwrap them.

## Not supported, reasoned

- C++ exceptions cannot be caught in Swift. Swift does not translate a thrown C++ exception into a Swift error, so a C++
  function that throws must not be called from Swift. This was not measured with a throwing function here.

## Types without a public destructor

The Swift importer does not import a C++ record that has no public destructor. The note reads "record 'X' is not automatically
available: it must have a copy/move constructor and a destructor; does this type have reference semantics?", and a Swift
reference to it fails with "'X' is not a member type of enum '__ObjC.facebook.jsi'". The jsi headers declare their interface
bases with protected destructors on purpose ("Interfaces are not destructible"): `ICast`, `IRuntime` and `ISerialization`
(the last one is also under `JSI_UNSTABLE`). So `facebook.jsi.IRuntime` cannot be named from Swift. Measured: with the three
destructors public and `JSI_UNSTABLE` defined, the jsi probe compiles with no errors; the unchanged header fails with the same
error under Apple's `swiftc` (via `xcrun`, iPhoneOS SDK, arm64), so this is the importer's rule, not the fork's. Swift code
names `facebook.jsi.Runtime` instead: it is concrete, has a public destructor, derives from `IRuntime`, and imports. The jsi
header and the fork are not patched for this. Changing the header would be a react-native patch owned by the consuming app,
and is the fallback only if `Runtime` cannot serve.

## Why the fork carries the compiler patch

Each row is a host compile (`-c`, no link) for armv7 iOS 6.0, with the flags `apple.swift.runtime_flags` gives when
`cxx_headers` is set, `has_main` true and the module `probe`. Each compile gets a fresh `-module-cache-path`. This matters:
with a shared clang module cache, the pre-patch compiler reused a module the patched compiler had built and passed the
header it refuses, so earlier runs without a fresh cache were wrong. Compilers: the pre-patch 6.4.0 package (recipe
`aa42d3e4`), and the patched one (recipe `e75ce6bf`, which applies `packages/s/swift/patches/clang-emulated-tls-without-dyld.patch`).

| Compiler | `-femulated-tls` | Class template `Tls<int>::value` (`toolchain/tests/swift_cxx/thread_local`) | Plain struct `S::v` (paseo repro) |
| --- | --- | --- | --- |
| Pre-patch | without | refused: `thread-local storage is not supported for the current target` | refused, same error |
| Pre-patch | with | refused, same error | refused, same error |
| Patched | without | refused, same error | refused, same error |
| Patched | with | compiles; `nm -u` imports `___emutls_get_address`, not `__tlv_bootstrap` | compiles; same `nm -u` result |

Only the patched compiler with the flag compiles. The flag alone does not change the pre-patch result. The patch makes the
compiler read `-femulated-tls` into the target options (`CompilerInvocation.cpp`), which the unpatched importer does not
do. The patch changes four clang files in the fork: `TargetOptions.h`, `OSTargets.h`, `ItaniumCXXABI.cpp` and
`CompilerInvocation.cpp`. It applies with `git apply -p2` in llvm-project after the other compiler patches.

## Open items

- The compiler patch is built by CI (package=swift, run 41072834350), and the table above is the host evidence for it. The
  `thread_local` device test has not run yet. The runtime build that carries the overlays for the `std` probe (run
  41103082464) was cancelled, so no installed runtime has them.
- arm64: the SDK has no `CxxStdlib` overlay either, so the same two overlays are needed there. They are not built for arm64.
- `-clang-target armv7-apple-ios9.0` makes the importer accept `thread_local`, but it changes the availability the importer
  sees. It is not a fix.

## Tests

Both tests live in the device group with `swift_test` and share `toolchain/tests/addon/swift_cxx.lua`. Each compiles its
fixture (`toolchain/tests/swift_cxx/std` or `thread_local`) through `swift.runtime_flags`, which adds the interop mode for
`cxx_headers`, links it against the installed `swift-runtime` and `libcxx`, and checks the minimum version, the libraries
it must load, and the dyld imports for iOS 6.0. Its `emulated_tls` is `apple.architectures`' `emulated_tls` for the
deployment. The suite runs under the host configuration, where the apple-ios toolchain instance is not loaded, so the
function is shared rather than read from the live config. The `thread_local` fixture is a class template (`Tls<int>`).
`swift_flags_test` (`toolchain_light`, host) checks the interop flag with and without `cxx_headers`, the `-femulated-tls`
pass-through and the emulated TLS value per architecture.
`swift_cxx_thread_local_test` also checks that the binary imports `___emutls_get_address` and not `__tlv_bootstrap`, that
the bundled libc++abi exports `___emutls_get_address`, and that the dyld check binds the import through that libc++abi,
which it passes to the check as a provided binary. No binary runs. They need both packages installed for iphoneos first: `./xmakew f -p iphoneos -a armv7`, then
`./xmakew require -P . -y revenant@swift-runtime` and `revenant@libcxx`.
