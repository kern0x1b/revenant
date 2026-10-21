# Reuse: what was compared against, and why it was or was not taken

The reviewer brief's rule (owner, 2026-09-28): a delivery names the open upstream it took from, or
"searched: none" with the queries. This is that line for `revenant@activitykit`.

**searched: none.** The queries and what each turned up are in
(a file of an earlier layout, not in the repository) — `gh search code "public protocol AppIntent
language:swift"`, `gh search code "public protocol ActivityAttributes language:swift"`, `gh search
repos "swift backport framework shim iOS 6"` (empty) — and none of them is a TipKit: the framework has
no open reimplementation that a `search` finds, and (a workflow file kept outside the repository) carries
`owner = "no upstream; a band"` on all 321 rows. For TipKit specifically I also searched for the two
things a port of it would most likely be built from, and found nothing reusable:

| query | result |
| --- | --- |
| `gh search code "Tips.DonationTimeRange language:swift"` | nothing outside Apple's SDKs |
| `gh search code "public protocol Tip language:swift" --limit 10` | the two host-side stand-ins already named in AppIntents' reuse line, plus app code, and both stand-ins declare nothing |

**What this module does reuse**, so the line is not read as "wrote everything from nothing":

* **`revenant@swift-runtime`** — the runtime a port carries; every recipe here declares it, and
  `toolchain/modules/apple/swift.lua` supplies the compile flags rather than this package re-deriving them.
* **`revenant@appintents`** — for `LocalizedStringResource`, which the recipe probes for and this
  release's Foundation does not have, and which therefore comes from the AppIntents module (the
  crutch is filed in (a workflow file kept outside the repository), open until Foundation Swift r2 carries it). Nothing
  here reimplements it.
* **SwiftUI's `SwiftUI`** — the source the ten `View.tip*` rows are routed to, and the reason they
  are not declared here: SwiftUI (`frameworks/SwiftUI/src/` in revenant) has
  `View` with its `body` requirement, `ShapeStyle`, `Edge`, `Binding`,
  `PresentationBackgroundInteraction`, `EnvironmentValues` and `EnvironmentKey`, but it is compiled
  only into the SwiftUI targets of the revenant project and there is no `revenant@swiftui` package to depend on
  yet. The ask is with the SwiftUI band; `README.md:40-43` and `docs/reference/backports/TipKit/TipKit/Rendering.md` say so too.
* **`the deleted registry package registry/CoreSpotlight/ios9.json`** — read through
  the generator's port headers ((a file of an earlier layout, not in the repository)); not this package's file.
* **Apple's own `.swiftinterface` and the toolchain's `swift-api-digester`** — as the reference for
  the declarations and the measurement. Nothing from either is vendored, and the host differential
  compares against Apple's *own* `TipKit` on the macOS 27 SDK rather than a port of it
  (`the host-differential writeup, **not kept**; its results are in the facts beside this`).
