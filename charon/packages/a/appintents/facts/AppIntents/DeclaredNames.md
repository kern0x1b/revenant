# The names this series declares that the framework's own interfaces do not

**The counts** were measured by `invented-names.py`, a Python census that was deleted with the appintents Python tests. Its history is in `git log -- packages/a/appintents/tests/invented-names.py`; the `--control` refusal and the `--table` output went with it.

**Where the interfaces come from, and why it is a real path.** The first version read three of the
four from `the 26.2 interface copies, **no longer read**: the census reads the machine's own `charon@iphoneos-sdk` 26.2 install*-ios.swiftinterface` -- files that exist only in the band worktree that
extracted them. The review measured the consequence on a **fresh detached checkout**, where those
paths do not exist: the script silently scored TipKit, WidgetKit and ActivityKit as absent from every
interface, and the counts came out **425 in the interfaces / 223 to explain** against the 573/75 it
printed in my worktree. Each path is now a glob under **`charon@iphoneos-sdk`'s own install of 26.2**
-- the machine's copy of the release the rows are written against, and the same files the worktree
copies came from (TipKit 1279, WidgetKit 1785, ActivityKit 676 lines) -- and a glob matching **no**
file exits non-zero naming the pattern, with `--control` as the test of that property. This store holds
three installs of 26.2, so a glob matching several is read in full and the count printed: which copies
were read is never a silent choice either.

**The counts, from a fresh detached checkout at the previous commit** (the run the review asked for,
in `charon/a fresh detached worktree used to re-record the counts, 2026-09-28; **not kept**`, a checkout with none of my `.agent-work/` in it):

