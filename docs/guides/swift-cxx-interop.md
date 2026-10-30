# Swift C++ interoperability on iOS 6

Status: armv7 iOS 6.0 builds and links with `-cxx-interoperability-mode=default` against the bundled libc++ (LLVM 23.1.1
shared pair). The `std::string`, container and `std::function` probe is `toolchain_device/swift_cxx_test`. The
`thread_local` repro is `toolchain_device/swift_cxx_thread_local_test` and stays red until the compiler half of the fix is
built (see "Open items"). arm64 is not covered.

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
  The Swift rule passes `-Xcc -femulated-tls` to the importer through `swift.runtime_flags`.

## Supported surface

Measured in `toolchain/tests/swift_cxx/main.swift`, which compiles and links for armv7 iOS 6.0:

- `std::string` to `String` and back (`String(cxxText)`, `std.string("...")`).
- Functions returning `std::string`, `std::vector<std::string>` (iterated with `for ... in`), `std::optional<int>`
  (`hasValue`), `std::map` and `std::unordered_map` (`size()`, subscript).
- `std::shared_ptr<T>` (`pointee`) and C++ classes with member functions.
- `std::function<int(int)>` returned from C++ and called from Swift, and passed back into C++.
- `thread_local` in a C++ header, once the compiler half of the fix is built (not yet measured on a fixed compiler).

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

- The importer's clang ignores `-femulated-tls` for the TLS check. Measured: the LLVM 23.1.3 clang of revenant accepts the
  header with `-femulated-tls` for armv7 iOS 6.0 (`__has_feature(tls)` turns on), and the Swift 6.4 importer does not, with
  or without the flag. The clang-level bridge is `packages/l/llvm/patches/clang-emulated-tls-without-dyld.patch`, which the
  Swift 6.4 compiler does not carry. Its patch for the compiler is `packages/s/swift/patches/clang-emulated-tls-without-dyld.patch`,
  checked with `patch -p2 --dry-run` against the Swift 6.4.0 fork's four files, which applies cleanly. Building the Swift
  compiler is needed to verify it, and it is not built here.
- arm64: the SDK has no `CxxStdlib` overlay either, so the same two overlays are needed there. They are not built for arm64.
- `-clang-target armv7-apple-ios9.0` makes the importer accept `thread_local`, but it changes the availability the importer
  sees. It is not a fix.

## Tests

Both tests live in the device group with `swift_test` and share `toolchain/tests/addon/swift_cxx.lua`. Each compiles its
fixture (`toolchain/tests/swift_cxx/std` or `thread_local`) through `swift.runtime_flags`, links it against the installed
`swift-runtime` and `libcxx`, and checks the minimum version, the libraries it must load, and the dyld imports for iOS 6.0.
`swift_cxx_thread_local_test` also checks that the binary imports `___emutls_get_address` and not `__tlv_bootstrap`, that
the bundled libc++abi exports `___emutls_get_address`, and that the dyld check binds the import through that libc++abi,
which it passes to the check as a provided binary. No binary runs. They need both packages installed for iphoneos first: `./xmakew f -p iphoneos -a armv7`, then
`./xmakew require -P . -y revenant@swift-runtime` and `revenant@libcxx`.
