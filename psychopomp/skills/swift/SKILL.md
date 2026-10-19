---
name: swift
description: Write the app's Swift for old iOS with Charon — choosing with the user between the whole Swift runtime the program carries and Embedded Swift (what each gives, and that at the 0.8.10 pin xmake deb refuses a carried runtime), availability (#available, the SDK's marks against what the release really has, the release's classes file), UIKit from Swift, @objc and NSObject for Objective-C, the backports config and apple-compat from Swift, GCD and classes of service (DispatchQueue.global(qos:), barriers, work items) below iOS 8, and what to tell the user when the package is refused. Use at the code step when PROJECT.md says Swift, when a Swift build warns about weak imports or selectors, when xmake deb refuses the Swift runtime's libraries, or when the user asks whether their app can be written in Swift for an old release.
---

# Swift for old iOS

You write the app's Swift yourself, from the decisions in `PROJECT.md`, against the releases it
names. Charon compiles it with its own `swiftc` (Swift 6.4) and the iOS 16.4 SDK, and the program
brings the Swift runtime with it, because no old iOS ships one. How `xmake.lua` is wired for that
(the rule, the packages, carried or shared, the bridging header, the module map) is the skill
`xmake-swift`; do not repeat it here. The Objective-C side of a mixed app is the skill `objc`,
reading the build is the skill `build`, packaging is the skill `package`.

Everything below holds at the pin `v0.8.10` / `charon-repo-0.8.10`. What was measured there says
so; the rest is read from the addon, the recipes or the README at the pin.

Read `PROJECT.md` first: the language, `apple_minimum`, the releases to check, the kind of target,
the backports.

## 1. Choose with the user: the whole runtime or Embedded Swift

Ask before you write any Swift, tell the user what each choice costs, and record the answer in
`PROJECT.md`. From the README (`v0.8.10:README.md:489-537`):

| | Whole runtime (`charon@swift-runtime` + `charon@libcxx`) | Embedded Swift (`charon@swift-embedded`) |
| --- | --- | --- |
| Language | all of Swift 6.4: classes, generics, `Codable`, reflection, `async`/`await`, regular expressions, Observation | classes, structures, protocols, generics, closures, `any`, `throws`, arrays, dictionaries, strings; no `Mirror`, no `Codable`, no `async` |
| Objective-C and UIKit | yes: the overlays of ObjectiveC, Dispatch, CoreFoundation, CoreGraphics, Foundation (from swift-5.4.3), QuartzCore, UIKit, CoreData (from swift-5.2.5) | none: no Objective-C interoperation; C calls Swift through `@_cdecl` functions |
| What the program carries | the runtime's `libswift*.dylib` and `libc++` (an app: in `<Name>.app/Frameworks/`) | nothing: the result loads only libSystem |
| Checked at the pin | built for armv7 at 6.0 (measured, `build ok`); no release named in the README where it was run. Run only with the package check waived on a scratch stand (`charon.waive.weak-imports`, §7), which an app must not do: a Combine daemon on an emulated iPhone 4S, iOS 6.1.3 (`pass on iPhone4,1 6.1.3`) | armv7 and armv7s at 6.0, arm64 at 7.0, against the devices' libraries (`swift_test`); older releases not checked. Measured: a daemon whose C `main` calls a `@_cdecl` function built for armv7 at 6.0 and ran on an emulated iPhone 4S, iOS 6.1.3 (`pass on iPhone4,1 6.1.3`) |
| `xmake deb` at the pin | **refused** (§7, measured) | passes (measured: `deb build/<package>_<version>_iphoneos-arm.deb`) |

An app with a Swift interface needs the whole runtime, and at this pin its package is refused.
Say so before the user decides. The honest choices are:

1. the whole runtime, knowing that `xmake deb` refuses it at this pin (§7): it builds and the code
   can be written now, but it does not reach a device as a package until Charon passes it;
