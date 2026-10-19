# Contributor guide

Orientation for anyone — human or AI assistant — working on this repository. Read it before making changes; this file
is the map.

## What this is

Eidolon is an implementation of the SwiftUI API on the UIKit of iOS 6 (armv7), written from scratch. Apple's SwiftUI
cannot be ported (no armv7 build, Metal, 400+ missing system images), so the API is re-implemented; the Swift module is
named `SwiftUI` because every symbol an app takes from SwiftUI is mangled with that name. Combine is Styx (a fork of OpenCombine).

## Layout

- `eidolon/Sources/SwiftUI/` — the module. `Core.swift`, `Graph.swift` (nodes, reconciler, scheduler), `Layout.swift`,
  `Gestures.swift`, `AnimatableEngine.swift`, `Dialogs.swift`, `Hosting.swift`, and one file per area.
- `eidolon/Tests/main.swift` — the engine tests (one flat file; identifiers are global, so prefix new ones).
- `eidolon/Probe/`, `eidolon/Sources/SwiftUI/Probe.swift` — the headless probe: `_Probe` hosts a view without a
  window, dumps its tree, drives gestures, dialogs and animations for tests. `_Probe`, `_DialogDescription` and
  `_Unsupported` are `@_spi(Probe)`, not public API: a client of them says `@_spi(Probe) import SwiftUI`.
- `eidolon/Demo/` — the demo app and its snapshot scenarios; `eidolon/Snapshots/reference/` — the tree references.
- `eidolon/README.md` + `eidolon/coverage.py` — the ledger and its checker.
- `eidolon/xmake.lua`, `eidolon/control`, `eidolon/Info.plist` — the Charon port: the same demo sources built as two
  applications (`EidolonDemo`, and `EidolonSnapshots`, whose Info.plist carries `EidolonSnapshots` so it renders the
  scenarios) and the engine tests as `EidolonTests`, each a Debian package `xmake emulate` installs into the image.
- `bridge/` — the typed API diff and the invented-name gate (`api-surface.sh`, `api-diff.lua`, `api-invented.lua`).
- `combine/` — the pre-Styx port of OpenCombine and its upstream test suite on iOS 6 (`build.sh`, `emu-loop.sh`,
  `gentests.py`, `stage-pkg.sh`), with results in `combine/RESULTS.md`. Historical: Styx, the `Combine` module Eidolon
  actually links, carries its own tests now.
- `rtpkg/` — the xmake project that builds the runtime packages Eidolon and Styx link against (`xmake.lua`, `control`,
  `main.swift`); everything else under it (`build/`, `*.log`, `xmake-addons.lock`) is xmake's own output and
  git-ignored.
- `device-run/` — probe output captured on hardware (`probe-ipad2.out`, `probe-iphone4s.out`), the source of the
  performance numbers in `eidolon/README.md`.

## Build and test

```bash
eidolon/build.sh                                    # begins with the ledger check
../run-emu.sh                                       # the engine tests, in the emulator
../snapshots.sh                                     # 38 rendered scenarios against eidolon/Snapshots/reference/
```

`run-emu.sh` and `snapshots.sh` drive the Charon emulator: `xmake f -c -P eidolon` (`-c`, so the package the pin names is the one installed), then `xmake emulate install` and
either `emulate run /usr/libexec/EidolonTests` or `emulate launch space.kern0x1b.eidolon.snapshots until-exit`. The
addon has to be one with `xmake emulate launch` (Charon v0.8.14 or later; `until-exit` holds until the application exits from v0.8.16), named by `CHARON_ADDON`; `CHARON_REPO`
names a Charon checkout to take the packages from. The scenarios need a key window, so they run in the application,
through SpringBoard; the engine tests are a console binary and go through `run`.

A change is done when the engine tests, every snapshot and the ledger check (`coverage.py --check`, after
`bridge/api-surface.sh`) pass. Anything that
touches layout, gestures, animation, dialogs or navigation also gets a run on hardware (an iPad 2 or an iPhone 4S on
iOS 6.1.3): the repository skill `device-ssh-access` says how to reach one from here.

Workspace-wide procedures are skills in `$HOME/Git/projects/ios/.agents/skills/`: `device-session` (claim, run, install, launch, tap on a real device), `canon-install`, `patch-merge`, `worktree-sweep`, `session-handoff`, `band-launch`, `band-supervise`. A session started inside this repository does not list them — read `<name>/SKILL.md` there.

## Rules that matter

- **No silent no-ops.** An API the engine does not honour either works, or is declared with `ignored(...)` (nothing to
  correspond to on iOS 6) or `_Unsupported.note(...)` (works with a named difference), and appears in
  `eidolon/README.md`. `coverage.py --check` fails the build otherwise. A protocol requirement that is only an
  *extension* member is not dispatched dynamically: put user-overridable members in the protocol.
- **Do not measure completeness by names.** Use `bridge/api-surface.sh`; it compares declarations. When you add an
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
- **Look at the picture before accepting a snapshot.** Wrong: `../snapshots.sh --accept`, or a new scenario (whose
  reference is written on its first run with no comparison), judged by the tree text alone. Right: `../snapshots.sh`
  also writes each scenario's PNG into `runs.noindex/snap-<time>/shots/`; look at it, then accept. `ONLY=<scenario>`
  renders one (it is a key of the snapshot bundle's Info.plist, so the port is reconfigured and the bundle rebuilt).
  Reason: a reference is the view tree as text, so an empty image or a lost label matches its own fresh reference.
- **Nothing personal.** No device addresses, hostnames, credentials or absolute `/Users/<name>/…` paths in tracked
  files; machine-local paths go in `local.env` (git-ignored). `bridge/fw/` is a copy of Apple's SDK content: it is
  generated by `bridge/prepare-fw.sh`, is git-ignored and must never be committed.
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
