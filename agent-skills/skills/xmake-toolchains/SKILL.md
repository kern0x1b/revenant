---
name: xmake-toolchains
description: Reference for the compiler side of an old-iOS app built with Charon and xmake 3.1.1 — what the apple-ios toolchain is made of (clang from the charon llvm package, ld64 from cctools-port, the SDK package, ldid), how the rules bind it to each target and the include to each package, what every compile and link gets (-target, -miphoneos-version-min, -isysroot, -femulated-tls, the weak-reference runtime flag, the blocks runtime, IPHONEOS_DEPLOYMENT_TARGET), the refusal when the architecture and apple_minimum disagree, what changes when either changes, how a universal armv7+arm64 app is built in slices and merged, why Homebrew llvm must be installed although it is not the compiler, and what not to use (Xcode, --toolchain, set_toolchains, the simulator, --target_minver). Use when choosing or changing architectures or the lowest release, when a configure or build refuses an architecture, or when you need to see exactly how a file is compiled and linked.
---

Derived from the `xmake-toolchains` and `xmake-cross-compilation` skills of xmake-io/xmake-skills at `ef67caa` (Apache-2.0), rewritten and modified for Charon.

# The apple-ios toolchain

An app for old iOS is cross-compiled on the Mac by Charon's `apple-ios` toolchain. You do not
choose or define a toolchain: each Charon rule sets `apple-ios` on its target when the target
loads, and the `@addon/charon/apple-ios` include hands it, as a config, to every package the
project requires. What you choose is the platform (`iphoneos`), the architecture and
`apple_minimum`. Read `PROJECT.md` first: its `## Target` names the lowest release, the devices
and the architectures. Which architecture runs which releases is the skill `project`'s (step 2).

## 1. What the toolchain is made of

| Part | Package |
| --- | --- |
| compiler | `charon@llvm` 23.1.1: clang built from source, with Charon's patches for emulated thread-locals and atomic library calls |
| linker | `charon@ld64` 956.6: Apple's ld64 from cctools-port, the linker that still inserts branch islands for armv7 |
| SDK | `charon@iphoneos-sdk` 16.4, with the startup objects (`crt1.o`, `crt1.3.1.o`, `dylib1.o`, `bundle1.o`), `libgcc_s.1.tbd`, the blocks runtime and arclite added for old releases |
| signing | `charon@ldid` |

No Xcode is involved. **Homebrew's `llvm` must still be installed**: it is not the compiler, but
building `charon@ld64` looks for `llvm-config` in `$LLVM_PREFIX/bin`, `/opt/homebrew/opt/llvm/bin`
or `/usr/local/opt/llvm/bin`, and without it stops with `ld64 links libLTO, and cctools' configure
finds it through llvm-config; install a full LLVM, such as brew install llvm`. The skill `install`
puts it in place.

How to know it worked: `xmake show -t <Name>` prints the compiler as `…/packages/l/llvm/23.1.1/
<hash>/bin/clang`, and its `linkflags` carry `-fuse-ld=…/packages/l/ld64/956.6/<hash>/bin/ld`.

## 2. Architecture and lowest release

```
xmake f -p iphoneos -a armv7 -y > .logs/configure.log 2>&1
```

`apple_minimum` is set in `xmake.lua` (`set_config("apple_minimum", "<release>")`), not on the
command line. When the toolchain loads, it refuses a release the configured architecture does not
run, and names the way out:

- `apple_minimum <r> is older than <first>, the first release an <arch> device runs; <archs> runs
  it, so build that architecture, or raise apple_minimum to <first>` (or `no architecture this
  toolchain builds runs it, so raise apple_minimum to <first>`);
- `apple_minimum <r> is newer than 4.2.1, the last release an armv6 device runs`.

Do what the message says only after asking the user if it changes a decision in `PROJECT.md`;
never move `apple_minimum` on your own to make a configure pass.

Changing the architecture or `apple_minimum` changes the toolchain config every required package
is built with, so those packages install again for it, each under a new path; the SDK, ld64, ldid,
the compiler, the firmware tools and the emulator's packages are shared. The import check then needs that release's
libraries for that architecture (`xmake firmware --arch=<arch> fetch <release>`, skill
`firmware`).

