# The emulator

**Revenant's emulator for legacy iPhone OS and iOS userlands, on macOS arm64.**

The emulator boots a firmware's own userland (launchd, the daemons, SpringBoard and the applications) over an
emulated XNU kernel, on a JIT-translated ARM CPU ([Dynarmic](https://github.com/MC-XiaoXiao/dynarmic), with our
patches). Software built for old iPhones, iPods and iPads can be started and tested on a Mac before it goes to a
device.

## Build

From the top of revenant:

```sh
./xmakew f -y
./xmakew build emulator
./xmakew test
```

The requirements, the options and how to boot a root filesystem are in
[build and run](../docs/guides/emulator/build-and-run.md).

## Documentation

| Document | About |
| --- | --- |
| [Build and run](../docs/guides/emulator/build-and-run.md) | requirements, options, boot and usage |
| [Contributor guide](../docs/guides/emulator/contributing.md) | the layout, what bites, the conventions |
| [How it works](../docs/explanation/emulator/how-it-works.md) | what is emulated and how the pieces fit |
| [Performance](../docs/explanation/emulator/performance.md) | where the time goes, and why not another emulator |
| [Shared translation](../docs/explanation/emulator/shared-translation.md) | the design for translating the shared cache once |
| [iOS 6.1.3](../docs/explanation/emulator/ios-6.1.3.md) | what kept 6.1.3 from booting, and what fixed it |
| [Control surface](../docs/reference/emulator/control-surface.md) | the `--control-stdin` commands and the log lines |
| [Guest tests](../docs/reference/emulator/guest-tests.md) | the guest programs that check what only a running guest shows |
| [Changelog](../docs/reference/emulator/changelog.md) | what changed, release by release |
| [Third-party](../docs/reference/emulator/third-party.md) | what is bundled or linked, and under which license |

## License

MPL-2.0. The licence text is `LICENSES/MPL-2.0.txt`, and `docs/reference/emulator/NOTICE` the notices to ship with a binary.

Built with Claude (Anthropic). This project is developed with AI assistance, openly; see the commit history.
