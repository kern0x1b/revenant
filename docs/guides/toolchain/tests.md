# Run the toolchain's tests

The toolchain's tests are in `toolchain/tests/`, and they run at three levels: the fast suite that the repository's check runs, the suites of each part of the toolchain, and the differential and device tests of the backports. This guide says what runs where, and how the backports' own probes are used.

## The suites

| Run | What it runs |
| --- | --- |
| `./xmakew l tools/check.lua toolchain` | `tests/light.lua`: the addon's tests (`tests/addon/`), the archive test, and the corpus test. This is the check the repository runs for the toolchain. |
| `cd toolchain/tests/addon && xmake f -y && xmake test` | the addon's tests as their own xmake project. They build their fixtures with the same `ld64` and `ldid`, so a new machine needs `brew install xmake llvm` first. |
| `tests/gen/` | the generator's tests: `gen_test.lua`, `headers_test.lua`, `doc_test.lua`, and others, with fake declarations in `fake_decls.lua`. |
| `tests/emulate/` | the emulator's fixtures: a launchd fixture, an install fixture and the expected output of a run. |
| `tests/swiftui/` | a consumer of the SwiftUI package. |
| `tests/backports/host/run-all.sh` | the host tests of the backports: each one compares a backport with the host's own framework. See below. |
| `tests/backports/device/` | the device tests of the backports, each run on an emulated device. See below. |

The repository's own check for a change to a component is `./xmakew l tools/check.lua <component>` for each component the change touches; the rows above are what that check and the component's own tests run.

## The host tests

Each host test compiles the backports for macOS (UIKit ones through Mac Catalyst), with every class they define renamed, and compares the result with the system class on the same inputs. Most are a script, `host/<name>/run.sh`, and a few take arguments.

A test that stops linking is the worst kind, because it looks like cover. Each script runs under `set -eu`, so a missing framework or a renamed symbol ends it at its first `clang` call, before any check. From outside it looks exactly like a test nobody has run lately. So before trusting the tests, run:

    cd toolchain/tests/backports
    sh host/run-all.sh [--seconds N] [NAMES]

`run-all.sh` starts every script and asks one question of each: did it get past building itself? A script that fails without reaching a single check is reported `DEAD` with the last lines of its error. One still running when the clock runs out is alive, since a link that fails fails in seconds. One that ends with status 0 is alive because it got to its end. It says nothing about whether the checks pass; it exits non-zero if anything is dead. The scripts that take arguments, or that write expectations rather than checking, are named with the reason, not passed over.

Several host scripts write an expectations header under `device/` when they pass, and some rewrite it on every run (a header that holds freshly made UUIDs changes each time). Look at `git status` after `run-all.sh`.

## The device tests

The device tests run on an emulated iOS 6.0 device, `iPhone3,1`. Each is a port built with the rules: a `daemon` for a process of its own, or an application with its own `Info.plist` for code that creates UIKit objects. Build and run one as [the emulator guide](emulate.md#test-a-library) describes.

Two rules for the device tests come from the cases that broke:

- A test that creates UIKit objects is an application. A bare process has no `UIApplicationMain` behind it, and `UITextView`'s `initWithFrame:` traps with `SIGTRAP` there.
- Inside an application, schedule a later step with a timer or `performSelector:withObject:afterDelay:`. The main queue is serial, so a block queued with `dispatch_async` does not run while a running block spins a nested run loop. A test waiting on a library that answers on the main queue waits off the main queue, and off the main thread it sleeps or waits on a semaphore, never on `CFRunLoopRunInMode`, which returns at once on a thread whose run loop has no sources.

`device/shearprobe/PREDICTION.md` is read by that probe's `run.sh`. It holds the prediction the probe is checked against, and is kept for that reason.

## Tools for a release and an application

Three tools in `tests/backports/tools/` read what a release holds. They are run from `toolchain/`, with `REVENANT_ROOT` set to the checkout when they need it.

Check an armv7 application against a release, and sort what it imports into what the backports carry and what nothing does:

    REVENANT_ROOT=/path/to/revenant xmake l tests/backports/tools/check-app.lua \
        6.0 /path/to/band/folder /path/to/App /path/to/Other

The release is one that `~/.revenant/dyld` holds a cache of. The band folder holds `libFoundationBackports.dylib` and its siblings, from an installed `revenant@apple-backports` or the `bands/<release>` folder of its deb.

List a class's methods with the address of each implementation, and disassemble from an address, in a release's cache:

    xmake l tests/backports/tools/cache-methods.lua ~/.revenant/dyld/12.0/dyld_shared_cache_arm64 CoreLocation CLLocationManager
    xmake l tests/backports/tools/cache-disasm.lua  ~/.revenant/dyld/12.0/dyld_shared_cache_arm64 0x187d5acd8 300

They read the cache and the subcaches beside it through the toolchain's own reader.

## Known gaps

These are open, and a test for each does not yet exist:

- `AXNameFromColor` is not carried. The host answers a curated vocabulary of named colours with the nearest match, not with the components of a colour, so it needs a fit rather than a lookup, and the fit has not been done.
- The appintents-macros expansion test asserts nothing. `tests/Expansions.swift` is a hand-written reference expansion, and the harness that would assert it needs `SwiftSyntaxMacrosTestSupport`, which this machine's Command Line Tools do not have. Once the harness exists it must fail on a mutation of the accessor's setter: `set { _rating = self.init() }` in place of `set { _rating = newValue }`.
