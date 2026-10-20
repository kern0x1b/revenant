# Combine

**Combine for the platforms Apple's framework never reached: one `import Combine`, down to iOS 6, armv7.**

Combine is [OpenCombine], a source-level reimplementation of Apple's [Combine] framework, patched to vend a single
module named `Combine`. Code written against the system framework (`ObservableObject`, `@Published`, publishers,
subjects, schedulers, `Timer.publish`) builds and runs unchanged on legacy iOS (tested on iOS 6.1.3, armv7). It is the
reactive layer under [SwiftUI] in the legacy-iOS work of the [toolchain].

Combine is not a fork: the code is OpenCombine's, pinned at one upstream commit, and what is ours is the patch series in
`patches/`, applied by the `revenant@combine` recipe.

## Build and test

From the top of revenant:

```bash
./xmakew f -P . -p iphoneos -a armv7
./xmakew build -P . Combine
./xmakew build -P . CombineTests
./xmakew test -P . CombineGenerated
```

The build, the emulator run and the gyb check are in [build and test](../../docs/guides/combine/build-and-test.md).

## Layout

`xmake.lua` is the targets of this module, `patches/` the series the recipe applies, `tests/` the XCTest shim, the skip
list and the test daemon's control, and `tools/` the test discovery. The shape of the folder and the rules for changing
it are in [the contributor guide](../../docs/guides/combine/contributing.md).

## Documentation

| Document | About |
| --- | --- |
| [Features](../../docs/reference/combine/features.md) | what the module provides, and what it adds to OpenCombine |
| [Usage](../../docs/guides/combine/usage.md) | a short example |
| [How it works](../../docs/explanation/combine/how-it-works.md) | how OpenCombine is pinned, patched and built as one module |
| [Build and test](../../docs/guides/combine/build-and-test.md) | the targets, the test daemon and the emulator |
| [Contributor guide](../../docs/guides/combine/contributing.md) | the design, the rules and the traps |
| [Test results](../../docs/reference/combine/test-results.md) | the upstream suite's results on iOS 6.1.3 and the known limits |
| [Changelog](../../docs/reference/combine/changelog.md) | what changed, release by release |
| [Third-party notice](../../docs/reference/combine/third-party.md) | OpenCombine's MIT notice, which covers the code this module is built from |

## Trademarks

Combine, Swift, iOS and iPhone are trademarks of Apple Inc. They are used here nominatively, to say what this software is
and where it runs; there is no affiliation with or endorsement by Apple, and none of Apple's code or assets is included.

## License

MIT. OpenCombine's notice covers the code this module is built from; the terms of our patches are the same. See the
[third-party notice](../../docs/reference/combine/third-party.md).

Built with Claude (Anthropic). This project is developed with AI assistance, openly — see the commit history.

[OpenCombine]: https://github.com/OpenCombine/OpenCombine
[Combine]: https://developer.apple.com/documentation/combine
[toolchain]: https://github.com/kern0x1b/revenant/tree/main/toolchain
[SwiftUI]: https://github.com/kern0x1b/revenant/tree/main/frameworks/SwiftUI
