---
name: combine
description: Combine on old iOS with Charon at the 0.8.10 pin — Styx, a reimplementation that builds as a module named Combine, taken as charon@styx with alias combine beside the Swift runtime and libcxx; the require and add_packages lines, the configs it must share with the runtime, what import Combine gives (publishers, subjects, operators, ObservableObject and @Published, Timer and NotificationCenter publishers, DispatchQueue, RunLoop and OperationQueue schedulers), what it does not (URLSession publishers, CombineLatest, Merge, collect(byTime:), the SDK's own Combine), the defect of Styx's DispatchQueue scheduler with strides over about 2 seconds and how to work around it, and how to know it worked. Use at the code step when PROJECT.md says Combine, when the user asks for publishers, @Published or ObservableObject on iOS 6, when a Swift build finds no module Combine, or when a target links two builds of swift-runtime after adding Styx.
---

# Combine on old iOS: Styx

Apple's Combine arrived with iOS 13, and the SDK's module cannot serve an old release: in the
`charon@iphoneos-sdk` 16.4 package, `Combine.framework/Modules/Combine.swiftmodule` holds only
`arm64` and `arm64e` interfaces, built for `-target arm64-apple-ios16.4`. Charon's `charon@styx`
builds Styx instead: a reimplementation of Combine compiled against the Swift runtime the app
carries, as one module named `Combine`, so the app writes `import Combine`
(`v0.8.10:README.md:553-567`).

Read `PROJECT.md` first: Combine is recorded under `## Code` (skill `init`), and it needs Swift with
the whole runtime. How that runtime is required and built is the skill `xmake-swift`; the Swift
itself (availability, UIKit from Swift, GCD) is the skill `swift`. Everything below is at the pin:
addon `v0.8.10`, recipes `charon-repo-0.8.10`, whose `styx` recipe builds Styx at commit
`f5fe6511` (version `2026.09.20`, `packages/s/styx/xmake.lua:8`). Facts marked "Styx's own account"
come from Styx's repository at that commit, not from a run of this plugin.

## 1. Require it

Styx is compiled against `charon@swift-runtime` and `charon@libcxx`, with the runtime's own
compiler (recipe `:26-29`, `:43`). It needs the whole runtime: Embedded Swift
(`charon@swift-embedded`) is not an option for an app that uses Combine. With the runtime and
libcxx already required (skill `xmake-swift` §1), add:

```lua
add_requires("charon@styx", {alias = "combine"})
-- in the Swift target:
add_packages("combine")
```

- **`add_packages` is not optional.** The `swift` rule adds `swift-runtime` and `libcxx` to the
  target itself (`v0.8.10:rules/swift/xmake.lua:28`), not Styx. It passes `-I` for the module
  folders (`CHARON_SWIFT_MODULES`) of the packages the target uses and no others (`:161-167`), and
  Styx names its folders there (recipe `:81`). Without `add_packages("combine")` the compile is not
  given the `Combine` module.
- **The same configs as the runtime.** The recipe has `shared`, `backports` and `backports_uikit`
  (`:13-15`) and asks for its `swift-runtime` with those values (`:27-29`), and for a packaged
  libcxx when `shared` is set. Give Styx exactly the values the project gives `swift-runtime`,
  e.g. with the backports config:
  `add_requires("charon@styx", {alias = "combine", configs = {backports = true}})`.
  A Styx built against another runtime build puts two in the program, and the target is refused
  with `target(<Name>) links 2 builds of swift-runtime at once: …`
  (`v0.8.10:modules/apple/platform.lua:288-314`, called from `rules/swift/xmake.lua:43`).
- Styx is linked statically: `libCombine.a` and `libCombineHelpers.a` (its C++ locking helper,
  built against the runtime's libc++), plus the Foundation and CoreFoundation frameworks (recipe
  `:24`, `:30-33`, `:58-79`). It adds nothing to `Frameworks/`; the app carries the runtime as
  any Swift app does (skill `xmake-swift` §4).
- The first configure after adding it may build Styx in the store: let it finish (skill `build`).

## 2. What `import Combine` gives

One module: the core, the Dispatch scheduler and the Foundation integration folded together
(README `:557-560`, recipe `:3`). In Styx's sources at `f5fe6511` (`Sources/Combine/`):

- `Publisher`, `Subscriber`, `Subscription`, `Cancellable`, `AnyCancellable`, `AnyPublisher`,
  `AnySubscriber`; `Just`, `Empty`, `Fail`, `Future`, `Deferred`, `Record`, `Optional.Publisher`,
  `Result.Publisher`, `Publishers.Sequence`.
- Subjects: `PassthroughSubject`, `CurrentValueSubject`. Subscribers: `sink`, `assign(to:on:)`,
  `assign(to:)` for a `@Published` property.
- `ObservableObject`, `@Published`, `ObservableObjectPublisher`.
- Operators, one file each in `Sources/Combine/Publishers/`, among them `map`, `compactMap`, `filter`,
  `removeDuplicates`, `scan`, `reduce`, `flatMap`, `switchToLatest`, `zip`, `catch`, `retry`,
  `replaceError`, `debounce`, `throttle`, `delay`, `timeout`, `receive(on:)`, `subscribe(on:)`,
  `share`, `multicast`, `buffer`, `collect` by count, `encode`/`decode`. Look an operator up there
  before you use it: Styx names three as missing (§3), and its list is its own.
- Foundation: `Timer.publish(every:on:in:)`, `NotificationCenter.default.publisher(for:)`,
  `JSONEncoder`/`JSONDecoder` and the property list coders as `encode`/`decode` targets.
- Schedulers: `DispatchQueue`, `RunLoop`, `OperationQueue`, `ImmediateScheduler`.
- Concurrency: a publisher's `values` as an `AsyncSequence`, and `Future`'s `value`, both marked
  `@available(iOS 13.0, *)` in Styx's own sources (`Concurrency/GENERATED-Publisher+Concurrency.swift:27,199`,
  `Future+Concurrency.swift:20,36`). That mark is Apple's, kept by Styx at `f5fe6511`: a defect
  of Styx, which is the one to lift it. Measured at the pin: `for await v in Just(1).values` in a
  target for 6.0 stops the build with `error: 'values' is only available in iOS 13.0 or newer`.
  Until Styx lifts the mark, subscribe with `sink`.
