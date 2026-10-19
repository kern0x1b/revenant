# The next whole family: the census, the pick, and the order — before any code

The header decides the rows: `coordination/corpus/ledger/AppIntents.tsv` carries **80**. This is the
census of what is *uncarried* per family, ordered by size, with what each family's rows actually are,
so the pick is a consequence of the table and not a preference. **No code in this commit.**

| family | rows | what the rows are |
| --- | --- | --- |
| `AttributedStringFromStringResolver` | 7 | **gated**: Foundation's `AttributedString`, absent from the runtime |
| `IntentItem` | 4 | **readable**: the declarations are present; the digester prints a `@resultBuilder` type's no members |
| `IntentPerson` | 4 | **readable**: four coding rows, placed by a call-site typecheck |
| `AppEntity` | 4 | **readable**: two placed by declaration, two rows that name a member on a protocol which only inherits it |
| `AttributedString` | 4 | **gated**: the same type |
| `Calendar` | 4 | **gated**: `Calendar.RecurrenceRule` is iOS 10+, and `Calendar.swift` is in the runtime's `still_ios7` |
| `Measurement` | 4 | **gated**: absent, and `swift-runtime/xmake.lua:39` records why |
| `IntentItemSection` | 3 | **readable**: the same result-builder gap, after the `Builder` typealias |
| `CSSearchableIndex` | 3 | **placed** by the registry fix and the overlay |
| `CSSearchableItem` | 3 | **placed** by the same |
| `FileEntityIdentifier` | 2 | normalisation family |
| `ForegroundContinuableIntent` | 2 | **readable**: recorded in `Unplaced.md` |
| `IntentFile` | 2 | **placed** by the two factories |
| `IntentParameterSummary` | 2 | normalisation 5, the generic parameter list |
| `NSUserActivity` | 2 | **another band's**: the Objective-C framework this band does not touch |
| the 19 schema-macro rows (`AppEntity(schema:)` … `UnionValue()`) | 19 | **Apple's plugin**: open by the ruling, with the contracts in `Macros.md` |
| the tail (`Bool`, `EntityQueryProperty`, `StringSearchCriteria`, `TransientAppEntity`, the comparator, `AppIntentError`, the URL-representation pair, `DynamicOptionsProvider`, `StartWorkoutIntent`, `OpenURLIntent`, `ParameterSummaryCaseBuilder`, `CSSearchableItemAttributeSet`, `IntentParameter`) | 15 | mixed: normalisation, a gate, or a reading — each in `Unplaced.md` |

## The pick, and why

**The largest family is `AttributedStringFromStringResolver` at 7, and it is the one family I must
not pick**: all seven rows are behind `CHARON_APPINTENTS_ATTRIBUTED_STRING`, and that flag is defined
only when a probe finds `AttributedString` in the runtime — which no installed runtime has
(`LocalizedStringResource` and `AttributedString` alike: zero hits in every
`…/lib/swift/iphoneos` in the store). It is the Foundation Swift family's, and the queue line says so.
Neither the 4-row gated families nor the 19 macro rows are mine to lift: one waits on the Foundation
band, the other on the addon release.

**So the pick is `IntentItem` + `IntentItemSection` — 7 rows together — as the largest family that is
neither renderer- nor hardware-bound and not gated.** `IntentPerson` (4) is already placed, `AppEntity`
(4) is closed on declarations, `CSSearchable*` (6) and `IntentFile` (2) are placed, and the tail is a
row at a time. `IntentItem`'s and `IntentItemSection`'s declarations are **already there** — the
digester simply prints a `@resultBuilder` type with no members — so this family is *readings*, not
code, and it needs one device compile to settle.

## The order of work, before any code

1. **One device compile of the module** (a heavy job; launch under `heavy.sh` only at `uptime` load1
   below 12, and kill the pid if the log says `waiting`). Without it no probe can read the current
   module, because the store's build predates the `IntentItemSection.Builder` typealias.
2. **Typecheck `probe-intembuilder.swift`** — four member references in the framework's spelling.
   Green places `IntentItem.Builder`'s four rows.
3. **Typecheck `probe-itembuilder.swift`** — the type and its two `buildBlock` overloads. Green places
   `IntentItemSection.Builder`'s three rows.
4. Then, from the tail and by size: `ForegroundContinuableIntent` (2), `FileEntityIdentifier` (2),
   `EntityQueryProperty` / `StringSearchCriteria` / the comparator / `AppIntentError`, each with the same
   call-site reading, one wip each.
5. The 19 macro rows and the 19 gated rows stay where they are: the first needs the addon release,
   the second the Foundation Swift family.
