# Build, run and test SwiftUI

## Requirements

- macOS and the revenant checkout this folder is in, configured for iOS at its top (revenant's README, "One xmake
  project"): the module is the `SwiftUI` target, Combine is the package `combine`, and
  `swift-runtime`, `libcxx`, the iOS SDK and the tools are packages the project requires. The `frameworks/Backports`
  targets are the project's own. An app outside revenant does not take SwiftUI from a recipe any more; see
  [the architecture](../../explanation/architecture.md) for the packages `xmake package` writes for our targets.
- To run the tests and rendered scenarios: revenant's emulator, which `./xmakew emulate -P .` drives once the project is
  configured with `--emulate=y`. `frameworks/SwiftUI/tools/emulate.lua` does that configure itself; use the emulator the way the
  repository's skill `emulator-session` says.
- To measure on hardware: an iPhone 4S or an iPad 2 on iOS 6.1.3, claimed with `./xmakew device -P .` (skill
  `device-session`).

Run output (logs, pictures, API dumps, the copy of Apple's framework) goes under `$HOME/.revenant/cache/<task>/swiftui/`,
never into the tree; `toolchain/modules/workspace.lua` names the task and the iOS 26.2 SDK the tools read.

## Build

From the top of revenant:

```bash
./xmakew f -P . -p iphoneos -a armv7 -y
./xmakew build -P . SwiftUI SwiftUIDemo SwiftUISnapshots SwiftUITests
./xmakew test -P . SwiftUITypeChecks/*                 # the Table and TabContent builders accept and refuse what Apple's do
```

Building `SwiftUI` begins with `frameworks/SwiftUI/tools/coverage.lua --check --before-build`, which refuses to continue if
the ledger and the code disagree. The count of invented names is not part of that: it is read from the `invented.txt`
that `frameworks/SwiftUI/tools/api_surface.lua` makes from the module the build produces, so a fresh tree runs the build, then
api_surface.lua, then a plain `./xmakew l -P . frameworks/SwiftUI/tools/coverage.lua --check`, which compares that count
with the ledger. Everything is compiled with availability checking **on**, against the same Swift runtime the app
carries.

## Usage

From the top of revenant, each a `./xmakew l -P . frameworks/SwiftUI/tools/<script>`:

```bash
emulate.lua tests                        # the engine tests, in the emulator
emulate.lua snapshots [--accept] [--only=NAME]   # rendered scenarios against frameworks/SwiftUI/tests/data/snapshots/
emulate.lua perf                         # in-app timings of deeply nested layouts
emulate.lua package                      # the platform and demo packages installed, the demo launched and checked to draw
coverage.lua --check                     # the ledger, checked against the code
api_surface.lua                          # the typed API diff against Apple's interface
api_surface.lua apple                    # Apple's 26.2 surface, which the invented-name gate reads
device.lua shots SCENARIO...             # scenarios rendered on a claimed phone
```

`xmake emulate launch` starts the application the way SpringBoard does, so it reaches
`application:didFinishLaunchingWithOptions:`; the engine tests are a console binary and go through `xmake emulate run`.

The package path installs the platform package `org.revenant.backports` and the demo's package into an iPhone 4S on iOS
6.1.3, the way dpkg installs them, launches the demo through SpringBoard and checks that it started, drew a settled frame
and did not crash:

```bash
./xmakew l -P . frameworks/SwiftUI/tools/emulate.lua package
```

It reconfigures the project with the emulator and the demo component, and restores its options afterwards. It is a tool
rather than a test target: a launch started from inside a running test never began its boot in my runs, while
the same launch from the command line does. The emulator packages have no prebuilt release, so the first configure
builds them, and the boot takes minutes of host time, so the tool is not part of `checks` in CI.


