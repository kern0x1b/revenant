# The localized case and the standard search of a string, iOS 8 and iOS 9

Source: the host's own Foundation and the differential run of
`tests/backports/host/foundation2/run.sh`, which asks nine subjects for their three cases and twelve
subject-and-search pairs for what each of the four ways of looking finds, under `en_US`.

## The three cases

`localizedUppercaseString`, `localizedLowercaseString` and `localizedCapitalizedString` are the current
locale's mapping, not a per-character one, and the mapping is the full Unicode one:

| subject | upper | lower | capitalized |
|---|---|---|---|
| `Straße ÉCOLE ﬁ ǅ ıi Ⅻ ＡＢＣ` | `STRASSE ÉCOLE FI Ǆ II Ⅻ ＡＢＣ` | `straße école ﬁ ǆ ıi ⅻ ａｂｃ` | `Straße École Fi ǅ Ii Ⅻ Ａｂｃ` |
| `İstanbul ijssel` | `İSTANBUL IJSSEL` | `i̇stanbul ijssel` | `İstanbul Ijssel` |
| `😀 emoji ß` | `😀 EMOJI SS` | `😀 emoji ß` | `😀 Emoji Ss` |

Three things in that table are worth naming. Uppercasing grows the string where a character has no single
upper case form - `ß` becomes `SS` and `ﬁ` becomes `FI`. Capitalizing uses the title case form, not the
upper case one: `ǅ` capitalizes to itself and uppercases to `Ǆ`. And capitalizing puts a capital on every
word, including after a digit - `123abc 4th` becomes `123Abc 4Th`.

## The four ways of looking for a string

`-containsString:` is literal. `-localizedCaseInsensitiveContainsString:` folds case, and case only.
`-localizedStandardContainsString:` and `-localizedStandardRangeOfString:` fold case **and** diacritics,
and answer the same question, one as a flag and one as the range.

| in | for | literal | case-insensitive | standard | range |
|---|---|---|---|---|---|
| `Crème Brûlée` | `BRULEE` | no | no | yes | 6, 6 |
| `Straße` | `STRASSE` | no | yes | yes | 0, 6 |
| `näive` | `naïve` | no | no | yes | 0, 6 |
| `Ångström` | `angstrom` | no | no | yes | 0, 8 |
| `あア` | `ア` | yes | yes | yes | 1, 1 |
| `Crème Brûlée ＣＡＦＥ` | `cafe` | no | no | no | not found |
| `a-b` | `a‐b` (U+2010) | no | no | no | not found |
| `abc`, or the empty string | the empty string | no | no | no | not found |

So the standard search reaches across a diacritic and across a case folding that changes the length, but
not across a width - full width `ＣＡＦＥ` is not `cafe` - and not across a punctuation that merely looks
the same. An empty search string is found nowhere, not even in the empty string.
