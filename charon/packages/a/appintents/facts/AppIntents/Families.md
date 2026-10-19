# The open rows, family by family — as the ledger's header has them

The header decides the rows: `coordination/corpus/ledger/AppIntents.tsv` currently carries **80**
rows, and this file walks them by the family the `api` column names. A row is a row the ledger
carries; nothing here adds one, and a family that is a measurement gap says so rather than being
worked.

## `AppEntity` — 4 rows: two placed, two the ledger names by the wrong owner

| row | state |
| --- | --- |
| `AppEntity.defaultQuery` | **placed by declaration** — a protocol *requirement*, `static var defaultQuery: Self.DefaultQuery { get }` (`arm64e-apple-macos.swiftinterface:413-416`), with the transient conformance's default in an extension |
| `AppEntity.defaultResolverSpecification` | **placed by declaration** — an `extension AppEntity` member, not a requirement (`:423-425`), which replaced nine per-type declarations of the same thing |
| `AppEntity.displayRepresentation` | **a measurement row**: declared by `InstanceDisplayRepresentable` (`:3819-3821`), which `DisplayRepresentable` refines and `AppEntity` refines through it. The port covers it *through that protocol* (`Display.swift:19-20`). The digester prints it under the declaring protocol and prints nothing for the inheriting one |
| `AppEntity.id` | **a measurement row**: declared by `Identifiable`, a Swift standard library protocol, outside this module's interface entirely; the port's own `AppEntity` refines it |

So the family is closed on declarations, and the two that remain are the ledger naming a member on
a protocol that only inherits it — which is a fact about the measurement, not about this module.
`Open-contracts.md` carries the same two rows with the check that looked for the class in all four
modules (zero in TipKit, WidgetKit and ActivityKit).

## The families that are gates, not work

| family | rows | why they are not this band's |
| --- | --- | --- |
| `AttributedStringFromStringResolver` | 7 | the whole type is behind `CHARON_APPINTENTS_ATTRIBUTED_STRING`, and the recipe's own probe measures that this release has no `AttributedString` |
| `Measurement`, `Calendar`, `AttributedString` | 12 | Foundation Swift r2's types, gated behind the probes in `xmake.lua:118-133`; the probe is what says `'Measurement' is only available in iOS 10.0 or newer` |

## The families that are a measurement gap

| family | rows | why nothing here makes them place |
| --- | --- | --- |
| `IntentItem.Builder`, `IntentItemSection.Builder` | 7 | the digester prints a `@resultBuilder` type with **no members at all** — measured on these two and on `Tips.GroupBuilder` in the kits |
| `EntityQueryProperties.init(…)`, `EntityQuerySortingOptions.init(…)`, the `subscript(index:)` rows | 5 | the declarations are there (`Queries.swift:371,376,436,440`) and the rows differ by a generic parameter list or a subscript's label — normalisations 5 and 3 of the handoff |
| `IntentPerson.Handle` and the other four nested types | 4 | the digester prints a type's cases and `hashValue` and no equality member, with three refuted attempts recorded |

## The families that are another band's, or Apple's

`CSSearchableItem`, `CSSearchableIndex`, `NSUserActivity` — the CoreSpotlight and Spotlight rows;
the `CSSearchable*` three each are placed by the registry fix (`scriptdir()` → `package:scriptdir()`)
and the overlay, and `NSUserActivity` is the Objective-C framework this band does not touch.
`AppEntity(schema:)` and `AppEnum(schema:)` are Apple's macro plugin, open by the ruling with the
reason in `Macros.md`. `IntentFile.data(contentType:)` and `.file(contentType:destinationDirectory:)`
are placed by the two factories this series added. `ForegroundContinuableIntent` and the tail are
recorded in `Unplaced.md` with their measurements.

## What the 80 rows are worth

`2045 / 2323` was measured against a 2323-row ledger; `14 / 80` against this one. **They are not
comparable** and this file does not add them together. The rule is `rows - missing - wrong-kind =
placed`, checked against the `<F>-missing.tsv` beside the number, and a header that moves invalidates
every count measured against the old one.
