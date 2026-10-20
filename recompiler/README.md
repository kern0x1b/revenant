# The recompiler

**A static binary recompiler: a compiled 64-bit (arm64) iOS application in, a 32-bit (armv7) binary that runs on iOS 6 out, without source and without rewriting the app.**

It lifts each arm64 function to LLVM IR (via [Rellume](https://github.com/aengelke/rellume)), rewrites the Objective-C metadata and data segments for the 32-bit runtime, re-emits the code as armv7, and links it against a small support runtime plus generated ABI bridges. The result is an ordinary armv7 Mach-O that a real iOS 6 device, or an emulator, loads and runs as a normal app.

This is a research prototype, not a product. It takes a real 64-bit App Store application to a live, interactive screen on iOS 6: OneBusAway 2.3.2, with no app-specific rules.

## Build

From the top of revenant:

```sh
./xmakew f -y
./xmakew build xlate xlgen
```

Then translate an arm64 executable, as [build and translate](../docs/guides/recompiler/build-and-translate.md) describes. Every document is in [the index](../docs/README.md).

## License

MIT. `LICENSES/MIT.txt` and `REUSE.toml` cover this folder.
