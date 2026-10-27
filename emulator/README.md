# The emulator

**Revenant's emulator for legacy iPhone OS and iOS userlands, on macOS arm64.**

The emulator boots a firmware's own userland (launchd, the daemons, SpringBoard and the applications) over an emulated XNU kernel, on a JIT-translated ARM CPU ([Dynarmic](https://github.com/MC-XiaoXiao/dynarmic), with our patches). Software built for old iPhones, iPods and iPads can be started and tested on a Mac before it goes to a device.

## Build and test

From the top of revenant:

```sh
./xmakew f -P . -y -m release --component=emulator
./xmakew build -P . emulator
./xmakew test -P .
```

Requirements, options and how to boot a root filesystem are in [build, run and test](../docs/guides/emulator/build-and-test.md). Every document is listed in [the documentation index](../docs/README.md).

## License

MPL-2.0. The licence text is `LICENSES/MPL-2.0.txt`, and [the notice](../docs/reference/emulator/notice.md) holds the notices to ship with a binary.

Built with Claude (Anthropic). This project is developed with AI assistance, openly; see the commit history.
