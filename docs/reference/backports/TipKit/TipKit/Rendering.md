# The seam: the tip is drawn in the app

A tip is drawn as a popover: a rounded view with the tip's image, title, message and action buttons,
anchored to a view of the app's own and pointing an arrow at it, animated in and dismissed when the
owner acts or swipes. On iOS 16 and later that popover is drawn by the system's TipKit service, which
reads the datastore the app's own donations are written to. iOS 6.1.3 has no TipKit, no such service
and no focus-filter-like surface to draw over: there is no Home Screen to anchor to, no Control
Centre, no widget host.

So the module splits the two halves and implements each in the place it belongs:

| the framework's half | this module's answer |
| --- | --- |
| **the datastore** - a service that records donations, display counts and invalidations | `Tips.Store`: a plist in the app's own Application Support ((a workflow file kept outside the repository)), read and written through `PropertyListSerialization`; the invalidations survive a relaunch, which is what the framework's own store does |
| **the rules** - `DonationFilter`, `DonatedWithin`, `LargestSubset`, `SmallestSubset`, combined with `&&` or `\|\|` | real: each condition is evaluated over the donations the app has sent, the operators compare as they are named (`equal` … `greaterThanOrEqual`), and a subset condition counts the groups the donations fall into |
| **the eligibility** - `shouldDisplay`, `status`, the display count, the display duration, the display frequency | real: not invalidated, every rule holds, the frequency has passed, the options' count and duration allow it, and `status` is `pending`, `available` or `invalidated` over the same store |
| **the presentation** - a popover the system animates over the app's views | the app's own: `TipUIPopoverViewController` is a real `UIViewController` that loads a `TipUIView` as its view and the app presents it over its own controller; `TipUIView` is a real `UIView` that sizes itself, rounds its corners and draws with the release's own drawing; the collection view and the reusable view are real `UICollectionViewCell`/`UIView` for an app that draws its tip in a list |
| **the events** - `donate()`, `donate(_:)`, `sendDonation(_:)`, `deleteDonations()` | real: they write to the store, and `Store.values(of:)` reads a donation's own fields into the values a rule reads |
| **the configuration** - `Tips.configure(_:)` with the display frequency, the datastore location and the CloudKit container | real: the frequency and the container are recorded in the store; the location names where the app keeps it |

What is *not* there and why:

* **`UIPopoverPresentationController`** - iOS 8's, and the release does not have it. The popover is
  presented by the app over its own controller, which is what the system would have done.
* **the SwiftUI half** - `View.popoverTip(_:arrowEdge:action:)` and its five siblings,
  `View.tipBackground(_:)`, `View.tipBackgroundInteraction(_:)`, `View.tipCornerRadius(_:antialiased:)`,
  `View.tipImageSize(_:)`, `View.tipImageStyle(_:)` (three spellings), `View.tipViewStyle(_:)`,
  `View.tipAnchor(_:)` and `Image.widgetAccentedRenderingMode(_:)`: extensions on `SwiftUI.View` and
  `SwiftUI.Image`, which no release this port builds for has. They belong to the SwiftUI band; the
  module declares `TipView`, the value such a modifier attaches, and the app's own surface draws it.

## What the host differential found, and the three rows that are declared but unreachable

`MacOSX27.sdk` carries `TipKit.framework`, so this module's differential ran against Apple's own
(`the host-differential writeup, **not kept**; its results are in the facts beside this`, (a workflow file kept outside the repository)): the same probe against Apple's
`TipKit` and against this module built as `RevenantTipKit`, 37 lines each, **37 of 37 identical** after
the module name is normalised. What it changed:

1. **`Tips.Status.invalidated` carries its reason.** Both interfaces declare
   `case invalidated(InvalidationReason)` (`TipKit-ios.swiftinterface:682`); this module had a bare
   `case invalidated`, so `Tip.status` could not say why a tip was off the list. The store now answers
   with the reason it recorded, and with the option's own reason when the option ended it:
   `.displayCountExceeded` once `MaxDisplayCount` is reached, `.displayDurationExceeded` once
   `MaxDisplayDuration` has passed. A tip that has merely been *shown* is `.available`, which the old
   code got wrong (it reported `.invalidated` for any shown tip, with nothing to explain it).