- `DispatchTime.distance(to:)`, which the runtime's Dispatch overlay (Swift 5.4.3) lacks and the
  recipe adds for the scheduler (recipe `:53-55`, README `:560-562`).

Styx's own account (`docs/TEST-RESULTS.md` at `f5fe6511`): its probe of the surface above passes
on iOS 6.1.3 armv7 on an iPhone 4S and an iPad 2; the upstream suite in emulation passes 1448 of
1453 tests. Of the five that do not, two are the stride of §4, and one (`testRecordDecode`) crashed
in the runtime's Foundation overlay while bridging a dictionary during a JSON decode: check a
`decode(type:decoder:)` of your own data on the release before you rely on it.

## 3. What it does not give

- **No URLSession publishers** (`dataTaskPublisher`): Styx at `f5fe6511` does not ship them (its
  reasons, README `:562-564`: iOS 7, and a TLS stack; recipe `:3`). That is Styx's gap, not the
  release's: `charon@apple-backports` implements `NSURLSession` from iOS 5.0
  (`charon-repo-0.8.10:packages/a/apple-backports/registry/Foundation/base.json:1347-1351`,
  `"status": "implemented"`). Fetch with the backported `URLSession`, or with the release's own
  `NSURLConnection`, and deliver the result through a `Future` or a `PassthroughSubject`. From
  Swift the backport is reached through the runtime's `backports` config, and a program with it
  was not built at the pin (skill `swift` §5); `NSURLConnection` needs nothing more.
- **No `CombineLatest`, `Merge` or `collect(byTime:)`**: absent at `f5fe6511` (Styx's README,
  "What is not included"; no such type in `Sources/`). Build the flow from what is there: `zip`
  when inputs pair up, `CurrentValueSubject`s read together in one `sink`, `flatMap`. Styx adds
  them "as the consuming code needs them"; do not declare your own under Apple's names in
  `Publishers`, which a later Styx would then declare too.
- **No run-loop timer tolerance below iOS 7.** `CFRunLoopTimer` tolerance is iOS 7; below it Styx
  reports `0` and ignores a set (`Sources/Combine/Foundation/Portability.swift:74-95`, behind
  `#available`). A `tolerance:` argument changes nothing on iOS 6.
- **Not Apple's Combine.** No SwiftUI comes with it (skill `swiftui`), and an API the SDK marks
  above the app's release stays marked: availability is checked in Styx as in the app.
- **Not checked for arm64 at the pin.** Styx's own account covers armv7 on iOS 6.1.3; the pin's
  README names no release the whole runtime was checked on (skill `xmake-swift` §3).

## 4. Scheduling on armv7

- UI work: `receive(on: DispatchQueue.main)` or `RunLoop.main` before touching UIKit.
- `@Published` sends in `willSet`: `objectWillChange` first, then the new value to the
  subscribers of `$value`, and only then is the value stored (`Published.swift:70`,
  `Helpers/PublishedSubject.swift:76-87`). In a `sink` on `$value`, use the value it is given;
  reading the property there gives the old one.