| | |
| --- | --- |
| type-level names declared | 648 across AppIntents, TipKit, WidgetKit, ActivityKit |
| in the module's own interface | **584** |
| `Charon`-prefixed (the port's own, by convention) | **44** |
| **to explain, in the table below** | **64** |
| -- of those, **quoted from the SDK** with the hit | 6 |
| -- of those, **invented by this band**, with the reason in the row | **64** |
| the macro plugin's own tree (`packages/a/appintents-macros`) | 8, all ours by construction |

**The first version of this file was wrong and said so in its own text.** It claimed a dotted or
qualified name is "the framework printing it under a qualified spelling"; the review sampled that and
it is false -- `AnyAppEntity` is in no file of the whole 26.2 SDK, and so are `AnyRange`,
`DateResolver`, `IndexRecord`, `FloatResolver`, `ElementResolver` and `IdentityResolver` (the
controls: `RecurrenceRule` scores 6, `AppIntent` 93). Every row now carries **the SDK hit, quoted**,
or says **invented, with the reason**, and the invented count is printed by every run, so a new
invented name cannot pass as a category.

**The three kinds a row can be.** *A quoted SDK hit* -- the framework's own name, in a `.swiftinterface` or
`.swiftdoc`, and the quote says where. **There are none left.** An earlier
version of the script also read C headers, and it is what produced the 36
"quoted" rows: `Never` out of `dlfcn.h`, and names like that. The search is now
Swift interfaces only, and every one of the 64 has no hit in any of them --
which is what the review measured for the names it sampled. *An SDK type in a framework this band does not read* -- `CLPlacemark` (CoreLocation), the
`CSSearchable*` trio (CoreSpotlight, read through the port's headers, see `Spotlight.md`),
the SwiftUI names, `BundleDescription`; the port names these to use them and declares none.
*Invented by this band* -- its own machinery behind a framework type this release does not carry, or
its own state where the framework keeps state in a store that does not exist here; each such row
carries the reason.

| name | hits in the four interfaces | what it is | invented, with reason |
| --- | --- | --- | --- |
| `AnyAppEntity` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- the framework's own erasure is a nested type of `AppEntity`; this one answers to the same name and is the port's own spelling of it |
| `AnyRange` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- the port's own erased range, for the same reason as `AnyAppEntity` |
| `AppShortcutOptionsCollectionSpecificationFor` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a name this band wrote for state the framework keeps in a store this release does not have |
| `AppShortcutParameterPresentationProtocol` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a value or protocol of the framework's *machinery* -- its store, its parameter resolution and its presentation live in a system this release does not have |
| `AppShortcutParameterPresentationSnapshot` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a value or protocol of the framework's *machinery* -- its store, its parameter resolution and its presentation live in a system this release does not have |
| `AppShortcutParameterPresentationTitleBuilder` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a value or protocol of the framework's *machinery* -- its store, its parameter resolution and its presentation live in a system this release does not have |
| `BundleDescription` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a name this band wrote for state the framework keeps in a store this release does not have |
| `Comment` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a name this band wrote for state the framework keeps in a store this release does not have |
| `Continuation` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- the port's own bridge for a resumed intent, since there is no system to resume one |
| `ContinuationError` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- as `Continuation` |
| `ControlStyle` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a value or protocol of the framework's *machinery* -- its store, its parameter resolution and its presentation live in a system this release does not have |
| `CustomLocalizedStringResourceConvertible` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a name this band wrote for state the framework keeps in a store this release does not have |
| `DateComponentsResolver` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a resolver the runtime does not carry -- the Foundation Swift r2 types are not in this release's Foundation (see the Foundation gate line in the queue), so the port writes one and gates it |
| `DateResolver` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a resolver the runtime does not carry -- the Foundation Swift r2 types are not in this release's Foundation (see the Foundation gate line in the queue), so the port writes one and gates it |
| `ElementResolver` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a resolver the runtime does not carry -- the Foundation Swift r2 types are not in this release's Foundation (see the Foundation gate line in the queue), so the port writes one and gates it |
| `EntityQueryComparatorProtocol` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a name this band wrote for state the framework keeps in a store this release does not have |
| `EntityQueryPropertyValue` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a name this band wrote for state the framework keeps in a store this release does not have |
| `FloatResolver` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a resolver the runtime does not carry -- the Foundation Swift r2 types are not in this release's Foundation (see the Foundation gate line in the queue), so the port writes one and gates it |
| `IdentityResolver` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a resolver the runtime does not carry -- the Foundation Swift r2 types are not in this release's Foundation (see the Foundation gate line in the queue), so the port writes one and gates it |
| `IndexRecord` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- the port's own record of a donation's index entry; the framework keeps that state in its own store |
| `IntentChoiceRequest` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a value or protocol of the framework's *machinery* -- its store, its parameter resolution and its presentation live in a system this release does not have |
| `IntentConfirmationRequest` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a value or protocol of the framework's *machinery* -- its store, its parameter resolution and its presentation live in a system this release does not have |
| `IntentDonation` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a value or protocol of the framework's *machinery* -- its store, its parameter resolution and its presentation live in a system this release does not have |
| `IntentDonationStore` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a value or protocol of the framework's *machinery* -- its store, its parameter resolution and its presentation live in a system this release does not have |
| `IntentItemBuilder` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a value or protocol of the framework's *machinery* -- its store, its parameter resolution and its presentation live in a system this release does not have |
| `IntentItemSectionBuilder` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a value or protocol of the framework's *machinery* -- its store, its parameter resolution and its presentation live in a system this release does not have |
| `IntentModesFlags` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a value or protocol of the framework's *machinery* -- its store, its parameter resolution and its presentation live in a system this release does not have |
| `IntentParameterValueRange` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a value or protocol of the framework's *machinery* -- its store, its parameter resolution and its presentation live in a system this release does not have |
| `Kind` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a name this band wrote for state the framework keeps in a store this release does not have |
| `LocalizedStringResource` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a name this band wrote for state the framework keeps in a store this release does not have |
| `NeverSummary` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a name this band wrote for state the framework keeps in a store this release does not have |
| `NumericFormat` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a name this band wrote for state the framework keeps in a store this release does not have |
| `RelevantIntentStore` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a name this band wrote for state the framework keeps in a store this release does not have |
| `Request` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a name this band wrote for state the framework keeps in a store this release does not have |
| `RoundingRule` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a name this band wrote for state the framework keeps in a store this release does not have |
| `Section` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a name this band wrote for state the framework keeps in a store this release does not have |
| `Storage` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a name this band wrote for state the framework keeps in a store this release does not have |
| `UUIDResolver` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a resolver the runtime does not carry -- the Foundation Swift r2 types are not in this release's Foundation (see the Foundation gate line in the queue), so the port writes one and gates it |
| `WidgetKind` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a name this band wrote for state the framework keeps in a store this release does not have |
| `ArrowEdge` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a name this band wrote for state the framework keeps in a store this release does not have |
| `BackgroundStyle` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a name this band wrote for state the framework keeps in a store this release does not have |
| `Code` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a name this band wrote for state the framework keeps in a store this release does not have |
| `EmptyTip` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a name this band wrote for state the framework keeps in a store this release does not have |
| `Image` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a name this band wrote for state the framework keeps in a store this release does not have |
| `Kind` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a name this band wrote for state the framework keeps in a store this release does not have |
| `Message` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a name this band wrote for state the framework keeps in a store this release does not have |
| `Store` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a name this band wrote for state the framework keeps in a store this release does not have |
| `Tips.Store` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a name this band wrote for state the framework keeps in a store this release does not have |
| `Title` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a name this band wrote for state the framework keeps in a store this release does not have |
| `ActivityViewContextPlaceholder` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a name this band wrote for state the framework keeps in a store this release does not have |
| `AnyWidgetConfigurationIntent` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- the port's own erasure of a framework type, so a value of it can be named |
| `Base` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a name this band wrote for state the framework keeps in a store this release does not have |
| `BodyType` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a name this band wrote for state the framework keeps in a store this release does not have |
| `CGSizeLike` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a name this band wrote for state the framework keeps in a store this release does not have |
| `ControlWidgetButtonContext` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a value or protocol of the framework's *machinery* -- its store, its parameter resolution and its presentation live in a system this release does not have |
| `ControlWidgetDescriptionContext` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a value or protocol of the framework's *machinery* -- its store, its parameter resolution and its presentation live in a system this release does not have |
| `IntentTimelineProviderContext` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a value or protocol of the framework's *machinery* -- its store, its parameter resolution and its presentation live in a system this release does not have |
| `Island` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a name this band wrote for state the framework keeps in a store this release does not have |
| `Kind` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a name this band wrote for state the framework keeps in a store this release does not have |
| `WidgetBody` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a name this band wrote for state the framework keeps in a store this release does not have |
| `WidgetView` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a name this band wrote for state the framework keeps in a store this release does not have |
| `_WidgetFamilyProviding` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a name this band wrote for state the framework keeps in a store this release does not have |
| `AvailabilityReader` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a name this band wrote for state the framework keeps in a store this release does not have |
| `FrequentPushReader` | **no hit in any SDK interface or header** | a name this band wrote | **yes** -- a name this band wrote for state the framework keeps in a store this release does not have |
<!-- 64 invented, 64 to explain -->
