# CSLocalizedString: which localization is chosen

`CSLocalizedString` holds a dictionary of strings keyed by language identifier and answers one of them. The class is
implemented as the two-stage form in the section "The implemented form" below, and that form is held to the host in
`tests/backports/host/corespotlight-localized`. The sections before it are the measurements that led to the form, kept
because they show which rules were tried and where each one fails.

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

## The composite: NSBundle's matcher over the keys, with en_US appended

The composite takes the dictionary's keys in its own enumeration order, asks
`+[NSBundle preferredLocalizationsFromArray:forPreferences:]` with the user's `AppleLanguages` plus `en_US`, takes the
first answer, and falls back to the first enumerated key when the matcher answers nothing. Measured on the host over the
same 966 rows (the enumeration order matches the recorded table in every row), it agrees with the host's
`CSLocalizedString` in 940 rows and disagrees in 26. Every disagreement has `en_US` in the key set together with another
English region, under a preference list that has an English language. The host picks the region; the composite picks
`en_US`, which the appended fallback ranks first.

| Preferences | Keys (given order) | Host | Composite |
| --- | --- | --- | --- |
| en-GB | `en_US,en_AU`; `en_AU,en_US` | `en_AU` | `en_US` |
| en-AU | `en_US,en_GB`; `en_GB,en_US`; `en,en_GB,en_US` | `en_GB` | `en_US` |
| fr-CA,en-GB | `en_US,en_AU`; `en_AU,en_US` | `en_AU` | `en_US` |
| de-DE,en-AU | `en_US,en_GB`; `en_GB,en_US`; `en,en_GB,en_US` | `en_GB` | `en_US` |
| en-IN | `en_US,en_GB`; `en_GB,en_US`; `en_GB,en_AU,en_US`; `en_US,en_GB,en_AU`; `en_AU,en_GB,en_US`; `en,en_GB,en_US` | `en_GB` | `en_US` |
| en-IN | `en_US,en_AU`; `en_AU,en_US` | `en_AU` | `en_US` |
| ja-JP,en-GB | `en_US,en_AU`; `en_AU,en_US` | `en_AU` | `en_US` |
| zz-ZZ,en-AU | `en_US,en_GB`; `en_GB,en_US`; `en,en_GB,en_US` | `en_GB` | `en_US` |
| it-IT,en-AU,de-DE | `en_US,en_GB`; `en_GB,en_US`; `en,en_GB,en_US` | `en_GB` | `en_US` |

The composite is not implemented: the coordinator's ruling was to stop at the first disagreement. The earlier
pass-one chain rule (five disagreements, listed above) and this composite each fail rows the other passes, so no rule
measured so far predicts all 966 rows.

## The implemented form

The choice is made each time `localizedString` is asked, from the user's `AppleLanguages` (`NSUserDefaults`), in two stages:

1. `+[NSBundle preferredLocalizationsFromArray:forPreferences:]` over the dictionary's keys in the dictionary's own
   enumeration order, with the preferred languages. The first answer that is a key wins.
2. If that answers nothing, the dictionary's first enumerated key.

An earlier draft had a third step, the same call with `en_US` appended. It was measured to decide no row (see below), so
it is not in the port.

The matcher answers nothing when it has no localization, and then it returns its first element. So each call puts a probe
(`charon.no-match`, which is not a language) first in the keys: an answer equal to the probe means the matcher answered
nothing. The probe is not a key, so it cannot win.

The matcher is the release's own call, `NSBundle`'s. The claim that on the device the release's own matcher decides the first
stage, as the host's does, is the coordinator's ruling and is not measured on a device here. The port carries no table of
its own; the enumeration order is the only rule it adds.

Measured on the host with the two-stage rule (`twostage.m`, scratch, not committed; its answers are reproduced by the
differential below):

| Set | Rows | Decided by the matcher | Decided by the first enumerated key | Disagreements with the host |
| --- | --- | --- | --- | --- |
| Measured (23 preference lists x 42 key sets) | 966 | 806 | 160 | 0 |
| Held out (12 new preference lists x 19 new key sets, fixed before the port was written) | 228 | 196 | 32 | 0 |

The same run measured the `en_US`-appended matcher call as a third step: it decided no row in either set, because wherever
the matcher with the preferred languages had no answer, the call with `en_US` appended had none either. The step was
removed, and the two-stage rule above is what is measured and implemented.

The differential (`tests/backports/host/corespotlight-localized`) runs the port and the host over 35 preference lists (the
23 measured and the 12 held out) against 61 key sets (the 42 measured and the 19 held out): 2,240 lines, identical after
addresses are replaced. A planted control, with the fallback set to the last enumerated key, differs from the host on 678
lines.

### The NSString subclass, as the host measures it

- The object is of class `CSLocalizedString`, reads as the string it localizes to (its length and characters), and is an
  `NSString` (`isKindOfClass:`). `isEqualToString:` and `isEqual:` with the string answer equal.
- `localizedString` returns the plain string, class `__NSCFConstantString` for the constant it is given.
- `copy` returns a `CSLocalizedString` with the same dictionary; `mutableCopy` returns a mutable string (`__NSCFString`).
- Archived and unarchived, it decodes as a plain `NSTaggedPointerString` with the same text.
- An empty dictionary: `localizedString` is nil, and the object reads as the empty string (length 0).
- A nil dictionary: `init` returns an object and `localizedString` crashes the host (exit 139). The port answers nil and
  reads as empty. This is a named difference (see "Named differences" below); the differential does not cover it.
- The host copies the dictionary at initialisation: a change to the mutable dictionary afterwards is not seen (measured:
  `before=one after=one`). The port copies it too, and the differential checks it.

## Named differences

- **nil-dictionary**: `initWithLocalizedStrings:nil` returns an object on the host, and `localizedString` on that object
  crashes the host (exit 139). The port treats nil as an empty dictionary: `localizedString` is nil and the object reads as
  the empty string. The port does not crash and does not reproduce the host's crash. Not in the differential, because the
  host's answer is a crash, which the differential cannot compare.
