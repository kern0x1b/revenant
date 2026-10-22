# Reuse: what was compared against, and why it was or was not taken

The reviewer brief's rule (owner, 2026-09-28): a delivery names the open upstream it took from, or
"searched: none" with the queries. This is that line for `revenant@appintents` and the three kits.

**searched: none** — with the queries that establish it, run 2026-09-28 from the machine:

| query | what it found | why it was not reused |
| --- | --- | --- |
| `gh search repos "swift backport framework shim iOS 6"` | nothing | — |
| `git -C <worktree> diff --stat origin/main..HEAD` over `api-kits` and `api-swift-kits` | no file under any of the four package directories | no other band in the fleet has written any of them, so nothing of ours was duplicated. |

**What *was* reused**, named so the line is not read as "wrote everything from nothing":

* **`revenant@swift-runtime`** — the port's own Swift runtime, a package, declared as every recipe's
  dependency. Nothing in the four modules reimplements it.
* **SwiftUI's `SwiftUI`** — the SwiftUI band, `frameworks/SwiftUI`
  (`src/`) in revenant: `View` with its `body` requirement (`Core.swift:7-13`), `Text`
  (`Views.swift`), `ShapeStyle`, `Edge`, `Binding`, `PresentationBackgroundInteraction`,
  `EnvironmentValues` (`Graph.swift:8`), `EnvironmentKey` (`Environment.swift:4`). It is the source
  the **view rows are routed to** and the reason they are not declared here: it is compiled only into
  the SwiftUI targets of the revenant project, with no `revenant@swiftui` package to depend on, so a port cannot
  build against it yet (the ask is with the band).
* **`the deleted registry package registry/CoreSpotlight/ios9.json`** — the backports package's own
  registry entry, read by the AppIntents recipe through the runtime's port overlay (`REVENANT_SWIFT_PORT_HEADERS`, which no build sets since the port headers were removed). The
  `scriptdir()` defect that hid it was this delivery's; the registry itself is not ours.
* **Apple's own `.swiftinterface`s and `swift-api-digester`** — as *references* for the declarations
  and for the measurement, which is not reuse of an implementation: nothing from them is vendored.

**Not reused, and worth naming because it is the obvious candidate:** `swift-foundation`. The
`AttributedString`, `Measurement` and `Calendar.RecurrenceRule` rows are gated on it
(`frameworks/Backports/src/AppIntents/Gated.swift`, and the recipe's probes, which measure rather than assume). This
delivery carries the *conformances* AppIntents adds to those types and takes the types themselves from
the runtime, which is the Foundation band's to carry; a second copy of `Measurement` here would be a
second copy of something that exists (the workspace contract: no second copy of what exists).