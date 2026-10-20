# Packages

The packages the toolchain defines, filed under `toolchain/packages/<group>/<name>/`, with the versions they pin, the configs that choose what a package builds, and the layout of the backports package. Licences and the upstream of each third-party piece are in [third-party](third-party.md). How to write one is in [write a package](../../guides/toolchain/packages.md).

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
| `revenant-coding` | | the secure coding and copying the data classes of the backports share, as a static library with hidden symbols |

`swift-runtime` takes the configs below. `shared` installs under absolute install names for a Debian package; `backports` and `backports_uikit` make the overlays see what `revenant@apple-backports` implements; `library_evolution` builds the resilient runtime and is a different package; `recipe` is the digest of the recipe and its changes.

## Frameworks

`apple-backports` is the package that carries the Objective-C APIs later releases added. See [its layout](#apple-backports). The other packages are frameworks written in this repository, each named for the framework it provides:

| Package | What it is |
| --- | --- |
| `combine` | Combine on OpenCombine with the patches of this repository, one module named `Combine` |
| `swiftui-uikit` | SwiftUI on the UIKit of iOS 6, one module named `SwiftUI`, built against `combine` and the runtime |
| `swiftui` | the SwiftUI module and static library a port imports, with Apple's module name |
| `activitykit`, `appintents`, `appintents-macros`, `createml`, `matter`, `musickit`, `swift-crypto`, `swift-data`, `swift-system`, `tipkit`, `widgetkit` | the other frameworks of the repository |

## Libraries and emulator

| Package | What it is |
| --- | --- |
| `box2d`, `ggml`, `lz4`, `lzfse`, `micro-ecc`, `monocypher`, `opencv`, `openssl`, `picotls`, `quicly`, `suitesparse-ordering`, `xz`, `zlib` | libraries a port links, each built for the target and carried into its program |
| `emulator` | the emulator, which boots a firmware's userland on macOS arm64 |
| `emulator-guest` | the guest programs, `revenant-runner` and `revenant-sblaunch` |
| `firmware-tools` | `revenant-firmware`, which decrypts the FileVault root filesystems and the Apple Encrypted Archives of firmware |
| `swiftshader` | the CPU Vulkan driver OpenGL ES is drawn through in the emulator |
| `apple-callkit-screen` (`tweaks/`) | the MobileSubstrate tweak that raises the system call screen for the CallKit backport |

## apple-backports

The package at `toolchain/packages/frameworks/apple-backports/`, with its own [README](../../../toolchain/packages/frameworks/apple-backports/README.md), which lists what it carries range by range.

### Libraries and configs

Each library is off unless its config is set. The configs are: `sources`, and one per library, `uikit`, `homekit`, `corelocation`, `avfoundation`, `coredata`, `security`, `commoncrypto`, `corebluetooth`, `compression`, `spritekit`, `spatial`, `sqlite3`, `avfaudio`, `webkit`, `graphics`, `localauthentication`, `opengles`, `videotoolbox`, `mapkit`, `passkit`, `coretext`, `coremedia`, `corefoundation`, `storekit`, `coregraphics`, `addressbookui`, `corevideo`, `carplay`, `safariservices`, `authenticationservices`, `backgroundtasks`, `photos`, `gamecontroller`, `coreml`, `vision`, `metal`, `metalkit`, `modelio`, `coretelephony`, `coremidi`, `contacts`, `accelerate`, `fileprovider`, `callkit`, `corespotlight`, `pushkit`, `intents`, `intentsui`, `accessibility`, `javascriptcore`, `arkit`, `scenekit`, `mediaplayer`, `network`, `avkit`, `healthkit`, `messageui`, `securityui`, `usernotificationsui`, `notificationcenter`, `messages`, `metrickit`, `sensorkit`, `coremotion`, `replaykit`, `speech`, `mlcompute`, `gamekit`, `corenfc`, `iokit`, `cfnetwork`, `accounts`, `appclip`, `adservices`, `apptrackingtransparency`, `browserkit`, `coreservices`, `iosurface`, `mps`, `mpsgraph`, `cloudkit`, `pdfkit`, `networkextension`, `gameplaykit`.

The `sources` config is the digest of the sources, their headers, the build module and the Revenant releases: a changed backport or a new release is a different package.

### Bands

A band is one set of libraries for a range of releases. Its boundaries are the port's minimum and every release at which the SDK's availability gives a symbol a backport source exports. A band runs to the last release of the firmware catalogue before the next boundary; the last band runs to the catalogue's last release that an armv7 device gets.

- Each band is built for its first release, and import-checked against the shared caches of its first and last release.
- The package holds the libraries of each band under `bands/<release>/`, and a `bands/ranges` file.
- Its `postinst` reads `ProductVersion` from the device's `SystemVersion.plist`, links the libraries of the band whose range holds it, and refuses, naming the ranges it has, a release outside all of them.

`xmake deb` writes `org.revenant.apple-backports_<release>+<digest>_iphoneos-arm.deb` beside a port's package. `<release>` is the latest release of the toolchain the addon lists, and `<digest>` is the first eight hex digits of the digest of the backports' sources, their build module and their recipe. The port's control file gains a `Depends` on that version, and `xmake device install` installs it first.

### Installed names

The libraries are named `/usr/lib/revenant/org.revenant.apple-backports/lib<Framework>Backports.dylib`: `libFoundationBackports.dylib`, `libUIKitBackports.dylib` (`uikit`), `libCoreLocationBackports.dylib` (`corelocation`), `libCoreDataBackports.dylib` (`coredata`), `libAVFoundationBackports.dylib` (`avfoundation`), and one per other config. They are one per process: two copies of a class would be two classes.

The import check refuses a weak import bound to a system library that lacks the symbol while a library of the build exports it. That is the sign of a link that put a framework first.

## Swift runtime notes

`swift-runtime` is built with the Objective-C floor of iOS 6.0. Its Swift classes mark themselves in the low bit of the `data` word, which iOS 6.0's Objective-C runtime masks off and iOS 5.1.1's does not, so older releases would follow a wild pointer. Embedded Swift registers nothing with Objective-C and is not bound by the floor.

Without `library_evolution` the runtime is compiled without resilient layouts. A resilient layout makes a client's class need `_objc_realizeClassFromSwift`, which only iOS 12 and later have, and the runtime stops with "class ... does not have a fragile layout" where it is missing. The `.swiftinterface` of these modules is not a stable contract, and `libswiftCore` carries a mark naming the build it is; a program links only against the build that compiled it.

With `library_evolution` the runtime is the one Apple builds, for programs an SDK's Swift compiled. Its arm64 install stops after Darwin: an arm64 consumer that expects `libswiftFoundation` from this package finds the SDK's instead. armv7 installs every overlay. Measured through the recipe, arm64 and armv7 install with `library_evolution`, and only armv7 without it.