How to know it worked: `xmake show` prints `plat: iphoneos` and `arch: <arch>`; the build's
`imports:` line names the architecture (`… of the armv7s slices of …`).

## 3. What every compile and link gets

`xmake -v` shows it; add none of it by hand:

- `-target <arch>-apple-ios -miphoneos-version-min=<release> -isysroot <SDK 16.4>
  -mlinker-version=956.6` on every compile and link, and `-fuse-ld=<ld64>` on the link;
- `-femulated-tls` below iOS 9.0 on 32-bit ARM (below 8.0 on arm64), so thread-local variables
  work on releases whose dyld has none;
- below iOS 5.0, `-Xclang -fobjc-runtime-has-weak` on Objective-C; below 3.2, `-lBlocksRuntime
  -lobjc` on the link;
- `IPHONEOS_DEPLOYMENT_TARGET=<release>` in the environment of the compiler and linker;
- for packages only, `-O3` (the project's own files get what its mode rules say, skill
  `xmake-basics`).

The `-Wincompatible-sysroot` warning on every compile is expected (skill `build`): the SDK is
newer than the release by design, and the import check against the release's own libraries is
the truth, not the SDK's headers.

## 4. A universal app (armv7 + arm64)

Only when `PROJECT.md` lists 64-bit devices; the target line, the configured architecture and the
plist are the skill `project`'s (step 2). What happens underneath: `xmake deb` builds each other
architecture in its own folder, `build/.charon/slices/<arch>/`, for the first release it runs when
`apple_minimum` is older — the slice build prints `note: the arm64 slice is built for iOS 7.0,
the first release an arm64 device runs; apple_minimum <r> holds for the armv7 slice` — then
merges the bundles with `lipo`, and checks and signs the result per architecture.

The merge refuses bundles whose other files differ: `the slices of <Name>.app cannot be merged:
Info.plist differs between slices in MinimumOSVersion (armv7: 6.0, arm64: 7.0). Each slice derives MinimumOSVersion from its own
target; pin it in app.plist-file or app.plist`. Write `MinimumOSVersion` into `Info.plist`
yourself, as the skill `project` says.

How to know it worked: the `xmake deb` log has the note above and an `imports:` line per
architecture, and `lipo -archs` on the executable inside the package prints `armv7 arm64`.

## 5. What not to use

- `--toolchain=`, `set_toolchains(…)`, `--sdk=`, `--cc=`, `--ld=`: the Charon rule sets
  `apple-ios` on each target from the pinned packages when the target loads; a compiler or SDK
  named by hand is not the one the checks and the lock files assume.
- `-p iphonesimulator`, `-p macosx` for the app, `--target_minver=`, `--xcode_sdkver=`,
  `--appledev=`: those belong to xmake's Xcode-based platform. Charon builds for devices only,
  and the lowest release is `apple_minimum`. Given on the configure line they also reach a
  macOS host-test target (skill `xmake-tests`) and change its target triple and SDK.
- The Command Line Tools' `clang`, `cc` or Homebrew's `clang` for anything that runs on the device
  (skill `build`, `Bad system call: 12`).
- `xmake show -l toolchains` to find Charon's: it lists xmake's own toolchains and the project's,
  not an addon's. Look at a target with `xmake show -t <Name>` instead.

## Traps

- `-a arm64` configured alone for an app whose `apple_minimum` is below 7.0 → configure `-a armv7`
  and add arm64 through `apple.architectures`. Reason: an architecture configured alone is
  refused below the first release it runs.
- `armv6` for a 3GS or later → armv7. Reason: armv6 runs only up to 4.2.1; every device from the
  3GS on runs armv7.
- Uninstalling Homebrew's `llvm` because "Charon brings its own clang" → keep it. Reason: whenever
  `charon@ld64` has to be built (a clean machine, a tag whose linker recipe changed) it needs
  `llvm-config`.
- Silencing `-Wincompatible-sysroot` or trusting the SDK's availability annotations → rely on the
  import check. Reason: the SDK is iOS 16.4; only the release's own libraries say what exists.
