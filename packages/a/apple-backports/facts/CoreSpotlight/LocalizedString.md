# CSLocalizedString: which localization is chosen

`CSLocalizedString` holds a dictionary of strings keyed by language identifier and answers one of them. It is not
implemented yet: the rule that chooses the key is not pinned, so the class is not in the registry. This file records the
measurements the rule has to meet, so the next session starts from them.

The answers are the host's, measured with a scratch program (not committed) that builds one `NSDictionary` per key set,
sets the preferred languages with the `-AppleLanguages` launch argument, and asks NSBundle's matcher
(`preferredLocalizationsFromArray:forPreferences:`) for the list it returns. The table has 966 rows: 23 preference lists
(v01 to v23) against 42 key sets, with the enumeration order of each dictionary and the matcher's list recorded per row.
The table is not committed; its counts and failing rows are below.

## What holds

- An exact match of the first preference is chosen, in every row where the first preference has a key.
- When no preference has a key of its language, the first key of the dictionary's own enumeration is chosen, for every
  row whose key set has no English key (no misses in those rows).
- Where the first preference's language has keys, the nearest of them is chosen by the CLDR parent chain of that
  preference (`en_AU` to `en_001` to `en`; `en_GB` is in `en_001`, `en_US` is not). This is the rule the coordinator
  stated; over the 608 rows in which the chain finds a key, it predicts 603 correctly (the five below are the rest).

## What does not hold

Five rows break the ordering "first preference, then parent-chain distance" (keys, preferences, measured, predicted):

- `en_US`, `en_GB` | `en-AU`, `en-US` | `en_US` | `en_GB`
- `en_GB`, `en_US` | `en-AU`, `en-US` | `en_US` | `en_GB`
- `en`, `en_GB`, `en_US` | `en-AU`, `en-US` | `en_US` | `en_GB`
- `en_US`, `en_AU` | `en-GB`, `en-US` | `en_US` | `en_AU`
- `en_AU`, `en_US` | `en-GB`, `en-US` | `en_US` | `en_AU`

In each, the second preference `en-US` has an exact key and beats a region of the first preference's language. The same
second preference does not win over a bare `en` key (`en`, `en_US` with `en-AU`, `en-US` measures `en`), and adding
`en_GB` to that key set changes the result to `en_US`. No ordering of tiers over (preference, tier) pairs gives both
results, so the rule needs a further input from the matcher that these rows do not show.

The English no-match case does not follow the enumeration either. With no preference matching, English keys are chosen
as follows (measured): `en_US` whenever it is a key; otherwise the order of the matcher's list with `en_US` appended to
the preferences. Examples: `en_AU`, `en_GB` gives `en_GB` (enumeration first would give `en_AU`); `en_IN`, `en_CA` gives
`en_CA`; `en_NZ`, `en_ZA` gives `en_ZA`; `en_NZ`, `en_IE`, `en_SG` gives `en_IE`. The rule that predicts these rows is
not pinned, so the `en_US` appended order is an oracle, not a rule, at present.

## Counts for the best candidate predictor

The candidate applies, in order: the first preference's chain (pass one), then the same chain with `en_US` appended to
the preferences, with the matcher's list as the tie-break (pass two), then the first enumerated key.

- 966 rows; 5 mismatches in pass one (the five rows above); pass two 198 rows, 0 mismatches; the fallback 160 rows, 0
  mismatches (with pass two in place).
- Without pass two the fallback misses 101 English key sets (`en_AU, en_US` gives `en_AU`, measured `en_US`, and so on).

Not measured yet: held-out preference lists and held-out key sets. The rule is not implemented until it predicts every
row above and those held-out ones.
