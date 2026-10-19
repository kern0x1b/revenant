# SwiftUI

**SwiftUI for iOS 6 — a from-scratch implementation of the SwiftUI API on UIKit, for armv7.**

Apple's SwiftUI cannot run on iOS 6: it has never had an armv7 build, it needs Metal, and it drags in over four hundred
system images the phone does not have. So this project re-implements the *API* instead. It is a Swift module named
`SwiftUI`, built on the UIKit of iOS 6, with [Combine](https://github.com/kern0x1b/revenant/tree/main/frameworks/Combine), a Combine for iOS 6, standing in for
Apple's Combine. An app written in ordinary SwiftUI syntax compiles against it and comes out as a native-looking iOS 6 app on a
phone from 2011.

The module keeps Apple's name on purpose: the mangled names of every symbol an app takes from SwiftUI depend on it.
The project, its directory and its build targets carry the same name.

## What works

A retained node tree over UIKit views, with a reconciler, a layout engine of its own and a scheduler that re-renders
only what changed. The areas below are exercised by tests and by rendered scenarios; the full ledger — what is
implemented, what is deliberately ignored and why, what is simplified — is in [`SwiftUI/README.md`](SwiftUI/README.md)
(in Russian) and is checked by the build.

| Area | What there is |
| --- | --- |
| Description and state | `View`, `ViewBuilder`, `@State`, `@Binding`, `@ObservedObject`, `@StateObject`, `@EnvironmentObject`, `@Environment`, `@AppStorage`, `@FocusState`, `@GestureState`, `@FetchRequest` (over Core Data) |
| Layout | stacks, `ZStack`, `Grid`, lazy stacks and grids, `ScrollView`, `GeometryReader`, alignment guides, the `Layout` protocol with a persistent cache and animatable layouts |
| Controls and text | `Text` (concatenation, styles), `Button`, `Toggle`, `TextField`, `Slider`, `Stepper`, `Picker`, `DatePicker`, `List`, `Form`, `Table`, `Menu`, `Label`, `ProgressView`, `Canvas` |
| Navigation and presentation | `NavigationView`, `NavigationStack`, `NavigationSplitView`, `TabView`, sheets, every form of `alert` and `confirmationDialog`, search |
| Gestures | typed gesture engine: `map`, `updating` with `@GestureState`, `sequenced`, `exclusively`, `simultaneously`, custom gestures through `body` |
| Animation | `withAnimation`, `repeatForever`, transitions, `matchedGeometryEffect`; the `animatableData` of custom shapes, geometry effects, view modifiers and layouts is interpolated frame by frame |
| Graphics | `Shape` and `Path` (trim, stroke, relative arcs), gradients, `GeometryEffect`, `ProjectionTransform` |
| Bridges | `UIViewRepresentable`, `UIViewControllerRepresentable`, `UIHostingController` |
| Accessibility | labels, values, traits, containers built from `accessibilityChildren`, sort priority, VoiceOver focus |

### On a phone

The screens of the demo app, drawn by the engine on an iPhone 4S running iOS 6.1.3 (armv7) — nothing here is an emulator.
[`docs/device/`](docs/device/) holds them: the symbol set, a social feed, settings, a dashboard, a store, contacts, token
search and an onboarding pager. `device-shots.sh` installs the demo, has the app render a scenario in its own process and
fetches the picture; `device-shots.sh --live` takes a picture of the real screen.

### How complete is it

Two numbers, and they measure different things.

- **By name:** 504 of Apple's 592 public types and every one of the 311 `View` modifier names are present; each API
  that iOS 6 cannot honour is *declared*, writes a line to a journal when used, and is listed with its reason. Nothing
  is a silent no-op — the build fails if an ignored or simplified API is not named in the ledger.
- **By declaration:** comparing Apple's SwiftUI interface for iOS 16.4 with this module signature by signature
  (`bridge/api-surface.sh`) finds, of the 4740 declarations of Apple's public interface, **3233 (68%) callable as Apple writes them, 314 (7%) present with a different signature, 927 (20%) absent and still to write, and 266 (6%) of types that iOS 6 or a phone cannot have, listed with a reason in `bridge/not-applicable.txt`**.
  A good part of the absent ones has nothing to correspond to on iOS 6 (widgets, documents, windows, accessibility
  rotors); the rest is the work queue.

The gap between the two is not hidden: counting by name alone overstated completeness, which is why the second measure
exists.

## How it works

- **Node tree.** Every view becomes a node. Primitive views (`Text`, `Button`, stacks) own UIKit views; composite views
  own a child node and re-evaluate `body` when their state changes.
- **Reconciliation.** A node is reused when the type of its view is unchanged, and skipped entirely when the view's bytes
  and the environment are unchanged. `if`/`else` branches are distinct identities, as in SwiftUI.
- **Dependencies.** A view's stored properties are read reflectively once per type, so `@State` and `@ObservedObject`
  find their nodes without code generation.
- **Layout.** Sizes are proposed and reported in points, cached per node, and applied to UIViews by size and centre.
  Only the nodes marked dirty are laid out again.
- **Animation.** Ordinary properties are handed to `UIView.animate`; data that UIKit cannot interpolate is driven frame
  by frame by a display-link animator.
- **Combine** is `frameworks/Combine`, built with the same Swift runtime; it is a module named `Combine`, so apps write `import Combine`.

## Requirements

- macOS and the revenant checkout this folder is in, configured for iOS at its top (revenant's README: the revenant addon of
  the checkout, `xmake f -p iphoneos -a armv7`): the module is the `SwiftUI` target, Combine the `Combine` and
  `CombineHelpers` targets, and `swift-runtime`, `libcxx`, `apple-compat`, the iOS SDK, `llvm`, `ld64` and `ldid` the
  toolchain packages the project requires. `pkg-env.sh` asks the revenant project where each is (`xmake where`, `xmake show`).
  An app outside revenant takes SwiftUI as the package `revenant@swiftui-uikit` instead.
- To run the tests and rendered scenarios: the toolchain's emulator (`emulator/`), which `xmake emulate` drives — the port in
  `SwiftUI/` builds the demo app, the snapshot bundle and the test binary as packages, and the emulator image,
  the device and the release are named on the command line (`-d iPhone4,1 -r 6.1.3`). The addon must be one that has
  `xmake emulate launch` (revenant v0.8.14 or later); `REVENANT_ADDON` names it, and `REVENANT_REPO` a toolchain checkout to
  take the packages from.
- To measure on hardware: an iPhone 4S or an iPad 2 on iOS 6.1.3, reached through Revenant's device tooling
  (`REVENANT_MODULES` names the `modules` directory of a toolchain checkout).

Machine-local paths go in `local.env` (git-ignored); nothing personal is tracked.

## Build

```bash
SwiftUI/build.sh        # module, demo app, tests and probe -> SwiftUI/out/SwiftUIDemo.app
xmake f -P SwiftUI -p iphoneos -a armv7 -y   # the same, as a Revenant port: the app and the tests as packages
```

The build begins with `xmake l SwiftUI/coverage.lua --check --before-build`, which refuses to continue if the ledger and the code
disagree. The count of invented names is not part of that: it is read from `bridge/api/invented.txt`, which
`bridge/api-surface.sh` makes from the module the build produces, so a fresh tree runs the build, then api-surface.sh,
then a plain `xmake l coverage.lua --check`, which compares that count with the README.
Everything is compiled with availability checking **on**, against the same Swift runtime the app carries.

## Usage

```bash
../run-emu.sh                                           # the engine tests, in the emulator
../snapshots.sh [--accept]                              # rendered scenarios against tree references
../perf.sh                                              # in-app timings of deeply nested layouts
xmake emulate -P SwiftUI -d iPhone4,1 -r 6.1.3 launch space.kern0x1b.swiftui.demo
xmake l coverage.lua --check                            # the ledger, checked against the code
../bridge/prepare-fw.sh && ../bridge/api-surface.sh     # the typed API diff against Apple's interface
```

`xmake emulate launch` starts the application the way SpringBoard does, so it reaches
`application:didFinishLaunchingWithOptions:`; the engine tests are a console binary and go through `xmake emulate run`.

`bridge/guest-abi-check.sh` is gone: it built for arm64 with the iOS 16.4 SDK's stdlib, not the runtime the port ships
(the reason and the measurement are in `SwiftUI/README.md`, in its section on the two builds of the module).

## Repository layout

| Path | Holds |
| --- | --- |
| `xmake.lua` | the `SwiftUI` target, and the targets of `SwiftUI/` and `rtpkg/`, as part of the revenant project |
| `SwiftUI/` | the module (`Sources/SwiftUI`), the demo app, the engine tests, the probe, the snapshot references, the coverage ledger, and the targets (`xmake.lua`, `control`, `Info.plist`) of the app, the snapshot bundle and the tests for `xmake emulate` |
| `bridge/` | the typed API diff against Apple's interface, the invented-name gate, and the name lists they use |
| `rtpkg/` | `swiftuirt`, a daemon of Combine and the runtime with the backports, as a target of the revenant project |
| `docs/` | the research (in Russian) |
| `*.sh`, `device.lua` | run the emulator, take snapshots and timings, reach a device |

## Documentation

| Document | About |
| --- | --- |
| [`SwiftUI/README.md`](SwiftUI/README.md) | the ledger: what is implemented, ignored, simplified or missing; measurements |
| [`docs/research.md`](docs/research.md) | why Apple's SwiftUI cannot be ported, and the design of this implementation (Russian) |
| [`bridge/README.md`](bridge/README.md) | the guest build by hand: the sample app, the slot table |
| [`../Combine/docs/TEST-RESULTS.md`](../Combine/docs/TEST-RESULTS.md) | OpenCombine's own tests against Combine, the `Combine` this module re-exports, on iOS 6 |
| [`AGENTS.md`](AGENTS.md) | the contributor guide |

## Trademarks

SwiftUI, UIKit, Combine, iOS and iPhone are trademarks of Apple Inc. They are used here nominatively, to say what this
project is compatible with. There is no affiliation. This repository contains no code or assets of Apple's.

## License

MIT, see `LICENSE`. Third-party dependencies and their terms are listed in `THIRD-PARTY.md`; nothing third-party is
vendored.

Built with Claude (Anthropic). This project is developed with AI assistance, openly — see the commit history.
