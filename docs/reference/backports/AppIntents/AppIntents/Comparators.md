# The comparison operators: nine equalities that answered `true` for every pair

Twenty-nine `==` in this module were written `{ return true }`, and twenty-six `hash(into hasher:)`
were written `{}`. Both are the fabricated answer the API push's rules forbid, and both are wrong in
a way a port acts on: a query compares **the operator a rule wrote** with **the one it runs**, so
`ComparableComparisonOperator.lessThan == .greaterThan` returning `true` means a rule written
`lessThan` runs as `greaterThan` and matches. A hash that tells no two values apart puts every value
of a type in one bucket, so a dictionary keyed by a shortcut tile colour or a phrase token has one
key however many values it holds.

**Nine of the twenty-nine are fixed** — the types whose cases are a plain list, each now carrying an
`ordinal` and both members made of it, which is the shape this port already used for
`Tips.InvalidationReason`:

| type | cases | file |
| --- | --- | --- |
| `HasValueComparisonOperator` | 2 | `Queries.swift` |
| `EquatableComparisonOperator` | 2 | `Queries.swift` |
| `OneOfComparisonOperator` | 1 | `Queries.swift` |
| `ComparableComparisonOperator` | 4 | `Queries.swift` |
| `StringComparisonOperator` | 4 | `Queries.swift` |
| `EntityQueryComparatorMode` | 2 | `Queries.swift` |
| `AppShortcutPhraseToken` | 1 | `Shortcuts.swift` |
| `ShortcutTileColor` | 16 | `Shortcuts.swift` |
| `SetFocusFilterIntentError` | 2 | `SystemIntents.swift` |

**Measured two ways.** The call sites are in `the comparator probe, **now `packages/a/appintents/tests/probe-comparators.swift`**`: twelve
questions — does an operator equal itself, does it equal its neighbour, does a tile colour equal
itself and its next — which **typecheck against Apple's AppIntents** on the host (0 errors, and
`apple-comparators.txt` has Apple's twelve answers) **and against this module** for
`armv7-apple-ios6.1.3` (0 errors). The port's *answers* cannot be measured on this machine: the
module does not build for the host (53 errors, the same wall as ActivityKit's and WidgetKit's
differentials) and there is no iOS runtime here, so the behaviour half of this family needs an
emulator run and the declaration half is what the typecheck settles.

**The other twenty are gone too, and the reason is the opposite of the nine's.** Read each type's
conformance in Apple's own interface (`arm64e-apple-macos.swiftinterface`) and they split two ways:

* the **payload enums** — `IntentFileError`, `EntityQuerySort.Ordering`, the two
  `StringInterpolation.Token`s — are `Equatable` in Apple's API, through a separate
  `extension X : Swift::Equatable {}` (which is how the printer spells a synthesised conformance), and
  they are fixed by the same `ordinal` as the nine;
* the **resolvers** — `DoubleFromStringResolver`, `IntResolver`, `URLFromStringResolver`,
  `StringFromIntResolver`, `BoolFromStringResolver`, `DoubleFromIntResolver`, `DoubleResolver`,
  `StringFromDoubleResolver`, `EmptyResolverSpecification`, `AttributedStringFromStringResolver`,
  `StringSearchCriteriaFromStringResolverSpecificification`, and the six in
  `Values+Foundation.swift` — get their equality from **`Resolver : Swift::Hashable, Sendable`**, and
  the port's own `Resolver` already carries the same refinement (`Values.swift:210`). Every one of
  those structs has no stored property, so what the compiler synthesises from the requirement *is*
  the answer Apple gets: equal to its own kind, and a constant hash. The hand-written pair was
  overriding that synthesis with a literal `true` and an empty `hash(into:)`, which is why the answer
  looked right and the declaration was still fabricated. **The members are deleted, not rewritten,
  and the protocol's requirement stands on its own.**

**Nothing is left, so there is no crutches.md entry for this family.** The count of
`== { return true }` and of `hash(into:) {}` in the module is zero, measured after the last build:

```
$ grep -rc "static func == (.*) -> Bool { return true }\|func hash(into hasher: inout Hasher) {}" … | grep -v :0 | wc -l
0
```

The measurement does not move — the digester does not print an enum's `==` — and the row count stays
**2043 of 2323**: what changed is what the module answers, and the probe that asks is in
`the comparator probe, **now `packages/a/appintents/tests/probe-comparators.swift`**`. The port's *answers* still want an emulator run, which
this machine has not had yet.
