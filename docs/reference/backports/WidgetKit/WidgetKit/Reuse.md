# Reuse: what was compared against, and why it was or was not taken

The reviewer brief's rule (owner, 2026-09-28): a delivery names the open upstream it took from, or
"searched: none" with the queries. This is that line for `revenant@widgetkit`.

**searched: none**, with the queries and their results in
[AppIntents' reuse line](../../AppIntents/AppIntents/Reuse.md): the fleet diff there covers all four
package directories, this one included, and the repository search found no open implementation of the
framework.

**What this module does reuse**, so the line is not read as "wrote everything from nothing":

* **`revenant@swift-runtime`** — the runtime a port carries; the recipe declares it, and
  `toolchain/modules/apple/swift.lua` supplies the compile flags rather than this package re-deriving
  them.
* **`revenant@appintents`** — for `WidgetConfigurationIntent`, `AppIntent` and the other AppIntents
  types the configurations and the two intent providers name. The recipe declares it; nothing here
  re-declares them.
* **`revenant@activitykit`** — for `ActivityConfiguration`, `ActivityViewContext` and the live-activity
  types: `Configuration.swift` and `DynamicIsland.swift` import ActivityKit rather than growing a
  second copy of them.
* **Apple's own `.swiftinterface` and the toolchain's `swift-api-digester`** — as the reference for
  the declarations and the measurement. Nothing from either is vendored. There is no host differential
  for the module as a whole: the value types were diffed against the macOS host's own WidgetKit
  ([Values.md](../Values.md)), and the protocols are measured by the digester's dump of the module
  built for `armv7-apple-ios6.1.3`.

**SwiftUI is not reused, because there is none to reuse on these releases.** The `SwiftUI`-typed rows
the ledger carries (`Image.widgetAccentedRenderingMode(_:)`, the `EnvironmentValues.activity*` members,
the `SwiftUI.View` payloads the `Preview` macros name) belong to the SwiftUI band; this module declares
no SwiftUI type and imports none.