2. the interface in Objective-C (skill `objc`) and the logic in Embedded Swift, which the
   Objective-C calls through `@_cdecl` functions (C calling Embedded Swift was built and run at the pin; an Objective-C app with it was not);
3. the whole app in Objective-C (skill `objc`).

Below iOS 6.0 no Swift was built or checked at the pin (Embedded from 6.0, `README.md:497-498`;
the measured runtime build at 6.0), and none for armv6 (skill `xmake-swift` §3). Promise neither.

How to know it worked: `PROJECT.md` names the choice, the reason the user gave, and, for choice 1,
the refusal under `## Limits`.

## 2. Availability: the language, the SDK, the release

Three different things decide whether a line may run on `apple_minimum`:

- **The language and its standard library** are the program's own. Charon's compiler takes
  `-bundled-swift-runtime`, so every feature of Swift 6.4 is available at any deployment target,
  and the runtime's availability macros are rewritten to `*` (`README.md:502-506,536-537`). Do not
  put `#available` around `async`, a regular expression or `Observation`: the compiler asks for
  none. That they compile is read from the README; that they run on iOS 6 was not run at the
  pin, so do not promise it.
- **The SDK's marks** are checked as before (`README.md:504-505`): an API of UIKit, Foundation or
  any framework, and every overlay member reached from a later release, keeps the availability the
  SDK gives it, "so a port for 6.0 asks with `#available`" (`README.md:573-575`). Unlike
  Objective-C, Swift refuses the unguarded call at compile time, so the SDK's marks cannot be
  forgotten; they can only be wrong.
- **The release** is the truth, and the SDK's mark is not the release a symbol appeared in. Read
  the release's own classes file (`xmake firmware -y --arch=armv7 classes <release>`) the way the
  skill `objc` §3 says, for `apple_minimum` and every release to check, before you design around
  an API. A class present below its SDK mark is a private predecessor there; an API the SDK no
  longer declares cannot be reached from Swift either.

For each API newer than `apple_minimum`, choose in the order of skill `objc` §4, and record the
choice in `PROJECT.md`:

1. **A backport**, taken through the runtime's `backports` config (§5): the call then compiles
   without `#available` at the program's release.
2. **The release's own older API**, as Objective-C would (`UIAlertView`, `NSURLConnection`, frames).
3. **A guard**:
   - `if #available(iOS 7.0, *) { … } else { … }` around what the SDK marks newer;
   - `object.responds(to: #selector(…))`, asked of the object itself, where the SDK's mark is at or
     below `apple_minimum` but the release's classes file says the object's class lacks the method.

What `#available` costs, measured at the pin: the scratch Swift app of the xmake checks, whose
code has one `#available(iOS 7.0, *)`, weakly imports `__availability_version_check`, and
`xmake deb -y -v` lists `<Name>  weakly imports 1 symbol … __availability_version_check` among
its refusals, next to the runtime's own libraries (§7). The Objective-C `@available` answered the
release on iOS 6.1.3 in the emulator (skill `objc` §4), and so did Swift's, measured in Embedded
Swift on an emulated iPhone 4S, iOS 6.1.3: `#available(iOS 7.0, *)` answered false. Under the whole
runtime its program does not pass `xmake deb` (§7). Run only with the package check waived on a
scratch stand (`charon.waive.weak-imports`, §7), which an app must not do, on the same emulated
6.1.3, `#available(iOS 7.0, *)` answered false and `#available(iOS 6.1, *)` true.

Never pass `-Xfrontend -disable-availability-checking` through `swift.flags` to get a newer API
through: it makes every `#available` true (the same emulated 6.1.3 answered `#available(iOS 7.0, *)`
true with it), so the guarded call runs on a release that lacks the API; the skill `self-review`
refuses it.

How to know it worked: `xmake -r -y -v > .logs/build.log 2>&1`, then
`grep -n 'build ok\|^imports: \|warning: ' .logs/build.log`. Read only the lines that name your
program (`<Name> weakly imports …`, `<Name> sends … selector …`); the lines that name
`Frameworks/libswift*.dylib` are the runtime's (§7). Every symbol and selector on your program's
lines must be one you guarded.

