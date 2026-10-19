---
name: xmake-swift
description: Reference for how a Swift target is built for old iOS with the Charon addon at the 0.8.10 pin — the @addon/charon/swift rule next to app, daemon, tweak or library, the packages it needs (charon@swift-runtime and charon@libcxx for the whole language, or charon@swift-embedded for the subset), the charon@swift compiler, how the rule calls swiftc (one module per target, swift.module, swift.flags, main.swift), which architectures and releases are checked, the runtime a program carries or shares, the backports config, and Objective-C and Swift in one app (a bridging header, a generated Objective-C header in its own target, a module map). Use when adding Swift to xmake.lua, when a Swift target is refused at load or link, when Objective-C must call Swift or Swift must call Objective-C, or when choosing between a carried and a shared runtime.
---

Derived from the `xmake-swift` skill of xmake-io/xmake-skills at `ef67caa` (Apache-2.0), rewritten and modified for Charon.

# Swift in xmake, with Charon

Charon compiles Swift with its own compiler, built from source, against a Swift runtime the program
brings with it, because no old iOS ships one. This skill covers what `xmake.lua` has to say for
that and what the rule does with it at the pin (`v0.8.10`, `charon-repo-0.8.10`). The Objective-C
side of a mixed app is the skills `xmake-objc` and `objc`, the app target is the skill `project`,
and reading the build is the skill `build`. The Swift itself (the choice between the whole runtime
and Embedded Swift, availability, UIKit, GCD) is the skill `swift`; Combine is the skill `combine`,
SwiftUI the skill `swiftui` (no package at this pin). Read `PROJECT.md` first: the language, the lowest
release, the architectures and the backports decide everything below.

## 1. The pieces

- **The rule.** `add_rules("@addon/charon/app", "@addon/charon/swift")`: the `swift` rule is added
  next to `app`, `daemon`, `tweak` or `library`. It can also stand alone on a static library of
  Swift (`set_kind("static")`), because it depends on the `apple-ios` rule itself
  (`v0.8.10:rules/swift/xmake.lua:2`).
- **One standard library, required by the project** (`rules/swift/xmake.lua:9-28`). The rule adds
  the package to every Swift target itself, so the target needs no `add_packages` for it:
  - the whole language: `add_requires("charon@swift-runtime", {alias = "swift-runtime"})` **and**
    `add_requires("charon@libcxx", {alias = "libcxx"})`. That gives Objective-C interoperation,
    Foundation, UIKit, CoreData and the other overlays, concurrency, regular expressions and
    Observation;
  - the subset: `add_requires("charon@swift-embedded", {alias = "swift-embedded"})`, Embedded
    Swift. It has no runtime library, no Objective-C interoperation, no reflection, no `Codable`
    and no `async`. C calls it through `@_cdecl` functions (`v0.8.10:README.md:489-495`).
  Both, or neither, is refused when the target loads (`target(<Name>) compiles Swift, and its
  project requires both …` / `… requires neither: …`). The runtime without libcxx is refused too
  (`… which links the C++ runtime: add_requires("charon@libcxx", …)`). All three measured at the
  pin, at `xmake f`.
- **The compiler** is `charon@swift` 6.4.0, a host dependency of either package, built from its
  sources with two changes for old releases (`README.md:498-513`). The rule takes its `swiftc`
  from the package (`rules/swift/xmake.lua:147-150`). Not the Command Line Tools' `swiftc`: a
  compiled module loads only in the compiler that wrote it. The first Swift build compiles that
  compiler and the runtime and takes hours. Run it once with a long timeout and wait (skill
  `install`). The packages side is the skill `xmake-packages`.

## 2. How the rule compiles

(`v0.8.10:rules/swift/xmake.lua:139-207`, `modules/apple/swift.lua:143-189`)

- All `.swift` files of a target are **one module**, compiled whole-module (`-wmo`) in one
  `swiftc` call into one object. The module is named by `set_values("swift.module", "<Name>")`,
  or by the target name. Characters that are not letters, digits or `_` become `_`.
