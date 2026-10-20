# Contributor guide

Orientation for anyone — human or AI assistant — working on this repository. Read it before making changes; this file
is the map.

## What this is

SwiftUI is an implementation of the SwiftUI API on the UIKit of iOS 6 (armv7), written from scratch. Apple's SwiftUI
cannot be ported (no armv7 build, Metal, 400+ missing system images), so the API is re-implemented; the Swift module is
named `SwiftUI` because every symbol an app takes from SwiftUI is mangled with that name. Combine is Combine (a fork of OpenCombine).

## Layout

- `Sources/` — the module. `Core.swift`, `Graph.swift` (nodes, reconciler, scheduler), `Layout.swift`,
  `Gestures.swift`, `AnimatableEngine.swift`, `Dialogs.swift`, `Hosting.swift`, and one file per area.
- `Tests/main.swift` — the engine tests (one flat file; identifiers are global, so prefix new ones).
- `Tests/Probe/`, `Sources/Probe.swift` — the headless probe: `_Probe` hosts a view without a window, dumps its tree,
  drives gestures, dialogs and animations for tests. `_Probe`, `_DialogDescription` and `_Unsupported` are
  `@_spi(Probe)`, not public API: a client of them says `@_spi(Probe) import SwiftUI`.
- `Tests/TypeChecks/` — snippets the `Table` and `TabContent` builders must accept or refuse, run by the tests of the
  `SwiftUITypeChecks` target.
- `Tests/Host/` — macOS oracles (`docs/host.md`); `Tests/Surface/` — the interface walker (`docs/surface.md`), a host
  project of its own; `Tests/API/` — the lists of Apple's types and modifiers, the allow-list and the not-applicable
  list the coverage check and the API diff read, and the sample app of `docs/bridge.md`.
- `Demo/` — the demo app and its snapshot scenarios, with the `Info.plist` and `control` of both applications;
  `Snapshots/` — the tree references.
- `docs/ledger.md` + `tools/coverage.lua` — the ledger and its checker.
- `tools/` — every script of this folder, in Lua, run with `./xmakew l frameworks/SwiftUI/tools/<script>` from the top of
  revenant; `tools/lib/tree.lua` names the folders they read and the run folder they write
  (`$HOME/.revenant/cache/<task>/swiftui/`, from `toolchain/modules/workspace.lua`).
- `xmake.lua` — the targets of this member in the revenant project (the top `xmake.lua` of revenant includes it):
  `SwiftUI` on Combine's `Combine`; the demo `SwiftUIDemo` and `SwiftUISnapshots`, the same demo sources whose
  Info.plist carries `SwiftUISnapshots` so it renders the scenarios; `SwiftUITests` and `SwiftUIProbe`, daemons; each a
  Debian package `xmake emulate` installs into the image. The options `swiftui_snapshot_only` and `swiftui_perf` set
  the keys of the snapshot bundle and the demo that `tools/emulate.lua` asks for.

## Build and test

From the top of revenant:

```bash
./xmakew f -P . -p iphoneos -a armv7 -y
./xmakew build -P . SwiftUI                                      # begins with the ledger check
./xmakew test -P . SwiftUITypeChecks/*                           # the builder typechecks
./xmakew l frameworks/SwiftUI/tools/emulate.lua tests            # the engine tests, in the emulator
./xmakew l frameworks/SwiftUI/tools/emulate.lua snapshots        # 38 rendered scenarios against Snapshots/
```

`emulate.lua` drives revenant's emulator (skill `emulate-port`): it configures the project with `-c` (so the package
the pin names is the one installed) and `--emulate=y`, then runs `./xmakew emulate install` and
`emulate run /usr/libexec/SwiftUITests`, or `emulate launch space.kern0x1b.swiftui.snapshots until-exit`. The scenarios
need a key window, so they run in the application, through SpringBoard; the engine tests are a console binary and go
through `run`. Its logs, the run's results and the pictures go to a fresh folder under the run folder, which it
prints.

