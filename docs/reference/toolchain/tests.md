# The toolchain's tests

The toolchain's tests are xmake tests. `toolchain/tests/xmake.lua` declares them as targets, which the top-level
`xmake.lua` includes on a host, and `./xmakew test -P .` runs them with the rest of the repository's tests. This
reference says what runs where.

## The targets

| Target | Tests | Needs | Declared |
| --- | --- | --- | --- |
| `toolchain_light` | 13 suites of `tests/addon/` that build nothing and need no package | the repository | always |
| `toolchain_packages` | 16 suites of `tests/addon/` that compile with `ld64`, `ldid`, `iphoneos-sdk` and `llvm` | the prebuilt packages, `REVENANT_PREBUILT=kern0x1b/revenant` | always |
| `toolchain_device` | `callkit_screen_test`, `port_test` and `tweak_test`, which build against the iOS 6 libraries of a firmware release; `emulator_test`, which runs the emulator's queue; `swift_test`, which also needs the `swift` package and the dyld libraries of a held release; the recompiler's `classpair` and `ordinal` checks (`recompiler_device`), which read the iOS 6 dyld cache; `compat_device_test`, the dispatch_block probes and the default global queue's class in `compat/device/`, which answer as iOS only on a device or an emulator | the firmware catalog and the firmware held under `~/.revenant/dyld`, an emulator image | only with `./xmakew f -P . --tests=device` |

The suites are the modules of `tests/addon/`, each one `failures(options)` that returns the failures it found. A test
prints each failure and fails. Run one target with `./xmakew test -P . 'toolchain_light/*'`, or one suite with
`./xmakew test -P . 'toolchain_light/descriptions_test'`.

`toolchain_device` is outside the default run by declaration: without `--tests=device` it is not in the project, so
`xmake test` does not see it. `swift_test` reads the system libraries of a firmware release held under
`~/.revenant/dyld`, and when they are not held it fails and names `xmake firmware --arch=<arch> fetch <release>`. Run
on this machine, which holds them, it passes. `emulator_test` runs its own xmake addon install and then a queue step that
runs the xmake task `queue`; the heavy job pool removed that task, so the step fails and names it, and the other checks
of the suite pass.

`macho_test` builds its encrypted armv7 image with the packaged ld64 and the packaged iPhone OS SDK, and adds the
`LC_ENCRYPTION_INFO` command itself, in the header's padding, as the system linker of older Xcode versions writes it:
the packaged ld64 writes no such command for armv7, and some Xcode linkers write none either. The reader and otool are
checked against the image in the default run.

The compat checks assert the values the SDK documents. Where the SDK says nothing fixed, or where only this host's
libdispatch answers, the check is in the device group: `compat_device_test` and the probes in `compat/device/`.

The suites that run only for the iPhone OS platform (`SwiftUITypeChecks`, `CombineGenerated`, and the WebKit host
tests behind `webkit_host_tests`) are declared by the platform, not by the default run; they belong to the components
that define them. The fixtures of `tests/emulate/` and `tests/swiftui/` are built for a device and are not xmake tests
yet. Each `tests/emulate/<case>/` runs with `./xmakew l toolchain/tests/emulate/<case>/<case>.lua [DEVICE] [RELEASE]`:
`install` (the install places the build's program in the image), `launchd` (the program runs under launchd and prints
its probe line), and `output` (a program's stdout and stderr reach the host, through a run that ends and through one
that hangs). Their scratch folders are `$HOME/.revenant/cache/<task>/emulate-<case>/`, where `<task>` is the checkout's folder.

## Known gaps

These are open, and a test for each does not yet exist:

- `AXNameFromColor` is not carried. The host answers a curated vocabulary of named colours with the nearest match, not with the components of a colour, so it needs a fit rather than a lookup, and the fit has not been done.
- The appintents-macros expansion test asserts nothing. `frameworks/Backports/tests/AppIntentsMacros/Expansions.swift` is a hand-written reference expansion, and the harness that would assert it needs `SwiftSyntaxMacrosTestSupport`, which this machine's Command Line Tools do not have. Once the harness exists it must fail on a mutation of the accessor's setter: `set { _rating = self.init() }` in place of `set { _rating = newValue }`.
