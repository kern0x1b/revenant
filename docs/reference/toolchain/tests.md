# The toolchain's tests

The toolchain's tests are in `toolchain/tests/`, and they run at two levels: the fast suite that the repository's check runs, and the suites of each part of the toolchain. This reference says what runs where.

## The suites

| Run | What it runs |
| --- | --- |
| `./xmakew l tools/check.lua toolchain` | `tests/light.lua`: the addon's tests (`tests/addon/`), the archive test, and the corpus test. This is the check the repository runs for the toolchain. |
| `cd toolchain/tests/addon && xmake f -y && xmake test` | the addon's tests as their own xmake project. They build their fixtures with the same `ld64` and `ldid`, so a new machine needs `brew install xmake llvm` first. |
| `tests/gen/` | the generator's tests: `gen_test.lua`, `headers_test.lua`, `doc_test.lua`, and others, with fake declarations in `fake_decls.lua`. |
| `tests/emulate/` | the emulator's fixtures: a launchd fixture, an install fixture and the expected output of a run. |
| `tests/swiftui/` | a consumer of the SwiftUI package. |
| `tests/common/` | `runs.sh`, which the emulator and SwiftUI scripts source for their scratch folder. |

The repository's own check for a change to a component is `./xmakew l tools/check.lua <component>` for each component the change touches; the rows above are what that check and the component's own tests run.

## Known gaps

These are open, and a test for each does not yet exist:

- `AXNameFromColor` is not carried. The host answers a curated vocabulary of named colours with the nearest match, not with the components of a colour, so it needs a fit rather than a lookup, and the fit has not been done.
- The appintents-macros expansion test asserts nothing. `tests/Expansions.swift` is a hand-written reference expansion, and the harness that would assert it needs `SwiftSyntaxMacrosTestSupport`, which this machine's Command Line Tools do not have. Once the harness exists it must fail on a mutation of the accessor's setter: `set { _rating = self.init() }` in place of `set { _rating = newValue }`.
