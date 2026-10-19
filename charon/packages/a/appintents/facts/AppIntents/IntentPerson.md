# `IntentPerson` — the rows, and how each is settled

The corpus ledger carries **four** rows for this family today, and they are all the coding member of
one of the four nested types:

| row | settled by |
| --- | --- |
| `IntentPerson.Name.encode(to:)` | a call site in the framework's spelling, typechecked against this module |
| `IntentPerson.Identifier.encode(to:)` | the same |
| `IntentPerson.Handle.Value.encode(to:)` | the same |
| `IntentPerson.Handle.Label.encode(to:)` | the same |

**The declarations are there.** `IntentPerson.Handle` is `Hashable, Sendable, Codable` and its nested
`Value` and `Label` are `String`-backed and `Codable`, so the compiler synthesises `encode(to:)` and
`init(from:)` for all four types. **The digester prints none of them** — it prints a type's cases and
`hashValue` and no coding or equality member for these types — which is the behaviour whose cause is
still unidentified after three refuted attempts (`Open-contracts.md` §3, and the handoff's finding 6).

So they are measured the way the coordinator set for exactly this case: a **call site in the
framework's spelling**, `the coding probe, **now `packages/a/appintents/tests/probe-intentperson-coding.swift`**`, which takes each type and
references `type.encode(to:)`. A reference is the test — it proves the member exists, with that name
and that signature, without inventing a value to encode — and it **typechecks with 0 errors** against
this module for `armv7-apple-ios6.1.3` with the recipe's own flags. By the criterion the coordinator
ruled on 2026-09-28, the four rows are placed.

The earlier probe of the same kind placed this family's five `==` rows, so the family is closed on
call sites: nine rows, none of which the digester can see, all of which this module declares with the
framework's spelling.

**What would close the rest of the class** is the digester printing a synthesised member, or the
ledger matching on a declaration rather than on a printed name. Neither is this band's, and both are
named in `.agent-work/handoffs/2026-09-28-ledger-swift-digester-naming.md`.
