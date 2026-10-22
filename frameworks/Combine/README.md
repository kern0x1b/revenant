# Combine

**Combine for the platforms Apple's framework never reached: one `import Combine`, down to iOS 6, armv7.**

Combine is [OpenCombine], a source-level reimplementation of Apple's [Combine] framework, patched to vend a single module named `Combine`. Code written against the system framework (`ObservableObject`, `@Published`, publishers, subjects, schedulers, `Timer.publish`) builds and runs unchanged on legacy iOS (tested on iOS 6.1.3, armv7). It is the reactive layer under [SwiftUI](../SwiftUI) in the legacy-iOS work of the [toolchain](../../toolchain). Combine is not a fork: the code is OpenCombine's, pinned at one upstream commit, and what is ours is the patch series in `packages/c/combine/patches/`, applied by the `revenant@combine` recipe.

## Build and test

From the top of revenant:

```bash
./xmakew f -P . -p iphoneos -a armv7
./xmakew build -P . CombineTests
./xmakew test -P . CombineGenerated
```

The build, the emulator run and the gyb check are in [build and test](../../docs/guides/combine/build-and-test.md). The folder's layout is in the [contributor guide](../../docs/guides/combine/contributing.md), and every document is in [the index](../../docs/README.md).

## License

MIT. OpenCombine's notice covers the code this module is built from; the terms of our patches are the same. See the [third-party notice](../../docs/reference/combine/third-party.md).

Built with Claude (Anthropic). This project is developed with AI assistance, openly; see the commit history.

[OpenCombine]: https://github.com/OpenCombine/OpenCombine
[Combine]: https://developer.apple.com/documentation/combine
