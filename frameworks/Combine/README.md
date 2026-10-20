# Combine

**Combine for the platforms Apple's framework never reached — one `import Combine`, down to iOS 6, armv7.**

Combine is [OpenCombine], a source-level reimplementation of Apple's [Combine]
reactive framework, with a short series of patches that make it vend a single
module named `Combine`, so code written against the system framework —
`ObservableObject`, `@Published`, publishers, subjects, schedulers,
`Timer.publish`, `NotificationCenter.publisher` — builds and runs unchanged on
systems that have no Combine of their own: legacy iOS (tested on iOS 6.1.3,
armv7). It is built for the legacy-iOS work of the [toolchain], where it is
the reactive layer under [SwiftUI].

Combine is not a fork. The code is OpenCombine's, pinned at one upstream commit;
what is ours is the patch series in `toolchain/packages/c/combine/patches/`, applied by
the `revenant@combine` recipe, and the targets in this folder that build the patched
sources inside revenant.

## What it does

- **One module, Apple's shape.** `import Combine` alone brings the core
  (`Publisher`, `Subscriber`, `Subject`, `AnyCancellable`, operators),
  `ObservableObject`/`@Published`/`ObservableObjectPublisher`, the
  `Timer.publish` / `NotificationCenter.publisher` Foundation integration, and
  `DispatchQueue` / `RunLoop` / `OperationQueue` as `Scheduler`s — with the
  natural spellings (`Timer.TimerPublisher`, `Optional.Publisher`,
  `Result.Publisher`), no disambiguation namespace.
- **What OpenCombine lacks, Apple declares.** `Publishers.Merge` through
  `Merge8` and `MergeMany`, `Publishers.CombineLatest` through `CombineLatest4`,
  `Publishers.CollectByTime` with `collect(_:options:)`, and the equality and
  hashing Apple's interface declares in the open.
- **Runs where Combine does not exist.** No dependency on any system Combine;
  verified on an iPhone 4S and an iPad 2 (iOS 6.1.3) and in emulation.
- **Availability-honest on old iOS.** iOS 7-only API (the `CFRunLoopTimer`
  tolerance, `URLSession.dataTaskPublisher`) sits behind `#available` or is
  marked iOS 7, so the module compiles at a 6.0 deployment target with
  availability checking on.

## How it works

The `revenant@combine` recipe fetches OpenCombine at its pinned commit and applies
the patches in order. The patches carry only content edits. Putting the three
upstream modules together is the build's work: the recipe installs the patched
sources as one tree, `src/Combine` holding `Sources/OpenCombine` with
`OpenCombineDispatch` under `Schedulers/` and `OpenCombineFoundation` under
`Foundation/` (less the helper files the core already has under the same name),
`src/CombineHelpers` holding the C++ helper `COpenCombineHelpers`, `src/Tests`
holding upstream's tests and `src/utils` the header of its gyb templates.

There are two ways to take it:

- `revenant@combine` as it is: the recipe compiles that tree against
  `revenant@swift-runtime` and installs `libCombine.a`, `libCombineHelpers.a` and
  the `Combine` module.
- `revenant@combine` with `sources = true`: the recipe installs only the tree, and
  the project compiles it. This is what revenant does.

## Build

Inside revenant, `xmake.lua` requires `revenant@combine` with `sources = true` and makes
two targets of the revenant project for iOS (`./xmakew f -P . -p iphoneos -a armv7` at
the revenant top) from the installed tree: `Combine`, the one module, and
`CombineHelpers`, the C++ helper it imports. A target of another member links it
with `add_deps("Combine")`.

Outside revenant, the legacy-iOS (armv7) build is taken through the toolchain as a
package dependency:

```lua
add_requires("revenant@combine", {alias = "combine"})
add_packages("combine")
```

## Test

`./xmakew build -P . CombineTests` compiles upstream's `Tests/OpenCombineTests`
against the module as one daemon, with the XCTest shim of `Tests/XCTest.swift`;
the test list is found by `tools/discover.lua` and leaves out what
`Tests/skip.txt` names. With the project configured `--emulate=y`,
`./xmakew emulate -P . -d iPhone4,1 -r 6.1.3 install` and
`./xmakew emulate -P . -d iPhone4,1 -r 6.1.3 run /usr/libexec/CombineTests` start it
in the guest (skill `emulate-port`), and its exit status is the verdict.
`./xmakew test -P . CombineGenerated` expands each gyb
template with Revenant's gyb (`toolchain/modules/gyb`) and checks the `GENERATED-*`
source beside it is that expansion byte for byte.

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
| `xmake.lua` | the `Combine` and `CombineHelpers` targets on the patched tree, `CombineTests` and its `CombineXCTest` shim, and `CombineGenerated`, the gyb check |
| `Tests/` | the XCTest shim, the skip list and the Debian control of the test daemon |
| `tools/` | the test discovery, which writes the `main.swift` that runs upstream's tests |
| `docs/` | the test results |
| `../../toolchain/packages/c/combine/` | the recipe and the patch series |

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

MIT, see [`LICENSE`](LICENSE): OpenCombine's notice, which the code it covers
carries wherever it ships, and the terms of our patches.

Built with Claude (Anthropic). This project is developed with AI assistance,
openly — see the commit history.

[OpenCombine]: https://github.com/OpenCombine/OpenCombine
[Combine]: https://developer.apple.com/documentation/combine
[toolchain]: https://github.com/kern0x1b/revenant/tree/main/toolchain
[SwiftUI]: https://github.com/kern0x1b/revenant/tree/main/frameworks/SwiftUI
