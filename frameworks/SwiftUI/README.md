# SwiftUI

**SwiftUI for iOS 6 — a from-scratch implementation of the SwiftUI API on UIKit, for armv7.**

It is a Swift module named `SwiftUI`, built on the UIKit of iOS 6, with [Combine](https://github.com/kern0x1b/revenant/tree/main/frameworks/Combine), a Combine for iOS 6, standing in for Apple's Combine. An app written in ordinary SwiftUI syntax compiles against it and comes out as a native-looking iOS 6 app on a phone from 2011. Why Apple's framework cannot run there, and how this one is built, is in [how it works](../../docs/explanation/swiftui/how-it-works.md).

## Build and test

From the top of revenant:

```bash
./xmakew f -P . -p iphoneos -a armv7 -y
./xmakew build -P . SwiftUI SwiftUIDemo SwiftUISnapshots SwiftUITests
./xmakew test -P . SwiftUITypeChecks/*
./xmakew l frameworks/SwiftUI/tools/emulate.lua tests
./xmakew l frameworks/SwiftUI/tools/emulate.lua snapshots
```

The requirements, the tools and the checks that gate a change are in [build, run and test](../../docs/guides/swiftui/build-and-test.md).

## Layout

`src/` is the module, `examples/showcase/` the demo application, `tests/` the engine tests, the probe, the typechecks, the macOS oracles, the interface walker and the data they read, and `tools/` the Lua scripts. The shape of the folder is [the contributor guide](../../docs/guides/swiftui/contributing.md).

## Documentation

| Document | About |
| --- | --- |
| [Features](../../docs/reference/swiftui/features.md) | the areas of the API that are implemented |
| [Completeness](../../docs/reference/swiftui/completeness.md) | how much of Apple's interface is present, measured two ways |
| [On a phone](../../docs/reference/swiftui/on-device.md) | the demo's screens, drawn on an iPhone 4S |
| [How it works](../../docs/explanation/swiftui/how-it-works.md) | why the module is built as it is, and its design |
| [Build, run and test](../../docs/guides/swiftui/build-and-test.md) | requirements, the build, the tools and the emulator |
| [Contributor guide](../../docs/guides/swiftui/contributing.md) | the layout, the rules that matter, the test limits |
| [Ledger](../../docs/reference/swiftui/ledger.md) | what is implemented, ignored, simplified or missing (in Russian) |
| [Research](../../docs/explanation/swiftui/research.md) | why Apple's SwiftUI cannot be ported (in Russian) |
| [Guest bridge](../../docs/explanation/swiftui/guest-bridge.md) | the sample app and the slot table of the guest build |
| [Surface](../../docs/reference/swiftui/surface.md) | the interface walker and the surface files the gaps are read from |
| [Host probes](../../docs/reference/swiftui/host.md) | values measured from Apple's framework on the host |
| [Builder typechecks](../../docs/reference/swiftui/typechecks.md) | the snippets the Table and TabContent builders must accept or refuse |
| [Changelog](../../docs/reference/swiftui/changelog.md) | what changed, release by release |
| [Third-party](../../docs/reference/swiftui/third-party.md) | the code this module is derived from, and its terms |
| [Combine's test results](../../docs/reference/combine/test-results.md) | OpenCombine's own tests against the Combine this module re-exports |

## Trademarks

SwiftUI, UIKit, Combine, iOS and iPhone are trademarks of Apple Inc. They are used here nominatively, to say what this project is compatible with. There is no affiliation. This repository contains no code or assets of Apple's.

## License

MIT. `LICENSES/MIT.txt` and `REUSE.toml` cover this folder; nothing third-party is vendored.

Built with Claude (Anthropic). This project is developed with AI assistance, openly — see the commit history.
