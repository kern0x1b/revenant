# Contributor guide

Orientation for anyone — human or AI — working on Combine. Read it before making
changes.

## 1. What this is

Combine is OpenCombine, a source reimplementation of Apple's Combine, patched to
vend a **single module named `Combine`**, so code written against the system
framework builds and runs where there is no system Combine: legacy iOS (down to
iOS 6.1.3, armv7). It is the reactive layer under [SwiftUI]'s SwiftUI on the
[toolchain] toolchain.

There is no copy of the code here. `toolchain/packages/frameworks/combine/xmake.lua` pins
OpenCombine at one commit and applies the series in `frameworks/Combine/patches/`; this
module holds the targets that build the patched tree inside revenant and run upstream's
tests against it.

### The one design decision

Apple ships Combine as one module. OpenCombine splits it into a core module plus
separate Dispatch and Foundation modules, and hides every Foundation/Dispatch
extension behind an `OCombine` disambiguation namespace so it could sit beside a
real Combine on newer OSes. **Combine targets platforms with no system Combine, so
it compiles the three as one `Combine` module and exposes the plain API**
(`Timer.publish`, `NotificationCenter.publisher`, `DispatchQueue` / `RunLoop` /
`OperationQueue` as `Scheduler`, `Timer.TimerPublisher`).

The merge of the folders is the build's, not the patches': the recipe installs
`Sources/OpenCombine` as `src/Combine`, `OpenCombineDispatch` as
`src/Combine/Schedulers`, `OpenCombineFoundation` as `src/Combine/Foundation`
less the helper files whose names the core's `Helpers` already has, and
`COpenCombineHelpers` as `src/CombineHelpers`. A patch never renames a file to
get there; it carries only the edits to the contents (the intra-module imports
and the `OCombine` namespaces go, the module qualifier is `Combine.`).

Consequences to respect:

- **`@Published` must not change a property's storage/layout**, and
  `objectWillChange` must fire **synchronously in `willSet`, before the write** —
  downstream (SwiftUI) relies on both. Don't "optimise" the `Published` storage.
- **Availability checking stays on** for the module. iOS 7-only calls (the
  `CFRunLoopTimer` tolerance in `Foundation/Helpers/Portability.swift`) sit
  behind `#available`, and `URLSession`'s publisher is marked iOS 7. Never
  paper over the check with `-disable-availability-checking`; only the tests
  compile with it off.
- **The C helper keeps upstream's name**, `COpenCombineHelpers`, and its
  `opencombine_*` symbols; the target that compiles it is `CombineHelpers`.

## 2. Layout

| Path | Holds |
| --- | --- |
| `xmake.lua` | `CombineHelpers` and `Combine` on the tree `revenant@combine` installs with `sources = true`; `CombineXCTest` and `CombineTests`, upstream's tests as a daemon; `CombineGenerated`, the gyb check |
| `patches/` | the series the recipe applies, one patch per file; their `sha256` digests are in the recipe |
| `tests/XCTest.swift` | the XCTest API shim the tests compile against (`XCT_SKIP`, `XCT_FILTER`, `xct-skip.txt`, `xct-resume.txt` at run time) |
| `tests/data/skip.txt` | the tests left out of the iOS 6 run, one `Class` or `Class.test` per line (see `docs/reference/combine/test-results.md`) |
| `tests/control` | the Debian control of the test daemon |
| `tools/discover.lua` | finds upstream's tests and writes the `main.swift` that runs them |
| `../../docs/` at the top of revenant | `guides/combine/` (this guide, build and test, usage), `reference/combine/` (features, changelog, test results, the third-party notice), `explanation/combine/` (how it works) |
| `../../toolchain/packages/frameworks/combine/` | the recipe: the pin of OpenCombine and the list of patches |

## 3. How to build, and how to check

- `./xmakew build -P . Combine` at the revenant top (configured with
  `./xmakew f -P . -p iphoneos -a armv7`) builds the module;
  `./xmakew build -P . CombineTests` the tests. Configured with `--emulate=y` as
  well, `./xmakew emulate -P . -d iPhone4,1 -r 6.1.3 install` and
  `./xmakew emulate -P . -d iPhone4,1 -r 6.1.3 run /usr/libexec/CombineTests` start
  them in the guest; the repository's skill `emulator` says how to use the emulator.
- `./xmakew test -P . CombineGenerated` expands each `*.swift.gyb` with Revenant's gyb
  (`toolchain/modules/gyb`) and checks the `GENERATED-*` file beside it.
- Outside revenant: `add_requires("revenant@combine")`, which compiles the module against
  `revenant@swift-runtime` with the runtime's compiler and flags.

### Changing the code

Work in a clone of OpenCombine at the pinned commit with the series applied
(`git am frameworks/Combine/patches/*.patch`), commit, and regenerate the
series with `git format-patch --zero-commit --no-renames` from the pinned
commit. Put the new `sha256` of each file in the recipe's `patches` list. A
change to a gyb template is followed by its expansion with Revenant's gyb, never
another one. Patches carry no comments of ours: why a change is made goes in the
patch's message.

## 4. Conventions

- **No personal data** in tracked files: no device addresses, hostnames,
  credentials, or absolute `/Users/<name>/…` paths. Use `$HOME`, placeholders,
  and a gitignored `device.env`.
- **Commits:** plain imperative subject, no type prefixes. Keep the
  writing agent's own `Co-Authored-By:` trailer — the work is openly AI-built.
- **Build artifacts are never committed.**

## 5. Traps

- A Swift `private` declaration's mangled name depends on the name of its file.
  A patch that moves declarations between files changes symbols; keep a file's
  name when its declarations stay.

## 6. Upstream

OpenCombine is at <https://github.com/OpenCombine/OpenCombine>. To take a newer
commit, move the pin in the recipe, rebuild the series on it and check the
targets and the tests. Do not re-add public product branding beyond what the
MIT license requires (the copyright notice in `docs/reference/combine/third-party.md`).

[toolchain]: https://github.com/kern0x1b/revenant/tree/main/toolchain
[SwiftUI]: https://github.com/kern0x1b/revenant/tree/main/frameworks/SwiftUI
