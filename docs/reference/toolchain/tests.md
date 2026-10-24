# The toolchain's tests

The toolchain's tests are xmake tests. `toolchain/tests/xmake.lua` declares them as targets, which the top-level
`xmake.lua` includes on a host, and `./xmakew test -P .` runs them with the rest of the repository's tests. This
reference says what runs where.

## The targets

| Target | Tests | Needs | Declared |
| --- | --- | --- | --- |
| `toolchain_light` | 17 suites of `tests/addon/` that need no package builds | the repository | always |
| `toolchain_packages` | 19 suites of `tests/addon/` that compile with `ld64`, `ldid`, `iphoneos-sdk` and `llvm` | the prebuilt packages, `REVENANT_PREBUILT=kern0x1b/revenant` | always |
| `toolchain_device` | six suites: `callkit_screen_test`, `compat_device_test`, `emulator_test`, `port_test`, `swift_test` and `tweak_test` | the packages, firmware data and device or emulator state each suite needs | only with `./xmakew f -P . --tests=device` |
| `recompiler_corpus` | the six host suites `jumptable`, `tsdscan`, `tsdguard`, `int128`, `weakimport` and `lse` | the prebuilt packages | always |
| `recompiler_device` | `classpair` and `ordinal` | the prebuilt packages and a claimed device | only with `./xmakew f -P . --tests=device` |
| `bench` | five workloads of `tests/bench/workloads/` (`msgsend`, `alloc`, `collections`, `strings` and the C `compute`, a package-style kernel of CRC-32, FNV-1a and a matrix product), run as the first process of an iPhone 4S boot of iOS 6.1.3 under the emulator; each one fails when its guest instructions, the calls to its own methods or its resident memory grow beyond the tolerance in `tests/data/bench/baselines.json` | the packages, the emulator built by `./xmakew build -P . emulator`, and the root filesystem from `./xmakew firmware -P . --device=iPhone4,1 rootfs 6.1.3` | only with `./xmakew f -P . --tests=device` |

The `bench` tests measure what the emulator counts: guest instructions are its CPU ticks for the boot, and a call count is the number of runs of the entry block of a method, which the block profile reports for the top 30 blocks of a run. A count is never a time. `REVENANT_BENCH_RECORD=1` records the baselines of the workloads that run, and `REVENANT_BENCH_REPORT=1` prints the counts, the resident size and the size of each binary without comparing them, which is how a compiler setting is measured. `REVENANT_BENCH_FLAGS` replaces the compiler flags of the workloads (default `-Os`).

Each toolchain suite is a module of `tests/addon/` with `failures(options)`, which returns the failures it found. A test
prints each failure and fails. Run one target with `./xmakew test -P . 'toolchain_light/*'`, or one suite with
`./xmakew test -P . 'toolchain_light/descriptions_test'`.

`toolchain_device` and `recompiler_device` are outside the default run by declaration: without `--tests=device` they
are not in the project, so `./xmakew test -P .` does not see them. `swift_test` reads the system libraries of a firmware
release held under `~/.revenant/dyld`, and when they are not held it fails and names
`./xmakew firmware -P . --arch=<arch> fetch <release>`. `emulator_test` runs its own xmake addon install and then a queue step that
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
yet. Each `tests/emulate/<case>/` runs with `./xmakew l -P . toolchain/tests/emulate/<case>/<case>.lua [DEVICE] [RELEASE]`:
`install` (the install places the build's program in the image), `launchd` (the program runs under launchd and prints
its probe line), and `output` (a program's stdout and stderr reach the host, through a run that ends and through one
that hangs). Their scratch folders are `$HOME/.revenant/cache/<task>/emulate-<case>/`, where `<task>` is the checkout's folder.

`optimisation_test` compiles `tests/data/optimisation/codegen.c` with the packaged clang for armv7 and reads the assembly of
each function. It pins the code-generation misses that [the optimisation explanation](../../explanation/toolchain/optimisation.md#codegen)
names: a case that still shows its miss passes, and the day the miss is gone the suite fails and names the case, so the
case moves to the controls with the patch that fixed it. The controls are the same code where the backend already does
the job, which shows the miss is in the backend's choice and not in the code's shape.

## Known gaps

These are open, and a test for each does not yet exist:

- `AXNameFromColor` is not carried. The host answers a curated vocabulary of named colours with the nearest match, not with the components of a colour, so it needs a fit rather than a lookup, and the fit has not been done.
- The AppIntentsMacros expansion check asserts nothing. Its package does not exist yet ([AppIntentsMacros](../backports/AppIntentsMacros/README.md)). `frameworks/Backports/tests/AppIntentsMacros/Expansions.swift` is a hand-written reference expansion, and the harness that would assert it needs `SwiftSyntaxMacrosTestSupport`, which this machine's Command Line Tools do not have. Once the harness exists it must fail on a mutation of the accessor's setter: `set { _rating = self.init() }` in place of `set { _rating = newValue }`.