- A file named `main.swift` makes the module a program's entry point. Without one, the module is
  compiled with `-parse-as-library`.
- With the runtime, the flags include `-target <arch>-apple-ios<minimum>`, the SDK,
  `-Xfrontend -bundled-swift-runtime` and `-runtime-compatibility-version none`. The optimization
  follows the mode: none → `-Onone`, smallest → `-Osize`, anything else → `-O`. Debug symbols
  add `-g`. Embedded Swift makes LLVM bitcode, and the `llvm` package's clang makes the object.
- **Every other `swiftc` option goes through `swift.flags`**, e.g.
  `add_values("swift.flags", "-warnings-as-errors")`. The rule builds the `swiftc` command line
  from its own flags, the packages' module folders and `swift.flags` alone. `add_scflags`,
  `swift.interop` and `swift.modulename` from generic xmake are not read.
- A Swift library package names its module folders in `CHARON_SWIFT_MODULES`. The rule adds them
  as `-I` for every package the target uses (`:162-167`), so `import <Module>` works with
  `add_requires` and `add_packages` alone. At the pin that library is Styx, `import Combine`
  (skill `combine`).

## 3. Architectures and releases

The rule and the recipes refuse no architecture themselves. The toolchain's pairing of
architecture and `apple_minimum` applies as for any target (skill `xmake-toolchains`). What the pin
has checked:

- Embedded Swift: armv7 and armv7s at 6.0 and arm64 at 7.0, against the devices' own libraries.
  Older releases are "not checked yet" (`README.md:497-498`, `tests/addon/swift_test.lua:97`).
- The runtime: it is built for the target's architecture and oldest release, with the calls old
  releases lack taken from `charon@apple-compat` (`README.md:522-538`). The pin's README names no
  release the whole runtime was checked on. Tell the user that their release and architecture are
  checked first by their own build and then in the emulator (skill `emulate`).
- armv6: nothing at the pin builds or checks Swift for it. Do not promise it.

## 4. The runtime: carried or shared

- **Carried** (the default). The rule adds `swift-runtime` and `libcxx` to `app.frameworks` and
  `charon.libraries` (`rules/swift/xmake.lua:47-53`). An app then bundles the libraries in
  `<Name>.app/Frameworks/`. A daemon or tweak places them in `/usr/lib/charon/<Package>/` and must
  name its package with `set_values("charon.control", …)` (`modules/apple/platform.lua:330-334`).
- **Shared**: `configs = {shared = true}` on `swift-runtime` and `configs = {packaged = true}` on
  `libcxx`. The runtime is then a Debian package of its own, which the program depends on and does
  not carry (`charon-repo-0.8.10:packages/s/swift-runtime/xmake.lua:86-90`). A shared runtime with
  a libcxx of other configs is refused (`… require charon@libcxx with the same configs as the
  runtime does (packaged)`). All of this is read from the recipe: a shared runtime was not built
  or checked at the pin, so whether its app passes `xmake deb` is not known.
- Import check: every binary the bundle carries, the runtime's libraries included, is held to
  the same weak-import rule as the app. Only the libraries of a package the program depends on
  (the backports, a shared runtime) are exempt (`platform.lua:22-24,226-229,437-471`). At the pin
  a carried runtime does not pass: `xmake deb -y -v` of a Swift app at `apple_minimum` 6.0 stops
  with `error: these imports are not exported by the device's iOS:` and one line per library of
  the runtime, e.g. `Frameworks/libswiftCore.dylib  weakly imports 9 symbols …` (Dispatch,
  Foundation and others likewise). Do not write `charon.waive.weak-imports` for them yourself. It
  is a limit of Charon at this pin: tell the user (skill `swift` §7 says how) and follow the skill
  `self-review`.
