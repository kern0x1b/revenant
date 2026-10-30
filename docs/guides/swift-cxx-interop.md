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
  The Swift rule passes `-Xcc -femulated-tls` to the importer through `swift.runtime_flags`, and that flag alone does not
  work: the importer's clang reads it only with the compiler patch in `packages/s/swift/patches`. Measured with the consumer
  flags on the 6.4.0 compiler, a class-template `thread_local` header is refused with and without `-femulated-tls` on the
  pre-patch compiler; with the patch and the flag it compiles and imports `___emutls_get_address` only.
- C++ interop is not in `swift.runtime_flags`. A consumer adds `-cxx-interoperability-mode=default` itself, as the overlay
  build does (`packages/s/swift-runtime/xmake.lua`) and the tests do. Without it a module that says `requires cplusplus` is
  refused with `requires feature 'cplusplus'`.

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

## Open items

- The importer's clang ignores `-femulated-tls` unless the compiler carries
  `packages/s/swift/patches/clang-emulated-tls-without-dyld.patch`, the same change as the LLVM one in
  `packages/l/llvm/patches`. The patch is applied with `git apply -p2` in llvm-project after the other compiler patches, and
  it applies cleanly to the 6.4.0 fork's four files. CI built that compiler (package=swift, run 41072834350). The
  `thread_local` device test has not run yet. The runtime build that carries the overlays for the `std` probe (run
  41103082464) was cancelled, so no installed runtime has them.
- arm64: the SDK has no `CxxStdlib` overlay either, so the same two overlays are needed there. They are not built for arm64.
- `-clang-target armv7-apple-ios9.0` makes the importer accept `thread_local`, but it changes the availability the importer
  sees. It is not a fix.

## Tests

Both tests live in the device group with `swift_test` and share `toolchain/tests/addon/swift_cxx.lua`. Each compiles its
fixture (`toolchain/tests/swift_cxx/std` or `thread_local`) through `swift.runtime_flags` with
`-cxx-interoperability-mode=default`, links it against the installed `swift-runtime` and `libcxx`, and checks the minimum
version, the libraries it must load, and the dyld imports for iOS 6.0. `emulated_tls` follows the toolchain's rule (below
9.0 on armv7, `toolchains/apple-ios/xmake.lua`), because the test runner does not pass the live toolchain config to the
addon. The `thread_local` fixture is a class template (`Tls<int>`).
`swift_cxx_thread_local_test` also checks that the binary imports `___emutls_get_address` and not `__tlv_bootstrap`, that
the bundled libc++abi exports `___emutls_get_address`, and that the dyld check binds the import through that libc++abi,
which it passes to the check as a provided binary. No binary runs. They need both packages installed for iphoneos first: `./xmakew f -p iphoneos -a armv7`, then
`./xmakew require -P . -y revenant@swift-runtime` and `revenant@libcxx`.
