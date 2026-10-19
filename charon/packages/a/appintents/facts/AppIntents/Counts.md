# The counts, and the ledger they are measured against

`2323 - 261 - 17 = 2045` is this module's placement against the **2323-row** corpus ledger, measured
with the toolchain's own `swift-api-digester -dump-sdk` of the module built for `armv7-apple-ios6.1.3`.

`coordination/corpus/ledger/AppIntents.tsv` now holds **80 rows**, so a run of the same measurement
against it answers a different question — 13 placed, 67 missing — and the two are **not comparable**.
The row set moved under this series; the placement numbers above are the ones measured against the row
set that had 2323, and this file says which is which so that a reader does not compare them.

The rule the kits' run directory states and this file repeats: `rows - missing - wrong-kind = placed`,
each line checked against the `<F>-missing.tsv` beside it. A table written from memory drifts — TipKit
read 247/73 once while its own TSV held 75 missing, and 321 − 75 − 1 is 245.

What moved and what did not, for this module: the last measured steps were the CoreSpotlight registry
fix (all seven `CSSearchable*` rows), the three `EntityProperty` initialisers, `AppEntity`'s
`defaultQuery` requirement, and the two `IntentFile` factories — 2032 → 2045. The comparator work
(the twenty always-true equalities and the twenty-six empty hashes, now zero) moved no row, because
the digester does not print an enum's `==`; that is behaviour, not count, and
`facts/AppIntents/Comparators.md` is where it is read.
