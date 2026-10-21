# The toolchain's tests

The toolchain's tests are xmake tests. `toolchain/tests/xmake.lua` declares them as targets, which the top-level
`xmake.lua` includes on a host, and `./xmakew test -P .` runs them with the rest of the repository's tests. This
reference says what runs where.

## The targets

| Target | Tests | Needs | Declared |
| --- | --- | --- | --- |
| `toolchain_light` | 13 suites of `tests/addon/` that build nothing and need no package | the repository | always |
| `toolchain_packages` | 19 suites of `tests/addon/` that compile with `ld64`, `ldid`, `iphoneos-sdk` and `llvm` | the prebuilt packages, `REVENANT_PREBUILT=kern0x1b/revenant` | always |
| `toolchain_device` | `emulator_test` and `swift_test`, which also needs the `swift` package: the emulator's queue, and the dyld libraries of a held firmware release | an emulator image, and the firmware held under `~/.revenant/dyld` | only with `./xmakew f -P . --tests=device` |

The suites are the modules of `tests/addon/`, each one `failures(options)` that returns the failures it found. A test
prints each failure and fails. Run one target with `./xmakew test -P . 'toolchain_light/*'`, or one suite with
`./xmakew test -P . 'toolchain_light/descriptions_test'`.

`toolchain_device` is outside the default run by declaration: without `--tests=device` it is not in the project, so
`xmake test` does not see it. `swift_test` reads the system libraries of a firmware release held under
`~/.revenant/dyld`, and when they are not held it fails and names `xmake firmware --arch=<arch> fetch <release>`. Run
on this machine, which holds them, it passes. `emulator_test` runs its own xmake addon install and then a queue step that
runs the xmake task `queue`; the heavy job pool removed that task, so the step fails and names it, and the other checks
of the suite pass.

The suites that run only for the iPhone OS platform (`SwiftUITypeChecks`, `CombineGenerated`, and the WebKit host
tests behind `webkit_host_tests`) are declared by the platform, not by the default run; they belong to the components
that define them. The fixtures of `tests/emulate/` and `tests/swiftui/` are built for a device and are not xmake tests
yet.

## Known gaps

These are open, and a test for each does not yet exist:

- `AXNameFromColor` is not carried. The host answers a curated vocabulary of named colours with the nearest match, not with the components of a colour, so it needs a fit rather than a lookup, and the fit has not been done.
- The appintents-macros expansion test asserts nothing. `tests/Expansions.swift` is a hand-written reference expansion, and the harness that would assert it needs `SwiftSyntaxMacrosTestSupport`, which this machine's Command Line Tools do not have. Once the harness exists it must fail on a mutation of the accessor's setter: `set { _rating = self.init() }` in place of `set { _rating = newValue }`.
