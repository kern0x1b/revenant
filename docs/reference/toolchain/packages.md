# Packages

The packages the toolchain defines, filed under `packages/<letter>/<name>/`, with the versions they pin, the configs that choose what a package builds, and the layout of the backports package. Licences and the upstream of each third-party piece are in [third-party](third-party.md). How to write one is in [write a package](../../guides/toolchain/packages.md).

A port requires a package by its name, and a package is built for the port's architecture and oldest release. The default `apple-ios` toolchain is pinned by `includes("@addon/revenant/apple-ios")`, which requires the SDK, `ld64` and `ldid` at the versions below and hands every other package the same toolchain.

## Build tools

These run on the build machine. Only the compiler runtimes reach the device.

| Package | Version | What it is |
| --- | --- | --- |
| `llvm` | clang 23.1.3 | the compilers and the runtime that every architecture is built with, without Xcode |
| `llvm-clang-c` | | the clang C API headers, which the declaration reader uses to read the SDK |
| `swift` | 6.4.0 | the Swift compiler, built from the sources of its own tag |
| `swift-bootstrap` | 6.4.0 | the swift.org release that builds the compiler, cut to the driver and frontend |
| `swift-syntax` | | the SwiftSyntax library for a port's macro plugin |
| `ld64` | 956.6 | the linker, from cctools-port with libtapi; reads `LLVM_PREFIX` |
| `ldid` | 2.1.5-procursus7+23.gaf86971 | the signer. Signing runs the binary of this package, never one found on `PATH` |
| `libplist` | | the plist library `ldid` and the emulator use |
| `iphoneos-sdk` | 16.4 (26.2 with `apple_sdk`) | the iOS SDK from theos/sdks, laid out as Xcode lays it out, with the `crt1` and `libgcc_s` files of iPhone OS 2 to iOS 6 and the library stubs of older releases |
| `gn` | | the GN meta-build tool, a host tool for a package whose upstream builds with GN |

## Runtimes

| Package | Version | What it is |
| --- | --- | --- |
| `libcxx` | 23.1.1 | libc++ and libc++abi as a shared pair an application bundles, checked against devices from iPhone OS 2.2.1 to iOS 6.1.3 |
| `apple-compat` | | the shims for what an old release lacks, linked hidden into each image that calls them |
| `swift-runtime` | 6.4.0 | the Swift standard library, runtime, concurrency and overlays, built for the port's architecture and oldest release |
| `swift-embedded` | | Embedded Swift's `Swift` module and the Unicode tables it calls |

`swift-runtime` takes the configs below. `shared` installs under absolute install names for a Debian package; `library_evolution` builds the resilient runtime and is a different package; `recipe` is the digest of the recipe and its changes. There is no `backports` config: the overlays see the SDK's headers lowered by the `apple-ios` toolchain (`modules/apple/lowered.lua`), so a program that uses a Backports API links the library by `add_deps` against the plain runtime.

## Frameworks

The `frameworks/Backports` targets carry the Objective-C APIs later releases added. See [Backports](#backports). The other packages are frameworks written in this repository, each named for the framework it provides:

| Package | What it is |
| --- | --- |
| `combine` | Combine on OpenCombine with the patches of this repository, one module named `Combine` |
| `activitykit`, `appintents`, `createml`, `matter`, `musickit`, `swift-crypto`, `swift-data`, `swift-system`, `tipkit`, `widgetkit` | the other frameworks of the repository |
| `realityfoundation`, `realitykit`, `spatial`, `cloudkit`, `weatherkit`, `network` | the overlays of Apple's frameworks, one dylib and one Swift module each, built against `swift-runtime`; the first two overlay SceneKit, whose part below iOS 8 is not yet backported, and `network` is the Network framework's overlay, whose part below iOS 12 is not yet backported; the open gaps are listed in [the Backports README](../../../frameworks/Backports/README.md) |

SwiftUI, the coding library `RevenantCoding`, the CloudKit wrapper `RevenantCKWebAuth` and the CallKit tweak `revenant-callkit-screen` are targets of their components, not packages: their sources are ours, and the components' `xmake.lua` files define them. See [the architecture](../../explanation/architecture.md).

## Libraries and emulator

| Package | What it is |
| --- | --- |
| `box2d`, `ggml`, `lz4`, `lzfse`, `micro-ecc`, `monocypher`, `opencv`, `openssl`, `picotls`, `quicly`, `suitesparse-ordering`, `xz`, `zlib` | libraries a port links, each built for the target and carried into its program |
| `emulator` | the emulator, which boots a firmware's userland on macOS arm64 |
| `emulator-guest` | the guest programs, `revenant-runner` and `revenant-sblaunch` |
| `firmware-tools` | `revenant-firmware`, which decrypts the FileVault root filesystems and the Apple Encrypted Archives of firmware |
| `swiftshader` | the CPU Vulkan driver OpenGL ES is drawn through in the emulator |

## Backports

The `frameworks/Backports` component builds one shared library per framework it backports. Each target is
named `<Name>Backports` and listed in `frameworks/Backports/xmake.lua`, with the frameworks it weakly imports
and the other Backports libraries it depends on. Each library installs under
`/usr/lib/revenant/org.revenant.backports/`.

Inside the project a target depends on a library with `add_deps`. The configure and build commands are in
[the component's README](../../../frameworks/Backports/README.md).

### Packaging

The one `.deb` of the repository that installs these libraries on a device is not written yet. A target that
links a Backports library is refused at packaging, and an application outside this repository has no package
to require. The design and what is measured are in [the backports loading note](../../explanation/backports-loading.md).

## Swift runtime notes

`swift-runtime` is built with the Objective-C floor of iOS 6.0. Its Swift classes mark themselves in the low bit of the `data` word, which iOS 6.0's Objective-C runtime masks off and iOS 5.1.1's does not, so older releases would follow a wild pointer. Embedded Swift registers nothing with Objective-C and is not bound by the floor.

Without `library_evolution` the runtime is compiled without resilient layouts. A resilient layout makes a client's class need `_objc_realizeClassFromSwift`, which only iOS 12 and later have, and the runtime stops with "class ... does not have a fragile layout" where it is missing. The `.swiftinterface` of these modules is not a stable contract, and `libswiftCore` carries a mark naming the build it is; a program links only against the build that compiled it.

With `library_evolution` the runtime is the one Apple builds, for programs an SDK's Swift compiled. Its arm64 install stops after Darwin: an arm64 consumer that expects `libswiftFoundation` from this package finds the SDK's instead. armv7 installs every overlay. Measured through the recipe, arm64 and armv7 install with `library_evolution`, and only armv7 without it.
