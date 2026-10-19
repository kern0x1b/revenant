# The open AppIntents rows, and what each one needs

What the rows are, and what settles each of them. Every entry names the interface line that settles
it, or says that the interface does not — the 26.2 interface the rows are written against is not on
this machine, so the reference read here is the macOS 27 SDK's
`arm64e-apple-macos.swiftinterface`, and where a row's own spelling in the ledger differs from it that
is noted. No header text is reproduced: a type's declarations are cited by line, not copied.

The rows are the 261 in `the missing-rows list, **regenerated** from the corpus ledger and a digester dump, not kept`, measured against the
2323-row ledger (see `Counts.md` for the row set this was measured with).

## 1. Rows that name a member the protocol only inherits — 2 rows, and a class

| row | what settles it |
| --- | --- |
| `AppEntity.displayRepresentation` | declared by **`InstanceDisplayRepresentable`**, not by `AppEntity` (`:3819-3821`: `var displayRepresentation: DisplayRepresentation { get }`), which `DisplayRepresentable` refines (`:3789`) and `AppEntity` refines through it (`:413`) |
| `AppEntity.id` | declared by **`Identifiable`**, a Swift standard library protocol, and inherited by `AppEntity` through the same refinement chain (`:413`) |

Measured against the digester's own dump: it prints `displayRepresentation` under
`AppIntents.InstanceDisplayRepresentable` and prints **nothing** for `AppIntents.DisplayRepresentable`
or for `AppIntents.AppEntity` — an inherited member is not printed on the inheriting protocol. So a row
may name a protocol that only inherits what the row names, and the digester will not print it there.
This is the smallest member of that class in this module, and the class is worth the ledger band
checking across all four modules before anything else: a row on a refining protocol is not evidence
that the declaration is absent.

## 2. A row that is an extension member, not a requirement — 1 row

| row | what settles it |
| --- | --- |
| `AppEntity.defaultResolverSpecification` | an `AppEntity` **extension** member, `public static var defaultResolverSpecification: EmptyResolverSpecification<Self> { get }` (`:423-425`), with a second, `some ResolverSpecification` one for `Self: AppEnum` (`:427-430`). It is not a protocol requirement, so it belongs in an `extension AppEntity`, and the port declares it on individual types instead |

