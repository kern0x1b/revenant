# The two intent providers, and the spellings they do not share with the timeline provider

`AppIntentTimelineProvider` and `IntentTimelineProvider` are `TimelineProvider`s, so they inherit
`placeholder(in:)`, `getSnapshot(in:completion:)`, `getTimeline(in:completion:)` and `relevance()` - the
framework declares those *on the two protocols* as well, under the spellings the configuration's intent
gives them a reason for:

| provider | snapshot | timeline |
| --- | --- | --- |
| `TimelineProvider` | `getSnapshot(in:completion:)` | `getTimeline(in:completion:)` |
| `AppIntentTimelineProvider` | `snapshot(for:in:)` | `timeline(for:in:)` |
| `IntentTimelineProvider` | `getSnapshot(for:in:completion:)` | `getTimeline(for:in:completion:)` |

The two intent providers also ask for recommendations - the intents the system should offer the owner
to configure this widget with - which is `recommendations()`, and the app-intent one names the intent
instance the widget is configured with, which is what the `for:` of those two spellings is.

These are the rows the module's last pass wrote, in the section below; the rest of WidgetKit's surface
is declared and measured (**240 of 340 placed, and the 100 that are not** are in the missing-rows
list, regenerated from the corpus ledger and a digester dump and not kept), and the counts section
below says where the 245 came from and what took the five.

## What landed after the TipKit differential, and what the ledger can see of it

The ten rows the coordinator named are **declared and compile** (`frameworks/Backports/src/WidgetKit/Providers.swift`
and `Configuration.swift`):

| row | where |
| --- | --- |
| `AppIntentTimelineProvider.snapshot(for:in:)`, `.timeline(for:in:)` | `Providers.swift`, `async`, the configuration passed in |
| `AppIntentTimelineProvider.placeholder(in:)`, `.recommendations()`, `.relevance()` | same protocol, with the framework's own default implementations in the extension |
| `IntentTimelineProvider.getSnapshot(for:in:completion:)`, `.getTimeline(for:in:completion:)`, `.placeholder(in:)`, `.recommendations()`, `.relevance()` | `Providers.swift`, the completion-handler shape |
| `WidgetPushHandler.pushTokenDidChange(_:widgets:)` | `Configuration.swift` |

Three of these changed the design, not just the count:

- `AppIntentTimelineProvider` no longer inherits `TimelineProvider`. The interface
  (`WidgetKit-ios.swiftinterface:1538`) declares it standalone with its own `Entry`/`Intent` and the
  *async* `snapshot(for:in:)`/`timeline(for:in:)`, so a provider answers one way, not two. It was an
  empty refinement of `TimelineProvider` before, which made a conformer implement the completion
  handlers as well.
- `IntentTimelineProvider` likewise, and its `Intent` is constrained to the AppIntents `AppIntent`
  rather than the interface's `Intents.INIntent`: the Objective-C framework is another band's and is
  not on these releases, and the port's own `IntentConfiguration` already takes that type. The
  divergence is here, not hidden.
- `WidgetPushHandler` was a `final class` with a `pushTokensDidChange(widgets:)` the framework does
  not declare; it is now the framework's protocol with `pushTokenDidChange(_:widgets:)`.

**The ledger cannot count nine of the ten.** `WidgetPushHandler.pushTokenDidChange(_:widgets:)` is
now placed (245 rows placed, one more than before). The nine intent-provider rows stay in
the run's `WidgetKit-missing.tsv` (a run file, not kept) because the digester prints **nothing** for either protocol — not the
protocol row for `AppIntentTimelineProvider`, not its `Context` typealias, not a member — and
`IntentTimelineProvider`'s own protocol row flipped *into* the missing list. The two protocols are the
only ones in this module whose associated types and members name a type from another module
(`AppIntents.WidgetConfigurationIntent`, `AppIntents.AppIntent`), which is the gap this repository's
own notes already record for `AlertConfiguration.title` and
`WidgetInfo.widgetConfigurationIntent(of:)`: a member typed with another module's type is not
reported even with that module on the digester's `-I`. `IntentTimelineProvider` was counted as
placed before only because it was an empty refinement, with no member of its own to drop.

## The 95 rows, classified against the digester's own dump

The row classifier (since removed) read the `-dump-sdk` dump of the built module and the missing-rows
list, regenerated from the corpus ledger and a digester dump and not kept, and sorted every row. Of
the 95:

| how the digester prints it | rows | whose work it is |
| --- | --- | --- |
| printed, under another name | **38** | the ledger's matcher: `==(a:b:)`→`==(_:_:)`, `init?(coder:)`→`init(coder:)`, `subscript(keyPath:)`→`subscript(_:)` |
| owner not printed at all | 22 | the cross-module gap, with *both* other modules on `-I`: the `ActivityAttributes` family (`ActivityConfiguration`, `ActivityViewContext`, `ActivityConfiguration.init(for:content:dynamicIsland:)`, `ActivityAttributes.previewContext(_:isStale:viewKind:)`, `DynamicIslandExpandedRegion.init(_:priority:content:)`, `Image.widgetAccentedRenderingMode(_:)`, the `EnvironmentValues.activity*` rows) and the `AppIntents` family (`AppIntentConfiguration`, `IntentConfiguration`, `AppIntentControlConfiguration`, `AppIntentRecommendation`, both intent-provider protocols) |
| member not printed | 23 | the eight `Preview(...)` rows (macros from Apple's `PreviewsMacros` plugin), the `EnvironmentValues.*` rows that need `SwiftUI.EnvironmentValues`, `StaticControlConfiguration.init(kind:content:)`, and `TimelineProviderContext.EnvironmentVariants.subscript(keyPath:)` |
| bare row, no owner | 12 | the same `Preview` macros seen from the other side, and the top-level `Preview` initialisers |

**One of the 23 was real and is fixed.** `TimelineProviderContext.EnvironmentVariants`'s key-path
subscript returned `fatalError` — a crash in a library a port links, for a value the system owns. The
framework's own subscript is optional (`[T]?`, `WidgetKit-ios.swiftinterface:1719`), so the honest
answer for a variant this release has no record of is none, and the port now returns `nil` instead of
trapping. It still does not count as placed, because the digester prints it as `subscript(_:)`.

## The five declarations review 2 removed, and why each is not there

An audit report, `2026-09-28-api-appintents-kits-2.md` (not kept in the repository), found five `fatalError`s in this module and one fabricated
value. All six are gone (`grep -rn fatalError frameworks/Backports/src/{WidgetKit,TipKit,ActivityKit}` is
empty), and the rows below are the cost, stated rather than hidden:

| removed | why it is not here | what it costs |
| --- | --- | --- |
| `ControlWidgetButton.init(_:action:actionLabel:)` | every constructor the framework declares on this type needs SwiftUI — the row is `where Label == SwiftUICore.Text` with an `AppIntent` action and an `actionLabel` closure (`WidgetKit-ios.swiftinterface:1334-1341`) — and this module's own label constructor is a trap, not a substitute | 1 placed row |
| `ControlWidgetToggle.init(_:isOn:action:valueLabel:)` | the same, for the toggle (`:1231-1236`, `:1250-1258`) | 1 placed row |
| `ControlWidgetButtonDefaultActionLabel.body`, `ControlWidgetToggleDefaultLabel.body`, `AccessoryWidgetBackground.body` | a `body: some SwiftUICore.View` row; the port had `body: Never { fatalError }`, and a `Never` has no value, so a non-trapping `body` cannot be one. These are SwiftUI rows, like TipKit's ten, and are in that list | 3 placed rows |
| `EnvironmentVariants.subscript(dynamicMember:)` returned `true` for every name | it now takes the key path the framework's own `@dynamicMemberLookup` subscript takes (`WidgetKit-ios.swiftinterface:1714-1716`) and answers `[Value]?` — none — like the subscript beside it | no row: the old shape was not the framework's, the new one is |

`ActivityViewContextPlaceholder.context(for:)` keeps its row and no longer traps: a context needs an
`Attributes` instance and a `ContentState` instance, this release has neither, so the answer is
optional and is none. `AccessoryWidgetBackground` is declared and conforms to `WidgetBody` with
`BodyType = Never`, the framework's `View` conformance with no type here for the background it draws.
WidgetKit is **240 of 340** placed, 100 missing, and the five rows above are why.

`ControlWidgetButton` and `ControlWidgetToggle` keep the constructors that take the app's own label
(`init(action:label:)`, and the `actionLabel:`/`valueLabel:` forms), which trap nowhere and need
nothing this module does not have.

## The counts

`340 - 100 - 0 = 240` is this module's placement, measured with the toolchain's own
`swift-api-digester -dump-sdk` of the module built for `armv7-apple-ios6.1.3` against
the WidgetKit ledger, since removed (340 rows), and it is the same number the kits' run
directory's table carries with its `<F>-missing.tsv` beside it. The rule is stated there: `rows -
missing - wrong-kind = placed`, every line checked against the list beside it rather than written from
memory, because a table written from memory drifts (TipKit once read 247/73 while its own TSV held 75).

The step that took it from 245 to 240 is review 2's, and the five rows are named in the table above:
two `ControlWidget*` constructors and three `body: Never` members, all of which stood for
declarations the framework does not have. Nothing in this module's later work moved a row: the two
subset-condition changes and the `Parameter`/`ParameterOption` rewrite were in TipKit, and the
comparator work was in AppIntents, and neither is a number this module reports.