## 3. UIKit from Swift

Only with the whole runtime. The form built at the pin (armv7, `apple_minimum` 6.0, `build ok`,
measured) is a `main.swift` that starts the application itself:

```swift
UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(AppDelegate.self))
```

with an `AppDelegate: UIResponder, UIApplicationDelegate` that makes its `UIWindow` from
`UIScreen.main.bounds`, sets `rootViewController` and calls `makeKeyAndVisible()` (`main.swift`
is the entry point: skill `xmake-swift` §2). `@main` and `@UIApplicationMain` were not built at
the pin; use the measured form.

- The interface follows the skill `objc` §5 in every point: the release's own controls, built in
  code (Charon's app rule compiles no nib or storyboard), frames and `autoresizingMask`, Auto
  Layout only from 6.0, both rotation methods below 6.0.
- UIKit's overlay is swift-5.2.5's (`README.md:569-573`). Its Swift conveniences keep the SDK's
  marks, and Charon adds marks where that overlay reached a later release (`charon-repo-0.8.10:
  packages/s/swift-runtime/patches/uikit/`). Treat an overlay member like any UIKit API (§2).

How to know it worked: the build as in §2 ends with `build ok`, and `ls build/iphoneos/armv7/
release/<Name>.app/Frameworks` lists `libswiftUIKit.dylib` (skill `xmake-swift` §5). That the app
launches is not shown: at the pin the package is refused (§7), and no Swift app was run.

## 4. Swift that Objective-C sees

Only with the whole runtime. How the targets and headers are wired (a bridging header for Swift
calling Objective-C, the generated `<Module>-Swift.h` in a Swift target of its own for the other
way) is the skill `xmake-swift` §5. What the Swift itself must say:

- A class Objective-C uses derives from `NSObject` (or an Objective-C class) and is `@objc`, and
  so is every member it calls. Built at the pin (measured): `@objc public final
  class Greeting: NSObject` with `@objc public static func text(for name: String) -> String`,
  called from a `.m` file as `[Greeting textFor:@"ObjC"]` through the generated header.
- Objective-C sees only what it can express: no structures, no enumerations with payloads, no
  generics, no Swift-only protocols. Give it a class that wraps them.
- A method a UIKit control calls (`addTarget(_:action:for:)`, a gesture recognizer, a timer's
  selector) is `@objc`, named with `#selector(…)`.

How to know it worked: the build (`-v`, §2) compiles the `.m` file that includes
`<Module>-Swift.h` and ends with `build ok`.

## 5. Backports and apple-compat from Swift

**Backports.** Swift reaches what `charon@apple-backports` implements only through the runtime's
`backports` config (`README.md:575-596`). With it, `modules/apple/lift.lua` lowers, in copies of
the SDK's headers, the release of every API the backports implement to the program's release,
and the rule hands those headers to your Swift (`v0.8.10:rules/swift/xmake.lua:69-92`). What it
does not lower: below an entry's own minimum, and anything the registry calls absent, inert or
ignored; those keep their `#available`. Which API to take and its status is the skill `backports`.

The requires, from the rule and the recipe at the pin (`rules/swift/xmake.lua:75,88`,
`charon-repo-0.8.10:packages/s/swift-runtime/xmake.lua:81-105`):

- `add_requires("charon@swift-runtime", {alias = "swift-runtime", configs = {backports = true}})`;
  an application may add `backports_uikit = true`, which links UIKit's overlay against
  libUIKitBackports (`backports_uikit` without `backports` is refused);
- `add_requires("charon@apple-backports", {alias = "apple-backports", configs = {coredata = true}})`,
  with `uikit = true` when the runtime has `backports_uikit` (and whatever the skill `backports`
  asks for the API you call), and `add_packages("apple-backports")` in the target.

The rule refuses the build when the program does not carry the backports the runtime links, and
names the missing config: a lowered call finds its implementation only where that library is
loaded, and a message to a library that is not there is an unrecognized selector at run time, not
a link error (`README.md:591-596`). Every other Swift package of the program takes the same
runtime configs (skill `xmake-swift` §4). A program with the `backports` runtime was not built at
the pin: all of this paragraph is read from the rule, the recipe and the README.

How to know it worked (by the README, not yet measured): a call to an API the backports implement
compiles without `#available` at `apple_minimum`; one they do not implement is still refused by the
compiler until you guard it.

**apple-compat.** The runtime already takes from `charon@apple-compat` what it calls and the
release lacks (`clock_gettime`, `clock_getres`, `dispatch_get_global_queue`, `memset_s`,
`objc_allocWithZone`, the `dispatch_block_*` family, `os_unfair_lock_*`, …; `README.md:526-529,
605-617`). Swift that reaches those calls through the runtime and its overlays (`DispatchQueue`,
`DispatchWorkItem`, locks of Synchronization) needs nothing more from you.
`add_values("apple.compat", …)` renames calls in C and Objective-C files only: the rule adds its
`-include` flags to `cxflags` and `mxflags` (`v0.8.10:rules/apple-ios/xmake.lua:29-37`); the Swift
compile line is the rule's flags, the module folders and `swift.flags` alone (`rules/swift/xmake.lua:
168-179`). A C call your Swift makes keeps the SDK's mark (§2); if only that call will do, put it
in a C or Objective-C file of the target, where `apple.compat` reaches it (skill `objc` §3).

## 6. GCD and classes of service below iOS 8

A class of service is iOS 8; before it, `dispatch_get_global_queue` answers a class with `NULL`
(`README.md:613-617`). Read from the pinned runtime; of it, only the queue a class maps to was run
(below):

- `DispatchQueue.global(qos:)` and the `DispatchQoS` constants are made available below iOS 8 by
  Charon's patch to the Dispatch overlay, and the global queue of a class is the queue of the
  priority it stands for (`charon-repo-0.8.10:packages/s/swift-runtime/patches/overlays/
  the-overlay-of-dispatch-asks-a-release-before-8-for-the-queues-it-has.patch`). Use it; do not
  hand a raw `QOS_CLASS_…` to a C call.
- `queue.async(qos:flags:…)` with a class, with flags other than `.barrier` alone, or with a group,
  makes a `DispatchWorkItem` only behind `#available(iOS 8.0)`; below it the block is sent as a
  plain `async` (into the group, when there is one), class and flags dropped (swift-5.4.3
  `stdlib/public/Darwin/Dispatch/Queue.swift`, `async(group:qos:flags:execute:)`, the tag the
  recipe pins). `queue.async(flags: .barrier)` with no class and no group is a real barrier
  (`dispatch_barrier_async`).
- A `DispatchWorkItem` you make yourself is built on apple-compat's `dispatch_block_*`: a
  cancelled item does not run, and `wait()`/`notify` work. The class and the enforce flags are
  accepted and change nothing, as a release before iOS 8 has no classes of service. `.barrier` is
  not honoured either: the item runs as an ordinary block (`README.md:619-625`, which gives the
  reason that the release's `dispatch_async` cannot read a block's flags). That part is a limit of
  apple-compat at `v0.8.10`, not of the release, which has `dispatch_barrier_async`; Charon is the
  one to lift it. Until it does, for exclusive access use a serial queue, or
  `async(flags: .barrier)` alone.
- `DispatchQueue.main.sync` from the main thread deadlocks on every release (the SDK's `queue.h`).

How to know it worked: only a run shows it, and at the pin a Swift program that carries the runtime
runs only with the package check waived on a scratch stand (`charon.waive.weak-imports`, §7),
which an app must not do. There, on an emulated iPhone 4S, iOS 6.1.3,
`DispatchQueue.global(qos: .userInitiated).label` answered `com.apple.root.high-priority`. The
`async(qos:flags:)` and `DispatchWorkItem` items above were not run.

## 7. `xmake deb` and the carried runtime at the pin

Measured at the pin (armv7, `apple_minimum` 6.0): a Swift app that carries the runtime builds
(`build ok`, with `weakly imports` and `sends … selector` warnings for `Frameworks/libswift*.dylib`),
and `xmake deb -y -v > .logs/deb.log 2>&1` stops with
`error: these imports are not exported by the device's iOS:` and one line per library of the
runtime (`Frameworks/libswiftCore.dylib  weakly imports 9 symbols …`, `libswiftDispatch` 11,
`libswiftFoundation` 52, …), then the program's own line if its code uses `#available` (§2) or links
a static library with a weak import of its own: with Styx (skill `combine`) that line names
`_CFRunLoopTimerSetTolerance`. The import
check holds every binary the bundle carries to the app's rule, and exempts only the libraries of a
package the program depends on (skill `xmake-swift` §4). A daemon carries the same libraries in
`/usr/lib/charon/<Package>/` and is refused the same way (measured:
`usr/lib/charon/<Package>/libswiftCore.dylib  weakly imports 9 symbols …`); a tweak was not run.

What follows:

- `xmake emulate install` runs `xmake deb` first (skill `emulate` §3), and it stops with the same
  `error: these imports are not exported by the device's iOS:` (measured on the Combine daemon), so
  the program is not installed into the emulator either. It was run only with the check waived on a
  scratch stand, to measure the lines in §2, §6 and the skill `combine`; that is not a path for an app.
- Do not write `charon.waive.weak-imports` to get it through: it states that every use is guarded,
  which you have not read in the runtime, and it hides your own later weak imports (skill `objc` §4).
- The shared runtime was not built at the pin; whether its program passes is not known (skill
  `xmake-swift` §4). Do not offer it as the fix.

Tell the user, in these terms: "The Swift runtime Charon builds for iOS <release> is refused by its
own package check at this version: its libraries weakly import symbols iOS <release> lacks.
The app builds, but it cannot be packaged, installed or run until Charon passes it. We can keep
Swift and wait, move the interface to Objective-C with the logic in Embedded Swift, or write it all
in Objective-C." Record the answer and the refusal under `## Limits` in `PROJECT.md`.

How to know it worked: `grep -n 'weakly imports\|^error: ' .logs/deb.log`; the lines naming
`Frameworks/libswift*` are the runtime's, the ones naming your program are yours to guard.

## Traps

- Promising a Swift app on a device at this pin, or waiving the runtime's weak imports to get
  there → tell the user it builds and is refused at `xmake deb` (§7).
- `#available` around a language feature (`async`, regular expressions) → none needed; the runtime
  is the program's own. Its run on iOS 6 is not shown; do not promise it.
- The SDK's mark taken as the release an API arrived in → the classes file (skill `objc` §3).
- `-disable-availability-checking` in `swift.flags` → `#available` or the backports config (§2).
- `add_values("apple.compat", …)` expected to rename a call in a `.swift` file → it reaches C and
  Objective-C only (§5).
- A lifted API without the backports the runtime links → carry them; the rule says which (§5).
- `DispatchWorkItem(flags: .barrier)` or `async(qos:…, flags: .barrier)` for exclusive access
  → a serial queue, or `async(flags: .barrier)` alone (§6). Reason: apple-compat at `v0.8.10` runs
  a barrier item as an ordinary block, and below iOS 8 the Dispatch overlay the runtime pins sends
  `async` with a class as a plain `async`, flags dropped.
- Objective-C calling a Swift class or member without `@objc`, or a class not derived from
  `NSObject` → the generated header does not declare it (§4).
- Embedded Swift chosen for an app with a Swift interface → it has no Objective-C
  interoperation; UIKit needs the whole runtime (§1).