- **One build of the runtime per program.** The libraries are built without library evolution. The
  program links the runtime's build mark by name (`rules/swift/xmake.lua:62-69`), and a target that
  reaches two builds is refused (`target(<Name>) links 2 builds of swift-runtime at once: …`,
  `platform.lua:288-314`). Require every Swift package with the program's configs.
- **Backports in Swift.** `configs = {backports = true}` on `swift-runtime` (and `backports_uikit`
  for an application) makes what `charon@apple-backports` implements available from the program's
  release in Swift too. The rule then requires the program to carry the backports with the configs
  the runtime links (`coredata`, and `uikit` with `backports_uikit`), and names what is missing
  (`rules/swift/xmake.lua:69-91`). Which API to take from the backports is the skill `backports`;
  calling them from Swift is the skill `swift` §5.

## 5. Objective-C and Swift in one app

Only with the whole runtime. Embedded Swift has no Objective-C interoperation. What the Swift
itself must declare for Objective-C to see it is the skill `swift` §4.

- **Swift calls Objective-C** of the same target through a bridging header:
  `add_values("swift.flags", "-import-objc-header", "<path/Bridging.h>")`. The rule passes it
  straight to `swiftc`. Give the path from the project root (xmake builds from the project
  directory).
- **Objective-C calls Swift** through the header `swiftc` writes. Put that Swift in a target of
  its own (a static library with the `swift` rule) and have it write the header:
  `add_values("swift.flags", "-emit-objc-header", "-emit-objc-header-path", "<dir>/<Module>-Swift.h")`.
  The rule then sets the `build.fence` policy on that target, so every target that `add_deps` it
  compiles after the header exists (`rules/swift/xmake.lua:36-42`). The Objective-C target adds
  `add_deps("<that target>")` and `add_includedirs("<dir>")`. The fence orders only dependents.
  In the same target nothing orders the header before the `.m` files.
- **A C or Objective-C module**: a folder with a `module.modulemap` over its headers, passed as
  `add_values("swift.flags", "-I", "<folder>")`, lets Swift `import` it by the module's name.
- The Objective-C files keep `-fobjc-arc` on compile and link (skill `xmake-objc`).

How to know it worked: `xmake -y -v > .logs/build.log 2>&1` shows the `swiftc` command line with
`-bundled-swift-runtime` (or `Embedded`), `build ok` and the `imports:` line. For a carried runtime,
`ls build/iphoneos/<arch>/release/<Name>.app/Frameworks` lists the runtime's `libswift*.dylib`
(`libswiftCore.dylib`, `libswiftFoundation.dylib`, `libswiftUIKit.dylib`, …) and the C++ runtime
(`libc++.1.dylib`, `libc++abi.1.dylib`).

## Traps

- `add_scflags(...)`, `set_values("swift.modulename", …)` or `swift.interop` → `swift.flags` and
  `swift.module`. Reason: Charon's rule reads only those two values; the others are silently
  ignored.
- `--toolchain=swift`, Xcode's or the Command Line Tools' `swiftc` for the app → the rule and the
  packages. Reason: the modules and runtime are built by `charon@swift`, and only it loads them.
- Requiring both `swift-runtime` and `swift-embedded` "to have both" → one. Reason: one program
  takes one standard library; the rule refuses both.
- `-Xfrontend -disable-availability-checking` to get newer API through → `#available`, or the
  backports config. Reason: the SDK's availability is still checked on purpose; the skill
  `self-review` refuses the flag.
- A waiver written to get the carried runtime through `xmake deb` → tell the user. Reason: a waiver
  states that every call is guarded, which you have not checked for the runtime's code.
- A Swift package required with configs other than the program's → the same configs. Reason: two
  builds of the runtime in one program are refused, and they would not interoperate anyway.
- `-emit-objc-header-path` in the app target that also compiles the `.m` files calling it → a
  separate Swift target. Reason: only a dependent target is ordered after the header.
- Killing the first Swift build because the log is quiet → wait. Reason: the compiler and the
  runtime build from source for hours, and a killed build starts that step again.
