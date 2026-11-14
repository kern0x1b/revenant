# reCAPTCHA Enterprise SDK on iOS 6: the work split

[The feasibility study](recaptcha-sdk-on-ios6.md) says the original arm64 `RecaptchaEnterprise.xcframework` can run on an
iPhone 4S through the recompiler, with the arm64 Swift runtime as a guest. This page splits what is left into blocks that
can be worked on in parallel, each with a goal, a criterion that can be measured, where the code is, how to test, and what
to build on. Every block's worker starts from this page and the study alone.

## What is shared

- The input is the arm64 slice of the SDK, local use only. The measurement that lists what it imports is
  `build/recaptcha-2a/` of the main checkout's `.cache/scratch/` when it is kept; `out/unresolved.txt` there has the 449 names
  that no image answers (section 13 of the study counts them).
- The imports that block a lift, by owner of the answer:

  | Names | Count | Answered by |
  | --- | --- | --- |
  | `$s10Foundation…`, `…So…` (Foundation, imported ObjC types) | 59 + 22 | block A |
  | `$s9CryptoKit…` | 18 | block B |
  | `$s8Dispatch…` | 9 | block A |
  | `$s7Network…` | 8 | block B |
  | Darwin overlay names | 2 | block A |
  | `$ss…` and `_swift_*` | 65 + 76 | the guest `libswiftCore` (done) |
  | host functions with no generated bridge (libc, ObjC, CF, Security, dispatch, CommonCrypto) | 114 | block E |

- The guest runtime is the arm64 build of `revenant@swift-runtime` (`-p iphoneos -a arm64`, `apple_minimum` 7.0), the
  recipe `packages/s/swift-runtime/xmake.lua`. Its guest images are translated together with the program
  (`recompiler/tools/translate.lua`, the images as arguments or as `XL_REPLACES`); the program's own Swift classes with a
  host ancestor need `XL_SWIFT_HOST_ANCESTORS=1`. Section "The twin scheme" of
  [how the recompiler works](recompiler/how-it-works.md) says why.
- The check of the object model is `recompiler/tests/swiftobjc` (device, see [the corpus](../reference/recompiler/corpus.md)).
  A block's own check is a fixture beside it, in the same shape: a Swift program compiled for `arm64-apple-ios12.0`, translated
  with the guest images, run on the phone, and a list of `ok <name>` lines that the check wants.
- The rules of the repository hold: no comments, forward-only git, one commit per component, `tools/prepush.lua` before a push,
  scratch and build output under the private cache, the phone claimed through the skill `device-session`.

## Building the guest runtime

The arm64 runtime is a package build, not a project of its own. A scratch project outside the repository requires it, and
configuring that project for `iphoneos` and `arm64` installs the runtime into the private cache:

```lua
set_project("guest")
add_repositories("revenant <worktree>")
add_addons("revenant", {sourcedir = "<worktree>/toolchain"})
set_config("apple_minimum", "7.0")
set_config("apple_compat_only", true)
includes("@addon/revenant/apple-ios")
add_requires("revenant@libcxx", {alias = "libcxx"})
add_requires("revenant@swift-runtime", {alias = "swift-runtime", configs = {library_evolution = true}})
target("guest")
    set_kind("phony")
    add_packages("swift-runtime", "libcxx")
```

```sh
REVENANT_CACHE=<worktree>/.cache-private ./xmakew f -P <scratch>/guest -p iphoneos -a arm64 -y -c
```

With the prebuilt LLVM, Swift and ld64 (`REVENANT_PREBUILT=kern0x1b/revenant`, `REVENANT_PREBUILT_ONLY=llvm,swift,ld64`) it
takes about four minutes on a warm cache. The images land in
`<cache>/xmake-global/.xmake/packages/s/swift-runtime/6.4.0/<key>/lib/swift/iphoneos/`: `libswiftCore.dylib`,
`libswiftDarwin.dylib`, `libswift_Concurrency.dylib`, `libswiftObservation.dylib`, `libswiftSynchronization.dylib`,
`libswift_StringProcessing.dylib`, `libswift_RegexParser.dylib`, `libswiftRegexBuilder.dylib`,
`libswiftSwiftOnoneSupport.dylib`, each with its `.swiftmodule`. `libc++.1.dylib` and `libc++abi.1.dylib` are in the
`libcxx` package's `lib`. The key changes when the recipe or one of its patches changes, so look it up, do not copy it.

