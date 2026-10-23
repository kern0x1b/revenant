# SwiftUI

**SwiftUI for iOS 6 — a from-scratch implementation of the SwiftUI API on UIKit, for armv7.**

It is a Swift module named `SwiftUI`, built on the UIKit of iOS 6, with [Combine](https://github.com/kern0x1b/revenant/tree/main/frameworks/Combine), a Combine for iOS 6, standing in for Apple's Combine. An app written in ordinary SwiftUI syntax compiles against it and comes out as a native-looking iOS 6 app on a phone from 2011. Why Apple's framework cannot run there, and how this one is built, is in [how it works](../../docs/explanation/swiftui/how-it-works.md).

## Build and test

From the top of revenant:

```bash
./xmakew f -P . -p iphoneos -a armv7 -y
./xmakew build -P . SwiftUI SwiftUIDemo SwiftUISnapshots SwiftUITests
./xmakew test -P . SwiftUITypeChecks/*
./xmakew l -P . frameworks/SwiftUI/tools/emulate.lua tests
./xmakew l -P . frameworks/SwiftUI/tools/emulate.lua snapshots
```

The requirements, the tools and the checks that gate a change are in [build, run and test](../../docs/guides/swiftui/build-and-test.md). The layout is in the [contributor guide](../../docs/guides/swiftui/contributing.md), and every document is in [the index](../../docs/README.md).

## License

MIT. `LICENSES/MIT.txt` and `REUSE.toml` cover this folder; the two files taken from OpenSwiftUI are MIT too, under Kyle-Ye's copyright, as `REUSE.toml` records.

Built with Claude (Anthropic). This project is developed with AI assistance, openly — see the commit history.
