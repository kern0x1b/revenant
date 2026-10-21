# The toolchain

Builds applications and tweaks for legacy Apple platforms with [xmake](https://xmake.io): armv6 from iPhone OS 2.0 to 4.2.1, armv7 from 3.0, armv7s from iOS 6 and arm64 from iOS 7. The compiler is clang from the `llvm` package, so no Xcode is needed. The toolchain is an xmake addon, `revenant`, with the `apple-ios` toolchain, target rules, checks and verbs, and a package repository with the SDK, linker, signer, runtimes and shared libraries.

## In three commands

    xmake                                   # build a port; every binary is checked as it links
    xmake deb                               # package it as a .deb
    ./xmakew test -P . 'toolchain_*/*'      # test the toolchain, from the repository root

## Documentation

- Writing a port: [tutorials/toolchain/port.md](../docs/tutorials/toolchain/port.md), and [writing a package](../docs/guides/toolchain/packages.md)
- Running on an emulated device: [guides/toolchain/emulate.md](../docs/guides/toolchain/emulate.md)
- Tests and contributing: [tests](../docs/reference/toolchain/tests.md), [contributing](../docs/guides/toolchain/contributing.md)
- Rules, values and checks: [reference/toolchain/rules.md](../docs/reference/toolchain/rules.md)
- Commands and environment: [reference/toolchain/commands.md](../docs/reference/toolchain/commands.md)
- Packages and versions: [reference/toolchain/packages.md](../docs/reference/toolchain/packages.md)
- Developer tools: [reference/toolchain/tools.md](../docs/reference/toolchain/tools.md)
- Changelog and third-party licences: [changelog](../docs/reference/toolchain/changelog.md), [third-party](../docs/reference/toolchain/third-party.md)
- Why it is built this way: [explanation/toolchain/design.md](../docs/explanation/toolchain/design.md), [runtimes and backports](../docs/explanation/toolchain/runtimes.md)