A worker needs the branch `recaptcha-sdk-feasibility` (the recipe takes its install prefix from the package, and the
patch for the guest's raw `isa` reads is in it) and its own private cache (`tools/private_cache.lua`).

## A. arm64 overlays: Foundation, Dispatch, Darwin

Goal: the guest has the Swift overlays the SDK imports from Foundation, Dispatch and Darwin, so the 59 + 22 + 9 + 2 names
resolve to guest images.

Criterion: `xlate` run on the SDK's 319 objects with the guest images no longer lists those names in `out/unresolved.txt`;
a fixture that builds a `URLRequest`, sets headers and a body, round-trips `Data` and `JSONSerialization`, and uses a
`DispatchQueue` and `DispatchSemaphore`, prints all its lines on the 4S.

Where: the overlay block of `packages/s/swift-runtime/xmake.lua` is under `if not package:is_arch("arm64")`; the armv7 build
already makes `ObjectiveC`, `Dispatch`, `CoreFoundation` and `Foundation` there (`build_overlay`), with patches in
`packages/s/swift-runtime/patches/overlays/`. The work is the arm64 variant of those four, then their translation as guest
images (each is one more `--replaces` or image argument). The simd overlay is the known trap: at SDK 26.2
`_DarwinFoundation1` makes the overlay's own `sqrt` of Darwin ambiguous, which is why simd is skipped for arm64.

Test: the host check is `xlate` plus the name diff above; the device check is the fixture. Build the runtime first (the
section above).

Build on: the armv7 overlay recipe; `swift-corelibs-foundation` and `swift-foundation` (Apache-2.0) for behaviour only if
an overlay symbol turns out to be implemented there and not in the overlay sources.

## B. arm64 CryptoKit and Network

Goal: the 18 CryptoKit and 8 Network names resolve to guest images.

Criterion: the names leave `out/unresolved.txt`; a fixture hashes with `SHA256`, runs `HMAC` and `AES.GCM` seal and open
against fixed vectors, and starts and cancels an `NWPathMonitor`, printing all lines on the 4S.

Where: `packages/c/cryptokit` is the CryptoKit module as swift-crypto's `Crypto` re-exported with the SDK's nested names
(armv7 and arm64 share its sources); `frameworks/Backports/src/Network/` has `NWPathMonitor.swift` and `NWConnection.swift`
(ADR 0016: the overlay runs over SCNetworkReachability). The work is building both for arm64 as guest images; the
reachability calls Network makes are host functions, so they need bridges (block E) and no guest copy.

Test: as the criterion; the Network fixture needs the phone's Wi-Fi state only to see `NWPath.Status`, not a request.

Build on: swift-crypto (Apache-2.0) as the package already does; no new implementation of a primitive.

Status, 2026-11-12: the guest images are two packages with a new arm64-only config `evolution`, not `packages/c/cryptokit`
(which re-exports `Crypto` under the module name `Crypto`, so none of the SDK's `$s9CryptoKit…` names are in it).
`swift-crypto` with `evolution` compiles the same sources as the module `CryptoKit` with library evolution against the
runtime built with `library_evolution`, and `network` with `evolution` compiles the path monitor of the Network overlay
(`NWPathMonitor`, `NWPath`, `NWInterface`, `NWEndpoint`, the two IP address types) with swiftc and links it on
SystemConfiguration; connections and listeners are not built, and the backports package is not part of it. The SDK imports
25 `$s9CryptoKit…` and 11 `$s7Network…` names in all (the measurement of the table above counted fewer); every one of them
is exported by the built dylibs (`nm -gU` against `nm -u` of the SDK image). The unresolved-name measurement is made
(next section); the fixtures on the 4S are still to do.

The path monitor calls `SCNetworkReachabilityCreateWithAddress`, `GetFlags`, `SetCallback` and `SetDispatchQueue`, which
iOS 6.1.3 has. A translation whose includes file lacks `SystemConfiguration` has no declaration for them, so `xlate`
reports the four as `UNSUPPORTED: no declaration in the SDK headers` and the first `NWPathMonitor` aborts with
`xlate: unsupported: SCNetworkReachabilityCreateWithAddress`. `recompiler/include/recaptcha-includes.h` imports
`SystemConfiguration/SystemConfiguration.h` for that reason; a fixture that starts a path monitor needs the same line.

### Measuring the unresolved names without a lift

`xlate` reports every import no guest image resolves before it lifts anything, so the list costs about 0.1 second and under
100 MB, not a translation:

1. Link the arm64 slice of the SDK's static archive into one dylib: `lipo -thin arm64` of the framework binary, then
   `clang -arch arm64 -dynamiclib -all_load -Wl,-undefined,dynamic_lookup -install_name @rpath/libRecaptchaGuest.dylib
   -framework Foundation` over the archive (319 members, 712 undefined names).
2. Run `xlate --base 0x10000000 --output lifted.bc --layout layout.txt --passthrough <empty file> --state-header xl_state.h
   --bridge libxl-guest.dylib` with the SDK dylib and the guest images. Do not pass `--objc-manifest`: that route is the
   analysis pass, which writes `manifest.json` and `guest-resolved.txt` and never reports. The run exits 1 and prints
   `call stub for unresolved import _X` for each name left; the image named in the line says whose import it is.
3. A bind that names a library by path takes that library: every image needs `--replaces <path the SDK binds>=<image>`
   (`/usr/lib/swift/libswiftX.dylib` for each overlay, `/usr/lib/libc++.1.dylib`, and
   `/System/Library/Frameworks/CryptoKit.framework/CryptoKit` for the CryptoKit image), otherwise `xlate` refuses the image
   (`a bind names …, which no guest image is`).

Count only the lines of the SDK image: the images' own unresolved stubs (libswiftCore 146, libc++ 157, Dispatch 108, …) are
host imports of the images, the same kind as the SDK's own remaining ones.

Result, 2026-11-13, the SDK from the Xcode 27.2 SDK, empty passthrough: with only libswiftCore and libc++ 300 names of the
SDK are unresolved; with the whole set (CoreFoundation, Darwin, Dispatch, ObjectiveC, `_Concurrency`, Foundation,
CoreGraphics, Network, CryptoKit added) 113. All 187 Swift names (Foundation 59, CryptoKit 18, Dispatch 9, Network 8, other
overlay and standard library 93) are resolved and none is new. The 113 left are host C and Objective-C runtime symbols
(libSystem, libobjc `objc_*`/`class_*`/`method_*`, CoreFoundation, Security, `CC_SHA256`, `Block_*`, `dispatch_once`,
`os_unfair_lock_*`), which the passthrough and the runtime bridge answer, block E. Three weak `Locale.Language` names bind to
`Foundation.framework` and stay unbound ("a bind takes the library it names"); the SDK takes its fallback for them.

To tell which of the 113 have a bridge, run `xlgen` with the names as `--symbols`, the `manifest.json` of an analysis pass of
the same images as `--objc-manifest`, and an includes file that imports Foundation, UIKit, WebKit, DeviceCheck, Security,
CoreMotion, CoreTelephony, AdSupport, SystemConfiguration and `CommonCrypto/CommonDigest.h`; without Foundation six
`NS*` functions read "no declaration in the SDK headers". Six symbols read UNSUPPORTED with an empty `--guest-provided`: `class_copyMethodList`,
`class_getMethodImplementation`, `method_getImplementation`, `imp_implementationWithBlock` (a result that is a pointer to a
struct or a function pointer), `getaddrinfo` (the `addrinfo` layout differs) and `sscanf` (no `va_list` variant). They are
not gaps: the runtime bridges them by hand (`objc_bridge.m`, `bridge.m`) and `tests/hostbridges` runs all six on the 4S. Of the 298 selectors left
UNSUPPORTED with that includes file almost all are the SDK's own protobuf getters and obfuscated selectors of its own classes.

## C. Objective-C exceptions across guest frames

Goal: an Objective-C or Swift error raised in guest code and caught in guest code works, and one raised by the host and
caught in the guest works.

Criterion: the 14 `objc_begin_catch` sites of the SDK are reachable without the trap; a corpus fixture (device) throws an
`NSException` in a guest frame under a guest `@try`, and one in a host method called from a guest `@try`, and both are
caught, with the unwind through at least two guest frames and one translated C++ frame.

Where: `recompiler/src/xlate/` lifts `__Unwind_Resume`, `objc_begin_catch`, `__gxx_personality_v0` as traps today
(`recompiler/tests/cxxinit` is the regression test for the C++ static-initialiser case, where they are only hit if an
exception propagates). The design question is how a guest frame is unwound: the lifted functions have no unwind tables of
the host's kind, so either each lifted call site carries a landing pad that the runtime reaches from the guest's own
`__unwind_info`/LSDA, or the runtime unwinds the guest's frame chain itself and resumes at the guest's handler.

Test: the corpus fixture above; the SDK's catch sites by the coverage count of `xlate --coverage`.

Build on: libunwind's own sources for the LSDA and compact unwind formats (read for the format; not copied where the
licence forbids), and the existing guest frame walker in `recompiler/src/runtime/runtime.c` (`xl_walk_guest`).

Done: the second way, with the host's own unwinder. Each lifted call that has a landing pad is an `invoke` whose pad names
the host personality; see "Exceptions" in `recompiler/how-it-works.md` and the `exceptions` check in the corpus reference.
The SDK's 14 catch sites and 15 resume sites are among 349 call sites in 60 functions that unwind to 54 landing pads.

## D. Library mode (milestone 3b)

Goal: the translated SDK and the guest `libswiftCore` and `libc++` are packed as armv7 dylibs plus a loader that an app
links and initialises, inside the app's process. The SDK's token is bound to the app (main bundle, bundle id, keychain,
`Info.plist`), so a separate process is not an option.

Criterion: a test app with a large host (about 85 MB resident, like Telegram) links the dylibs, calls an init, and a
Swift call into the guest returns; the resident set, the address-space map and the guest's threads are measured and
written to the reference.

Where: `recompiler/tools/translate.lua` makes a program; the images are at fixed guest addresses (main `0x10000000`,
`libswiftCore` `0x10100000`, `libxl-guest` `0x10900000`, `libswiftCore`'s data near `0x105c4000`), and the guest address is
the host address, so the first check is whether those ranges are free in the host app (the base is `XL_BASE`/`--base`). The
probe binary is about 119 MB, almost all of it the lifted `libswiftCore`.

Test: the test app on the 4S; `vmmap`-style numbers from the phone's `/proc`-less tools are not available, so use
`task_info` resident size in the app and report it.

Build on: how `recompiler/src/runtime/` starts a program (`xl_bridge_init`, `xl_run_initializers`), the Backports loader
for how a dylib is loaded by an app.

Done: `XL_LIBRARY=1` builds two dylibs, the library (the guest image is a section of it, the host part is placed by dyld anywhere)
and a registry of the guest's Objective-C classes, `xl_loader` reserves the guest range and loads them, and a fixture
(Objective-C and Swift, public classes with `NSInteger`, object and block parameters, a category) runs on the 4S inside an
85 MB host in every launch of 130 (the heap of the host started at its random places, the reservation of the first design failed 3 launches of 20),
also with a Swift runtime of its own in the host. Measured: the 162 MB Swift library adds 4.4 MB resident after its first calls. Numbers, address maps and what is not done
(no dead-strip, no lazy loading, the real SDK not yet) are in
[the library mode reference](../reference/recompiler/library-mode.md).

## E. Host bridges (about 114 functions)

Goal: the host functions the SDK and the guest runtime import have generated bridges.

Criterion: `xlgen` reports no `UNSUPPORTED: no declaration in the SDK headers` for the names in `out/unresolved.txt` that are
host functions; the names the SDK headers lack (`NSClassFromString` at the include level of the corpus, `_NSGetArgc`,
`_Unwind_*`) get an include or a hand-written bridge in `recompiler/src/runtime/`.

Where: `recompiler/src/xlgen/` and the include header `recompiler/include/swiftdemo-includes.h`.

Status: the bridges are done and the `hostbridges` corpus program passes 70 of 70 on the iPhone 4S (see
[the corpus reference](../reference/recompiler/corpus.md)). The one function the iOS 6 host lacks that the SDK imports,
`SecKeyCreateWithData`, is a Backports implementation, checked against macOS and on the 4S (see
[Security](../reference/backports/Security/README.md), "Keys made from data").

## Held by the lead worker

The Mirror crash (every `Mirror`, `print` of a struct or enum, `AnyCollection` aborts in the guest `libswiftCore`; the
smallest case is `String(describing: SomeClass.self)`: `String(describing:)` releases a `_RandomAccessCollectionBox`, whose
destroy call reaches a null function pointer); the raw
`isa` reads of the guest runtime on host objects; the 4S memory probe and the plan to shrink the image (dead-stripping what
the SDK cannot reach).