2. **`TipKitError` exists** (`Sources/TipKit/Errors.swift`, the ten rows the ledger listed as
   missing). Its `description` and `errorDescription` are the case's own name, which is what Apple's
   own `TipKit` returns — measured, not guessed (`the differential's output, **not kept** (37 of 37, 2026-09-28)`, the `error.`
   rows). The `~=` operator the interface declares is there, so a port may catch a case by name.
   `Tips.configure` matches the interface now: an array (`TipKit-ios.swiftinterface:921`), `throws`,
   and `tipsDatastoreAlreadyConfigured` when the app configures its datastore twice — the datastore
   is one file in the app's own container, so a second call would drop the first configuration.
3. **Which of the three cases this module can raise, and which it cannot.** `configure` raises
   `tipsDatastoreAlreadyConfigured` for real. `missingGroupContainerEntitlements` names a condition
   these releases do not have: an app-group container needs an app-group entitlement and iOS 6 has no
   facility for one. `invalidPredicateValueType` is raised by the typed predicate evaluation, and this
   module's evaluation reads every donated value as text through `RevenantDonationValue`, so a value
   type it does not have cannot arise — a rule it cannot compare answers `false` instead. Both are
   declared because the framework declares them, so a port that catches one compiles; they are not
   raised here, and that is the whole of the difference.

## The subset conditions' two builders, and what the 73 remaining rows are

`build_largestSubset` and `build_smallestSubset` took a third `_ count: Int` argument the interface
does not have: both are two-argument there (`TipKit-ios.swiftinterface:180,191`), and the count is
not an argument of the condition at all — `Foundation.Predicate`'s `largestSubset` takes the other
side of the comparison, and the interface's `LargestSubset` has no count member either. The port now
reads the count the way the framework does: the condition takes the `DonationFilter` the rule wrote on
the other side (`input.value` is how many, `input.op` is which way) and the key path to group by, and
`RevenantDonationCompare` — which already compares numerically — answers it. That is what moved
TipKit from 245 to **247 of 321 placed**.

**What the remaining 73 rows are** ((a workflow file kept outside the repository),
classifier (the row classifier, since removed), run against the digester's own dump):

| how the digester prints it | rows | whose work it is |
| --- | --- | --- |
| printed, under another name | **59** | the ledger's matcher: `==(a:b:)`→`==(_:_:)`, `init?(coder:)`→`init(coder:)`, `subscript(keyPath:)`→`subscript(_:)`, `~=`, and the eight `Tips.GroupBuilder.*` members a result-builder type never gets |
| owner not printed at all | 12 | the cross-module gap (both other modules were on `-I`): `Parameter(_:)` and `Rule(_:_:)`'s neighbours |
| member not printed | 1 | `TipUIPopoverViewController.popoverPresentationController` — UIKit's property is iOS 8, and 6.1.3's `UIViewController` has no such selector to override |
| bare row, no owner | 3 | `Rule(_:_:)` and `Parameter(_:)` are `@freestanding(expression)`/`@attached` **macros** from Apple's `TipKitMacros` plugin (`TipKit-ios.swiftinterface:336`, and the `Parameter` macro beside it) |

So the real gap for this band is **14 rows**, and 13 of them are the `SwiftUI.View` modifiers
(`View.popoverTip(_:arrowEdge:action:)` and its two siblings, `tipImageStyle` ×3, `tipViewStyle`,
`tipAnchor`, `tipBackground`, `tipBackgroundInteraction`, `tipCornerRadius`, `tipImageSize`), which
are the SwiftUI band's: this module draws its popover in `UIView` and `UIViewController` instead, as
`docs/reference/backports/TipKit/TipKit/Rendering.md` says at the top. Counting the four normalisations the ledger can make,
this module is at **247 + 59 = 306 of 321**.