- **A defect of Styx's `DispatchQueue` scheduler at `f5fe6511`: a stride over about 2 seconds
  traps.** Styx is the one to fix it.
  `DispatchQueue.SchedulerTimeType.Stride` keeps nanoseconds in an `Int64` and hands them out as
  `magnitude: Int` through `Int(_nanoseconds)`, and `advanced(by:)` reads it
  (`Sources/Combine/Schedulers/DispatchQueue+Scheduler.swift:61-64,103-110`). On armv7 `Int` is 32
  bits, so a stride above 2^31 ns traps there. `delay`, `debounce`, `throttle` and `timeout` all
  call `advanced(by:)` (`Publishers.Delay.swift:169`, `Debounce.swift:214`, `Throttle.swift:224`,
  `Timeout.swift:265`). Styx's own test results report two `Stride` tests crashing on armv7 for
  this reason. Measured at the pin with the package check waived on a scratch stand
  (`charon.waive.weak-imports`; skill `swift` §7), which an app must not do, on an emulated
  iPhone 4S, iOS 6.1.3: `Just(1).delay(for: .seconds(3), scheduler: DispatchQueue.main)` crashed with
  `crash(signal 4, …)` in `DispatchQueue.SchedulerTimeType.Stride.magnitude.getter`; the same delay
  on `RunLoop.main` delivered its value, and 300 ms on `DispatchQueue.main` did too. For intervals
  of 2 seconds and more, schedule on `RunLoop.main` (its stride is a `TimeInterval`) or keep the
  interval under 2 seconds on a `DispatchQueue`.
- A class of service (`DispatchQueue.global(qos:)`) on iOS 6 is the skill `swift`'s, as GCD from
  Swift is.

## 5. How to know it worked

- **Build:** `xmake -y -v > .logs/build.log 2>&1` ends with `build ok` and the `imports:` line
  (skill `build`). The target's `swiftc` line carries
  `-I <…>/styx/2026.09.20/<…>/lib/swift/iphoneos` and the link line `-lCombine` and
  `-lCombineHelpers`: `grep -n 'styx/2026.09.20' .logs/build.log` (measured at the pin on a daemon
  for armv7 at 6.0: `build ok`, `imports: every non-weak import of the armv7 slices of 20 binaries
  resolves …`).
- **Run:** a pipeline you can see, checked on the release in the emulator or on the device (skills
  `checks`, `emulate`, `device`): a value sent through a subject and a `map` arrives in its `sink`;
  a `Timer.publish(…).autoconnect()` ticks on the main run loop. At the pin this was run only
  with the package check waived on a scratch stand (`charon.waive.weak-imports`; skill `swift` §7),
  which an app must not do: on an emulated iPhone 4S, iOS 6.1.3, a
  `PassthroughSubject` through `map { $0 * 10 }` delivered `40` for `4`, a 0.2 s timer ticked within
  1 s, and the run ended `pass on iPhone4,1 6.1.3`.
- **Package:** a Combine app carries the runtime, and at the pin a carried runtime does not pass
  `xmake deb` (skill `xmake-swift` §4). Measured on a daemon: `error: these imports are not exported
  by the device's iOS:`, a line per runtime library, and the program's own line
  `usr/libexec/<name>  weakly imports 2 symbols … _CFRunLoopTimerSetTolerance __availability_version_check`.
  `_CFRunLoopTimerSetTolerance` is Styx's: its `libCombine.a` imports it (`nm -u`), behind the
  `#available` of `Portability.swift:74-95`, so every program that links Styx has it;
  `__availability_version_check` came from the probe's own `#available`. Tell the user; do not
  waive it (skill `self-review`).

Record in `PROJECT.md` under `## Code`: Combine through `charon@styx`, the configs, and any
operator of §3 the design needed and what replaced it.

## Traps

- `import Combine` with no `charon@styx` → require it. Reason: the SDK's Combine has no armv7
  interface and no old release has the framework.
- `add_requires` without `add_packages("combine")` in the Swift target → add it. Reason: the rule
  passes module folders only of the target's own packages; the build stops with
  `error: no such module 'Combine'` (measured).
- `charon@styx` without the configs the runtime has (`backports`, `shared`, …) → the same configs.
  Reason: two builds of the runtime in one target are refused.
- `charon@styx` next to `charon@swift-embedded` → the whole runtime. Reason: Styx is built against
  `charon@swift-runtime` only.
- `URLSession.shared.dataTaskPublisher` → the backported `URLSession` or `NSURLConnection` into a
  `Future` (§3). Reason: not shipped by Styx at `f5fe6511`.
- `combineLatest`, `merge`, `collect(.byTime…)` from memory of Apple's Combine → compose from what
  Styx has. Reason: absent at `f5fe6511`.
- `delay(for: .seconds(3), scheduler: DispatchQueue.main)` → `RunLoop.main` until Styx is fixed.
  Reason: a defect of Styx's `DispatchQueue` scheduler at `f5fe6511`, which narrows nanoseconds to
  `Int`, 32 bits on armv7, and traps (measured, §4).
- `-Xfrontend -disable-availability-checking` to reach an API Styx does not ship → take the
  release's API. Reason: the skill `self-review` refuses it.