**This one is implementable and is now written**: `extension AppEntity` carries
`defaultResolverSpecification` returning `EmptyResolverSpecification()`, which is the interface's shape
(`Entity.swift`, after the `AppEntity` protocol's own body). It matters that it is an *extension*
member: the port had `defaultResolverSpecification` on nine individual types — an entity's identifier,
its schema, a parameter, a donation, and the resolvers — and the framework gives it to **every**
entity once, with a second, `some ResolverSpecification` one for `Self: AppEnum` (`:427-430`). A
conformance that wants another specification names its own beside it.

**The other three rows of the family, and their status:**

| row | status |
| --- | --- |
| `AppEntity.displayRepresentation` | covered through the declaring protocol (`Display.swift:19-20`, `InstanceDisplayRepresentable`), and it is a *measurement* row, not a missing declaration — see §1 |
| `AppEntity.id` | covered through `Identifiable`, which the port's own `AppEntity` refines; nothing to add, and nothing to find in this module's sources |
| `AppEntity(schema:)` | open by the coordinator's ruling of 2026-09-28, with the reason in `Macros.md`: the interface names the `memberAttribute` role and not the attribute it adds, and Apple's expansion is not on this machine |

**Measured, and it places.** The module compiles for `armv7-apple-ios6.1.3` with the extension member
in it -- 0 errors, `object 2056252 bytes`, through `heavy.sh` (`the device compile, **now `packages/a/appintents/xmake.lua`'s own flags**; the script is not kept`),
and the digester's dump of that build has the member. Against the **80-row** corpus ledger the
module goes from 13 placed to **14**, and `AppEntity.defaultResolverSpecification` is no longer in
`AppIntents-missing.tsv`; the four rows that carry that name and are still there belong to other
owners: `AppEnum` (the `Self: AppEnum` overload, `:427-430`), and `AttributedString`,
`Calendar.RecurrenceRule` and `Measurement` (the Foundation Swift r2 types, gated at this release).

The number is against the 80-row ledger and is **not comparable** with the 2045/2323 in
`Counts.md`, which was measured against the 2323-row ledger; that file says so and this does not
repeat the old total.

## 3. Rows the digester never prints — 41 rows, and three refuted ways of making them print

| rows | what settles it |
| --- | --- |
| `IntentParameter.<Unit>.==(a:b:)` for 26 unit types and `ValueState.==(lhs:rhs:)` — **27** | the digester prints each type's cases and `hashValue` and no equality member. Three hypotheses were tried on the built module and all three are refuted: not enums only (`IntentPerson.Handle` is a struct), not synthesised only (`IntentParameter.Acceleration` declares its `==` in `Units.swift:21`), not nesting in a generic type (`InputConnectionBehavior` is top-level). The discriminator is not identified |
| `IntentPerson.Handle`/`.Handle.Value`/`.Handle.Label`/`.Name`/`.Identifier` — 14, of which the 5 `==` are **placed by a typecheck call site** and the 8 `init(from:)`/`encode(to:)` are here | same behaviour, same refutations. The `==` rows were placed by `the equality probe, **now `packages/a/appintents/tests/probe-appintents-equality.swift`**` typechecking against Apple's AppIntents and against this module, both exit 0; the coding members need a call site, and a call site for them needs an *instance* of each type |
| `AttributedStringFromStringResolver` — 7, and it is not this one | **all three are declared**: `==` and `hash(into:)` come from `Resolver: Hashable, Sendable` (the port's own `Resolver` carries it, `Values.swift:210`) and `resolve(from:context:)` is at `Gated.swift:53`. The 7 rows are the *gated* ones: the whole type is behind `CHARON_APPINTENTS_ATTRIBUTED_STRING`, and the recipe's own probe measures that this runtime has no `AttributedString` |

## 4. Rows that are another band's — 16 rows

`String.IntentInputOptions.CapitalizationType.==(a:b:)`, `Measurement` ×4, `Calendar` ×4,
`AttributedString` ×4: the Foundation Swift r2 types, gated in `Sources/AppIntents/Gated.swift` behind
`CHARON_APPINTENTS_ATTRIBUTED_STRING`, `CHARON_APPINTENTS_MEASUREMENT` and
`CHARON_APPINTENTS_RECURRENCE_RULE`, each measured by a probe in `xmake.lua:118-133` and not assumed.
The probe is what says `'Measurement' is only available in iOS 10.0 or newer` on this release, so the
rows are `missing` by the truth and belong to the Foundation port.

## 5. Rows the digester prints under another name — 106 rows

Documented once, with the five normalisations and the per-module counts, in
`.agent-work/handoffs/2026-09-28-ledger-swift-digester-naming.md`. Of the 106, 68 are
`IntentParameter.init`'s generic parameter list, which the digester does not print at all; the rest are
`==(a:b:)`→`==(_:_:)`, `init?(coder:)`→`init(coder:)`, `subscript(keyPath:)`→`subscript(_:)` and `~=`.
Of the families below, the comparators (`ContainsComparator` ×5, the three other comparators ×6) and
`IntentParameterSummary.init(_:table:…)` are entirely of this kind: the declarations are there and the
spelling is the ledger's to normalise.

## 6. Rows that are Apple's macro plugin — 16 rows

`AppEntity(schema:)`, `AppIntent(schema:)`, `AppEnum(schema:)`, `AssistantEntity/Enum/Intent(schema:)`,
`ComputedProperty()` ×5, `DeferredProperty()` ×2, `UnionValue()`. The contracts are in
`Macros.md`, the four `memberAttribute` rows are open by the coordinator's ruling with the reason, and
the plugin itself is the series in `packages/a/appintents-macros/`.

## 7. Rows that are a result-builder type's members — 9 rows

`IntentItem.Builder.buildArray(_:)`, `.buildBlock()`, `.buildBlock(_:)`, `.buildExpression(_:)`,
`IntentItemSection.Builder.buildBlock()`/`.buildBlock(_:)`,
`IntentParameterSummary.ParameterKeyPathsBuilder.buildBlock(_:)`/`.buildExpression(_:)`. The digester
prints a `@resultBuilder` type with **no members at all** — measured on `Tips.GroupBuilder` in the kits
and on these three here — so the declarations are there and nothing makes them appear.

## 8. Rows the port declares, of the same class as §3 — 5 rows

`DisplayRepresentation.==(a:b:)`, `DisplayRepresentation.Image.==(a:b:)` and
`DisplayRepresentation.Image.DisplayStyle.==(a:b:)`, `IntentFile.==(a:b:)` and
`IntentFile.IntentFileError.==(a:b:)`. `DisplayRepresentation` **is** Equatable in the interface
(`:3845`, `ExpressibleByStringLiteral, Equatable`) and is Equatable in the port (`Display.swift:81`);
`IntentFile` is a `Hashable` struct (`Items.swift:157`). So these are the class of §3 — a member the
digester does not print — and not a missing declaration.

## 9. What the ledger's spelling adds that the macOS 27 interface does not — 2 rows

`IntentParameterSummary.init(_:table:<Intent>.ParameterKeyPathsBuilder:)` and
`IntentParameterSummary.init(<Intent>.ParameterKeyPathsBuilder:)` name a **result-builder type** as a
parameter. The port's initialisers take that builder (`Queries.swift:371,436`), and macOS 27's interface
prints `IntentParameterSummary` with the same builder parameters, so these are spelling and not shape.
They move with normalisation 5.

## The one implementable row in this list, and the one decision

`AppEntity.defaultResolverSpecification` (§2) is the only row here whose fix is a declaration rather
than a normalisation, a gate or another band's, and it is written down with the interface line that
settles it. The decision that is not mine is §6's four `memberAttribute` rows: the interface names the
role and not the attribute, Apple's expansion is not on this machine, and the coordinator's ruling of
2026-09-28 is that they stay unimplemented with the reason on the row.

## The inherited-member check, run across all four modules

The §1 rows are a class, and the class was looked for in all four modules rather than assumed to be
two rows. The method: for every row in each module's `<F>-missing.tsv`, take the member's own name,
find the protocols that *declare* a member of that name in that module's interface, and walk the
row's owner's refinement chain to see whether the declaring protocol is on it. Interfaces read:
`AppIntents.framework/Modules/AppIntents.swiftmodule/arm64e-apple-macos.swiftinterface` (the macOS 27
SDK, since the 26.2 one is not on this machine) and this package's own copies of the three kit
interfaces in `the 26.2 interface copies, **no longer read**: the census reads the machine's own `charon@iphoneos-sdk` 26.2 install`.

| module | rows that name an inherited member | which protocol declares it | does the port cover it through that protocol |
| --- | --- | --- | --- |
| **AppIntents** | `AppEntity.displayRepresentation` | **`InstanceDisplayRepresentable`** (`:3819-3821`), reached `AppEntity` → `DisplayRepresentable` (`:3789`) → `InstanceDisplayRepresentable` | **yes** — `Display.swift:19-20` declares `InstanceDisplayRepresentable` with `var displayRepresentation` and the port's own `DisplayRepresentable` refines it, so the declaration is under the protocol the interface names |
| **AppIntents** | `AppEntity.id` | **`Identifiable`**, a Swift standard library protocol — *outside this interface entirely*, which is why no scan of it finds the row | **yes**, through `Identifiable` itself: the port's `AppEntity` refines `Identifiable` (`:10` in `Entity.swift`), and `id` is that protocol's own requirement. There is nothing to add, and nothing to find in this module's sources |
| **AppIntents** | `AppEnum.defaultResolverSpecification`, `URLRepresentableEntity.urlRepresentationParameter`, `URLRepresentableEnum.urlRepresentationParameter` | not inherited rows: the first is an **`extension AppEnum` member** (`:427-430`), the same shape as `AppEntity.defaultResolverSpecification` in §2, and the other two are declared by `CustomURLRepresentationParameterConvertible` (`:10392`) which `URLRepresentableEntity` (`:10439`) and `URLRepresentableEnum` (`:10484`) both **refine directly** | **yes** for the pair — `Remaining.swift:264,270,275` implements `urlRepresentationParameter` on the three conforming types the port has (`String`, `Int`, `URL`), which is exactly the set `CustomURLRepresentationParameterConvertible` asks for |
| **TipKit** | **0** | — | every one of its 73 open rows is naming-gap, gated, cross-module, a macro, a builder member, or the `==` omission |
| **WidgetKit** | **0** | — | its 100 are the same, plus the SwiftUI rows routed to the SwiftUI band |
| **ActivityKit** | **0** | — | its 10 are eight operator spellings, three enums the digester does not print equality for, and three it prints under the ledger's own name |

**What the check settles.** Two of the four AppIntents rows in §1 are real and the port covers both
through the declaring protocol — so they are *measurement* rows, not missing declarations, and the
port is not to touch them. The other two in the fourth line are not inherited rows at all: one is the
extension-member shape §2 already covers, and one is a direct refinement the port implements on the
three types that conform. And the three kits have no rows of this class, so the ledger band can stop
looking for them there.

**The method's own limit, stated.** It matches on the *member's name* and walks refinements read from
the interface's own text; it cannot see a member declared by a protocol in another module (the
`Identifiable` case above is found by hand for that reason) and it cannot see a member the interface
prints only in a private interface. A row it does not report is therefore "not found this way", not
"not a row of this class".