A change is done when the engine tests, every snapshot and the ledger check (`coverage.lua --check`, after
`tools/api-surface.lua`) pass. Anything that
touches layout, gestures, animation, dialogs or navigation also gets a run on hardware (an iPad 2 or an iPhone 4S on
iOS 6.1.3): the skill `swiftui-device` says how to reach one from here.

## Rules that matter

- **No silent no-ops.** An API the engine does not honour either works, or is declared with `ignored(...)` (nothing to
  correspond to on iOS 6) or `_Unsupported.note(...)` (works with a named difference), and appears in
  `docs/ledger.md`. `coverage.lua --check` fails the build otherwise. A protocol requirement that is only an
  *extension* member is not dispatched dynamically: put user-overridable members in the protocol.
- **Do not measure completeness by names.** Use `tools/api-surface.lua`; it compares declarations. When you add an
  overload, the gap count should fall.
- **Availability checking stays on.** Never build with `-disable-availability-checking`: it hides iOS 7+ APIs and the
  `fatalError` stubs of the overlay. Put newer API behind `#available`.
- **The look is iOS 6's own.** Wrong: drawing a modern flat stand-in for a control, bar or button. Right: map the
  SwiftUI element onto the iOS 6 UIKit control that corresponds (`UISwitch`, `UISlider`, `UIStepper`,
  `UITabBarController`, the release's navigation bar), and give anything custom-drawn the release's own gloss, bevel
  and metrics. Reason: an app must look like one written for iOS 6, and the tree snapshots do not compare appearance.
- **Views get `bounds` and `center`, not `frame`.** A view with a transform has an undefined `frame`.
- **Invalidate layout at the source.** A node that changes what it lays out calls `invalidateLayout()`; wrapper nodes
  adopt their content on the inner layout node, or the walk up skips the node that holds the size cache.
- **A test must fail without the fix.** Revert the change and run it once.
- **Look at the picture before accepting a snapshot.** Wrong: `emulate.lua snapshots --accept`, or a new scenario
  (whose reference is written on its first run with no comparison), judged by the tree text alone. Right:
  `emulate.lua snapshots` also copies each scenario's PNG into the `shots/` folder it prints; look at it, then accept.
  `--only=<scenario>` renders one (it is a key of the snapshot bundle's Info.plist, so the project is reconfigured and
  the bundle rebuilt). Reason: a reference is the view tree as text, so an empty image or a lost label matches its own
  fresh reference.
- **Nothing personal.** No device addresses, hostnames, credentials or absolute `/Users/<name>/…` paths in tracked
  files; the phone is named in a git-ignored `device.env`. The copy of Apple's SwiftUI framework that
  `tools/api-surface.lua prepare` makes is Apple's SDK content: it lives in the run folder, outside the tree, and must
  never be committed.
- **No Apple code or assets** in the repository, and no comments that explain the obvious; match the density of the
  file you are in.
- **No copyleft code.** Wrong: copying code from a GPL project into this repository — the Objective-C Telegram-iOS
  before its Swift rewrite, a good reference for swipes, custom cells and gesture-driven animation on plain UIKit, is
  one. Right: study how it solves the problem and write it anew. Reason: this repository is MIT (`LICENSE`), and GPL
  code would bind it to the GPL.

## Limits of the test environment

The engine tests run in a console process of the emulator, not in an app: fonts crash there (tests use `Color`, not
`Text`), timers and the main queue do not fire, and `UIView.animate` has no render server. Text, navigation and timer
behaviour is checked in the snapshot scenarios, which run inside the demo app. Animations driven by `ValueAnimator` are
tested with a virtual clock (`_Probe.useVirtualClock()`, `_Probe.advanceAnimations(to:)`); dialogs through
`_Probe.captureDialogs`.

One more limit, measured in the emulator's guest. There is no `UIApplication`, so `UIControl.sendActions(for:)` sends
nothing: a test performs the control's registered actions with `deliver(_:to:)`. Core Image draws there as on a device (the
colour-filter and blur pixel checks always run, and fail if it draws nothing).

## Conventions

- Commit subjects are plain and imperative; an agent's commit ends with its own `Co-Authored-By:` trailer.
- Documents in `docs/` and the ledger are in Russian; the front README and this guide are in English.
