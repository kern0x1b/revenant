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
implemented, what is deliberately ignored and why, what is simplified — is in [`docs/ledger.md`](docs/ledger.md)
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
search and an onboarding pager. `tools/device.lua shots` installs the demo, has the app render a scenario in its own
process and fetches the picture; `tools/device.lua shots --live` takes a picture of the real screen.

### How complete is it

Two numbers, and they measure different things.

- **By name:** 504 of Apple's 592 public types and every one of the 311 `View` modifier names are present; each API
  that iOS 6 cannot honour is *declared*, writes a line to a journal when used, and is listed with its reason. Nothing
  is a silent no-op — the build fails if an ignored or simplified API is not named in the ledger.
- **By declaration:** comparing Apple's SwiftUI interface for iOS 16.4 with this module signature by signature
  (`tools/api-surface.lua`) finds, of the 4740 declarations of Apple's public interface, **3233 (68%) callable as Apple writes them, 314 (7%) present with a different signature, 927 (20%) absent and still to write, and 266 (6%) of types that iOS 6 or a phone cannot have, listed with a reason in `Tests/API/not-applicable.txt`**.
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

- macOS and the revenant checkout this folder is in, configured for iOS at its top (revenant's README, "One xmake
  project"): the module is the `SwiftUI` target, Combine the `Combine` and `CombineHelpers` targets, and
  `swift-runtime`, `libcxx`, `apple-backports`, the iOS SDK and the tools are packages the project requires. An app
  outside revenant takes SwiftUI as the package `revenant@swiftui-uikit` instead.
- To run the tests and rendered scenarios: revenant's emulator, which `./xmakew emulate` drives once the project is
  configured with `--emulate=y`. `tools/emulate.lua` does that configure itself; use the emulator the way the
  repository's skill `emulate-port` says.
- To measure on hardware: an iPhone 4S or an iPad 2 on iOS 6.1.3, claimed with `./xmakew device` (skill
  `swiftui-device`).

Run output (logs, pictures, API dumps, the copy of Apple's framework) goes under `$HOME/.revenant/cache/<task>/swiftui/`,
never into the tree; `toolchain/modules/workspace.lua` names the task and the iOS 26.2 SDK the tools read.

## Build

From the top of revenant:

```bash
./xmakew f -P . -p iphoneos -a armv7 -y
./xmakew build -P . SwiftUI SwiftUIDemo SwiftUISnapshots SwiftUITests
./xmakew test -P . SwiftUITypeChecks/*                 # the Table and TabContent builders accept and refuse what Apple's do
```

Building `SwiftUI` begins with `tools/coverage.lua --check --before-build`, which refuses to continue if the ledger
and the code disagree. The count of invented names is not part of that: it is read from the `invented.txt` that
`tools/api-surface.lua` makes from the module the build produces, so a fresh tree runs the build, then
api-surface.lua, then a plain `./xmakew l frameworks/SwiftUI/tools/coverage.lua --check`, which compares that count
with the ledger. Everything is compiled with availability checking **on**, against the same Swift runtime the app
carries.

## Usage

From the top of revenant, each a `./xmakew l frameworks/SwiftUI/tools/<script>`:

```bash
emulate.lua tests                        # the engine tests, in the emulator
emulate.lua snapshots [--accept] [--only=NAME]   # rendered scenarios against Snapshots/
emulate.lua perf                         # in-app timings of deeply nested layouts
coverage.lua --check                     # the ledger, checked against the code
api-surface.lua                          # the typed API diff against Apple's interface
apple-surface.lua                        # Apple's 26.2 surface, which the invented-name gate reads
device.lua shots SCENARIO...             # scenarios rendered on a claimed phone
```

`xmake emulate launch` starts the application the way SpringBoard does, so it reaches
`application:didFinishLaunchingWithOptions:`; the engine tests are a console binary and go through `xmake emulate run`.

`bridge/guest-abi-check.sh` is gone: it built for arm64 with the iOS 16.4 SDK's stdlib, not the runtime the port ships
(the reason and the measurement are in `docs/ledger.md`, in its section on the two builds of the module).

## Layout

| Path | Holds |
| --- | --- |
| `xmake.lua` | the targets, as part of the revenant project: the module `SwiftUI`, the applications `SwiftUIDemo` and `SwiftUISnapshots`, the daemons `SwiftUITests` and `SwiftUIProbe`, and `SwiftUITypeChecks` |
| `Sources/` | the module |
| `Demo/` | the demo application and its scenarios; `Info.plist` and `control` of both applications |
| `Snapshots/` | the reference view trees of the scenarios, which `emulate.lua snapshots` compares against |
| `Tests/` | the engine tests (`main.swift`, `control`), the headless probe (`Probe/`), the builder typechecks (`TypeChecks/`), the macOS oracles (`Host/`), the interface walker (`Surface/`) and the API lists the coverage check reads (`API/`) |
| `tools/` | the Lua tools above, and the ones they share (`lib/`) |
| `docs/` | the ledger and the research (in Russian), and the notes of the tools |

## Documentation

| Document | About |
| --- | --- |
| [`docs/ledger.md`](docs/ledger.md) | the ledger: what is implemented, ignored, simplified or missing; measurements |
| [`docs/research.md`](docs/research.md) | why Apple's SwiftUI cannot be ported, and the design of this implementation (Russian) |
| [`docs/bridge.md`](docs/bridge.md) | the guest build by hand: the sample app, the slot table |
| [`docs/surface.md`](docs/surface.md) | the interface walker and the surface files the gaps are read from |
| [`../Combine/docs/TEST-RESULTS.md`](../Combine/docs/TEST-RESULTS.md) | OpenCombine's own tests against Combine, the `Combine` this module re-exports, on iOS 6 |
| [`AGENTS.md`](AGENTS.md) | the contributor guide |

## Trademarks

SwiftUI, UIKit, Combine, iOS and iPhone are trademarks of Apple Inc. They are used here nominatively, to say what this
project is compatible with. There is no affiliation. This repository contains no code or assets of Apple's.

## License

MIT, see `LICENSE`. Third-party dependencies and their terms are listed in `THIRD-PARTY.md`; nothing third-party is
vendored.

Built with Claude (Anthropic). This project is developed with AI assistance, openly — see the commit history.
