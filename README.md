# Styx

**Combine for the platforms Apple's framework never reached — one `import Combine`, down to iOS 6, armv7.**

Styx is a source-level reimplementation of Apple's [Combine] reactive
framework. It vends a single module named `Combine`, so code written against the
system framework — `ObservableObject`, `@Published`, publishers, subjects,
schedulers, `Timer.publish`, `NotificationCenter.publisher` — builds and runs
unchanged on systems that have no Combine of their own: legacy iOS (tested on
iOS 6.1.3, armv7), Linux, and WASI. It is built for the [Charon] toolchain's
legacy-iOS work, where it is the reactive layer under [Eidolon]'s SwiftUI.

## What it does

- **One module, Apple's shape.** `import Combine` alone brings the core
  (`Publisher`, `Subscriber`, `Subject`, `AnyCancellable`, operators),
  `ObservableObject`/`@Published`/`ObservableObjectPublisher`, the
  `Timer.publish` / `NotificationCenter.publisher` Foundation integration, and
  `DispatchQueue` / `RunLoop` / `OperationQueue` as `Scheduler`s — with the
  natural spellings (`Timer.TimerPublisher`, `dispatchQueue` as a scheduler), no
  disambiguation namespace.
- **Runs where Combine does not exist.** No dependency on any system Combine;
  verified on an iPhone 4S and an iPad 2 (iOS 6.1.3) and in emulation.
- **Availability-honest on old iOS.** iOS 7-only calls (the `CFRunLoopTimer`
  tolerance) sit behind `#available`, so the module compiles and runs correctly
  at a 6.0 deployment target with availability checking on.

### What is not included

- **URLSession publishers** (`dataTaskPublisher`) — not implemented yet. The
  Combine spec (`charon/packages/a/apple-backports/spec/Combine/swift.tsv`) has no
  rows for them, and `URLSession` is iOS 7+, so on iOS 6.1.3 they depend on the
  URLSession that `charon@apple-backports` carries. How this module reaches that
  class is still to be decided.
- The `Optional` and `Result` publishers are declared under an `OCombine`
  namespace (`Optional.OCombine.Publisher`, `Result.OCombine.Publisher`), and
  `Optional.Publisher` and `Result.Publisher` are typealiases of it. The names a
  caller writes are the ones Apple declares; the declared path differs.

## How it works

Apple ships Combine as a single framework. This fork's upstream split its
sources into a core module plus separate Dispatch and Foundation modules, and
guarded every Foundation/Dispatch extension behind a disambiguation namespace so
it could coexist with a real Combine on newer OSes. On the platforms Styx
targets there is no system Combine, so that split is only friction: Styx folds
everything into one `Combine` module and exposes the plain API. The one C++
translation unit that backs the locking primitives is compiled as a small helper
library the module links.

## Requirements

- A Swift toolchain and, for the legacy-iOS build, the [Charon] toolchain with
  its Swift runtime packages installed. Styx is consumed there as the
  `charon@styx` package.
- For SwiftPM use on a platform without a system Combine (Linux, WASI): a recent
  Swift toolchain. On Apple platforms the system `Combine` shadows this module,
  so SwiftPM builds of it are meant for the no-Combine platforms.

## Build

With SwiftPM, where no system Combine shadows the module:

```bash
swift build
```

For the legacy-iOS (armv7) build, take it through Charon as a package
dependency:

```lua
add_requires("charon@styx", {alias = "combine"})
add_packages("combine")
```

## Usage

```swift
import Combine

final class Counter: ObservableObject {
    @Published var value = 0
}

let counter = Counter()
var bag = Set<AnyCancellable>()

counter.objectWillChange
    .sink { _ in print("will change") }
    .store(in: &bag)

Timer.publish(every: 1, on: .main, in: .common)
    .autoconnect()
    .sink { _ in counter.value += 1 }
    .store(in: &bag)
```

## Repository layout

| Path | Holds |
| --- | --- |
| `Sources/Combine/` | the module: core, `Schedulers/`, `Foundation/` |
| `Sources/COpenCombineHelpers/` | the C++ helper the module links (locking) |
| `Tests/` | the regression suite (runs where no system Combine shadows it) |
| `Package.swift` | the SwiftPM manifest |
| `utils/` | source-generation helpers (`gyb`) |

## Documentation

| Document | About |
| --- | --- |
| [`docs/TEST-RESULTS.md`](docs/TEST-RESULTS.md) | on-device/emulator test results and the documented limitations |
| [`AGENTS.md`](AGENTS.md) | the contributor guide — design, build, gotchas |

## Trademarks

Combine, Swift, iOS and iPhone are trademarks of Apple Inc. They are used here
nominatively, to say what this software is and where it runs; there is no
affiliation with or endorsement by Apple, and none of Apple's code or assets is
included.

## License

MIT, see [`LICENSE`](LICENSE). The MIT copyright notice is retained there as the
license requires. Nothing third-party is vendored.

Built with Claude (Anthropic). This project is developed with AI assistance,
openly — see the commit history.

[Combine]: https://developer.apple.com/documentation/combine
[Charon]: https://github.com/kern0x1b/charon
[Eidolon]: https://github.com/kern0x1b/eidolon
