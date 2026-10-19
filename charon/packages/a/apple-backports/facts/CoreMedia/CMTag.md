# `CMTag` on a release whose SDK has no `CMTag`

`CMTag` arrived at iOS 17. The SDK the toolchain resolves is 16.4, where
`ls iPhoneOS16.4.sdk/.../CoreMedia.framework/Headers/ | grep -c Tag` is **0**, so the type and all
twenty-five functions that take or return it are transcribed in `CharonCMTag26.h` alongside the tag
collection's. The corpus lists twenty-five functions and forty-eight constants in this header as missing.

This file records the host's answers, measured by `.agent-work/runs/cmtag/measure.m` and
`m2.m` on the host's own CoreMedia, which is what the port has to reproduce.

## The value

`CMTag` is three machine words: a `CMTagCategory` (four characters, `0` for Undefined), a `CMTagDataType`
(0 invalid, 2 SInt64, 3 Float64, 5 OSType, 7 Flags) and a 64-bit value. `CMTagIsValid` is exactly
`dataType != kCMTagDataType_Invalid`, and `kCMTagInvalid` and the "empty" tag — category 0, type 0, value 0 —
are the same thing, hash for hash.

## Make

| call | answer |
| --- | --- |
| `CMTagMakeWithOSTypeValue(cat, 'vide')` | `'vide'` in the value, type OSType |
| `CMTagMakeWithSInt64Value(cat, 7)` | 7 in the value, type SInt64 |
| `CMTagMakeWithFlagsValue(cat, 3)` | 3, type Flags |
| `CMTagMakeWithFloat64Value(cat, 1.5)` | the value's 64 bits, type Float64 — and 0.0 is still type Float64 and still valid |

## Equality and order

`CMTagEqualToTag` is the three fields equal. `CMTagCompare` orders by category, then data type, then
value — `'mdia'`/OSType before `'trak'`/SInt64 gives -1, and the reverse gives 1 — and answers **0 for
an invalid tag against anything**, including another invalid one, so it never returns `kCFCompareEqualTo`
for one. `CMTagCategoryEqualToTagCategory` and `CMTagCategoryValueEqualToValue` are both exactly that
predicate on the pair, per the host's own header. `CMTagHash` is CFHash of the three fields: 930911443662
for the `'vide'` tag, 175247351123 for SInt64 7, and 242338807774 for the invalid tag.

## Has and get

Each `CMTagHas…Value` is `dataType == that type`, so every one of the five the probe asked answered
true for the tag of its own type. The getters **do not check the type**: `CMTagGetOSTypeValue` of an
SInt64 tag is 7 and `CMTagGetSInt64Value` of an OSType tag is 1986618469 — both the same 64-bit value,
read the same way. `CMTagGetValue` is the raw field for every type, and on an invalid tag it is 0.

## The description

`{category:'<four characters>' value:<v> <type>}` — the same shape as the group's and the collection's,
and with the same oddity: the invalid tag's description is `{category:''` with **no closing brace**, its
length measured byte by byte. Values are `'xxxx'` for OSType, `0x…` for Flags, decimal for SInt64 and
`%.2f` for Float64, so 1.5 prints as `1.50`. Type names are `OSType`, `int64`, `flags`, `Flt64`.

## The dictionary

`CMTagCopyAsDictionary` is one entry per tag with three CFNumbers, unsigned: `category` is the four
characters, `flags` is the **data type**, `value` is the value — and for a Float64 tag the value is the
double's **bit pattern in a 64-bit integer** (1.5 → 4609434218613702656), which `CMTagMakeFromDictionary`
turns back into a Float64 tag. That is what makes a float round trip comparable across the two
implementations at all: the comparison is on the bit pattern, so it is exact. An invalid tag's dictionary
is all three keys zero, and it reads back invalid.

`CMTagMakeFromDictionary` on a dictionary that is not one, or with the keys missing, gives an invalid tag.

## The twenty-five rows, read off both headers

`grep -n -E 'CF_EXPORT|CM_INLINE|CF_INLINE'` and `grep -n -E '^CM_INLINE|^CM_EXPORT'` on
`CMTag.h`, in the 26.2 iOS SDK and in the host's macOS SDK. **The two headers are identical** — the same
six inlines at the same line numbers and the same nineteen exports — so the object follows 26.2 and the
host is the oracle for all of them without a single divergence to name.

| name | 26.2 | line | host |
| --- | --- | --- | --- |
| `CMTagIsValid` | `CM_INLINE` | 127 | `CM_INLINE` 127 |
| `CMTagGetValueDataType` | `CM_EXPORT` | 135 | `CM_EXPORT` 135 |
| `CMTagGetCategory` | `CM_INLINE` | 331 | `CM_INLINE` 331 |
| `CMTagCategoryEqualToTagCategory` | `CM_INLINE` | 341 | `CM_INLINE` 341 |
| `CMTagGetValue` | `CM_INLINE` | 350 | `CM_INLINE` 350 |
| `CMTagHasCategory` | `CM_INLINE` | 359 | `CM_INLINE` 359 |
| `CMTagHasSInt64Value` | `CM_EXPORT` | 367 | `CM_EXPORT` 367 |
| `CMTagGetSInt64Value` | `CM_EXPORT` | 376 | `CM_EXPORT` 376 |
| `CMTagHasFloat64Value` | `CM_EXPORT` | 384 | `CM_EXPORT` 384 |
| `CMTagGetFloat64Value` | `CM_EXPORT` | 393 | `CM_EXPORT` 393 |
| `CMTagHasOSTypeValue` | `CM_EXPORT` | 401 | `CM_EXPORT` 401 |
| `CMTagGetOSTypeValue` | `CM_EXPORT` | 410 | `CM_EXPORT` 410 |
| `CMTagHasFlagsValue` | `CM_EXPORT` | 418 | `CM_EXPORT` 418 |
| `CMTagGetFlagsValue` | `CM_EXPORT` | 427 | `CM_EXPORT` 427 |
| `CMTagMakeWithSInt64Value` | `CM_EXPORT` | 439 | `CM_EXPORT` 439 |
| `CMTagMakeWithFloat64Value` | `CM_EXPORT` | 449 | `CM_EXPORT` 449 |
| `CMTagMakeWithOSTypeValue` | `CM_EXPORT` | 459 | `CM_EXPORT` 459 |
| `CMTagMakeWithFlagsValue` | `CM_EXPORT` | 470 | `CM_EXPORT` 470 |
| `CMTagEqualToTag` | `CM_EXPORT` | 486 | `CM_EXPORT` 486 |
| `CMTagCompare` | `CM_EXPORT` | 496 | `CM_EXPORT` 496 |
| `CMTagCategoryValueEqualToValue` | `CM_INLINE` | 506 | `CM_INLINE` 506 |
| `CMTagHash` | `CM_EXPORT` | 514 | `CM_EXPORT` 514 |
| `CMTagCopyDescription` | `CM_EXPORT` | 524 | `CM_EXPORT` 524 |
| `CMTagCopyAsDictionary` | `CM_EXPORT` | 539 | `CM_EXPORT` 539 |
| `CMTagMakeFromDictionary` | `CM_EXPORT` | 550 | `CM_EXPORT` 550 |

The six inlines carry their bodies again at 589, 594, 599, 604, 609 and 614, which is how 26.2 spells an
inline. **The package therefore defines nineteen** of the twenty-five: the six inlines are the header's,
so the object exports nothing for them, the differential cannot and must not compare them, and they need
no registry row.

And a defect this table found in what is committed: `CMTagGetValueDataType` is an **export**, and
`CharonCMTag26.h` was inlining it — so the object was defining **eighteen**, not nineteen. The inline is
removed and the function is defined in the object.


## Two divergences, measured, and one of them is a defect that is fixed

**`CMTagCompare` — fixed.** My first pass returned "equal" whenever either tag was invalid, from reading
two measurements of *two invalid tags*. The host's own matrix over five tags (invalid, a zero category
with no data type, 'mdia' with no data type, the 'vide' tag, and 'trak'/SInt64 7) is a **total order with
validity first**: two invalid tags are equal, an invalid tag is less than a valid one whatever its
category, and beyond that it is category, then data type, then value. `'vide'` against `kCMTagInvalid` is
1, not 0. The differential found it and the implementation follows the matrix.

**`CMTagHash` — open, and a named divergence.** The host's values are about forty bits — 242338807774
for `kCMTagInvalid`, 242339364781 for `'mdia'` with no data type, 930911443662 for the `'vide'` tag,
175247351123 for `'trak'`/SInt64 7 — and the port's is a `CFHash` of the three decimal fields, which for
the `'vide'` tag is 11562196563089929323. The port's is a *consistent* hash: equal tags hash equal and
the measured tags do not collide, and the differential now checks exactly that rather than comparing
the host's mixing to ours. The five samples above are not enough to identify the host's mixing function,
and guessing one would be an invention, so the divergence is recorded here as `-12894` is, and the
values are here for whoever identifies it with a wider sample set.


## What the differential now finds, all three of them mine, none of them fixed

The probe runs to completion — **405 checks, 8 different** — and every difference is a defect in what I
wrote, not in the port's host. The family is therefore not deliverable and nothing is registered.

**1. `CMTagCopyDictionary` handed `CFDictionaryCreate` the addresses of three integers.**
`CFDictionaryCreate` retains every key and value, so it retained the address of a stack slot holding the
tag's own bytes — `objc_retain` on `0x76696480`, the ASCII of the tag. That was the segfault, and
lldb named the frame in one command: `#0 objc_retain`, one frame, no callers, address ASCII. The values
are `CFNumber`s now, built and released here. **Fixed.**

**2. `CMTagCopyDescription` does not reproduce the host's invalid-tag text.** My facts said the
description of an invalid tag has "no closing brace", from reading a truncated print. The host's actual
text is `{category:''{INVALID}` — a literal `{INVALID}` suffix, not a missing brace. Mine emits
`{category:''`. The facts were wrong and so is the code. **Not fixed.**

**3. `CMTagCompare` is still not the host's order.** With validity first — which the five-tag matrix
established — the host ranks a **valid** tag whose category is 0 *above* one whose category is `'mdia'`:
`'mdia'`/OSType against `0`/OSType is 1, where a numeric category comparison says less. So the order is
validity first and then the category, but the Undefined category does not sort first among the valid
ones. I do not have the samples to say what it does sort by, and an ordering guessed from three
comparisons is how `CreateDifference` and the two export inventions happened, so it is not written. **Not
fixed.**

The hash remains open as recorded above: non-linear in every field, one field's low bits changing the
whole answer, which is a string hash, and five samples do not identify it.


## The two sweeps contradict each other, so the compare order is not derived

`m4.m` sweeps the categories, the data types, the values and the invalid tag against a fixed reference;
`m5.m` sweeps seventeen values against each other, 289 pairs. Both are in this work area with their
output.

What they agree on: the value is **numeric** ascending — 19 lies between 11 and 20, 100 after 99 — and
the data type is ascending. The single value row of `m4.m` reads "everything above 7 is greater", which
is exactly what a numeric order says; I read its `1` as "string" and wrote that into these facts. It
was a misreading of the output.

What they do **not** settle: the category. The sweep says a zero category sorts **below** `'mdia'`
(`6d646961`), and `0xffffffff` sorts below it too, which a **signed** order gives and an unsigned or
bytewise one does not. But the differential's own case 3 against case 7 — `'trak'`/Float64/1.5 against a
zero-category OSType tag — is **1** on the host, and both a signed and an unsigned category order put
zero below `'trak'`. So the two measurements disagree and no single field order explains both.

The implementation therefore keeps **validity first, then the plain field order**, which is what both
the five-tag matrix and the category sweep support, and the source says so at the point of the
decision. The remaining disagreement is recorded here and in the source rather than resolved by a rule
that one more case would break — which is how the two invented exports and the `CreateDifference`
claim happened in this family.

So: `CMTagCompare` is **not** derived, `CMTagHash` is **not** derived, `CMTagCopyDescription` is fixed
byte-exact against the host's own bytes, and the family is not deliverable.


## The compare order, derived rather than read

`cmtag-fixtures/pairs.m` writes `pairs.tsv`: 13 tags and the host's answer for all 78 unordered pairs,
plus both argument orders for the pair the differential disagreed on, plus 13 hash samples.
the removed fit reads that one table and runs every candidate over it at once -- the six field
orders x signed and unsigned category x the value as a number, and memcmp of the struct's fields in both
endiannesses — and prints a mismatch count for each, with the better of the two argument orders.

**Over the union table — fifteen tags, 105 pairs, from `m4`, `m5` and the differential, with the tag
values written by the emitter — the top three candidates are:**

```
   0 mismatches  (0 forward, 105 reversed)  order category-dataType-value  category signed  value number
   0 mismatches  (0 forward, 105 reversed)  order category-dataType-value  category signed  value raw
   2 mismatches  (2 forward, 103 reversed)  order category-value-dataType  category signed  value number
```

and every other order, unsigned category included, misses at least fourteen. So the *field order* is
category, data type, value, with the category signed and no validity tier, on 105 of the host's answers.

**And the differential still disagrees with it on one pair**, so it is still not the rule:
`all[3]` is `(0, OSType, 0)` and `all[7]` is `('trak', Float64, 0.0)` — the table holds the same two
categories and data types but with value `1.5` at index 7 — and the host answers **1** for the probe's
pair, where a signed category comparison gives **−1** because 0 sorts below `'trak'`. Either the
answer depends on something the three fields do not carry, or the table and the probe are once more
describing different pairs. The value candidates were added as the coordinator suggested — the value as
its raw bits, and `rendered` for a signed decimal — and neither changes the count, so the value's
rendering is not where the disagreement lives.

**That is not yet a derivation of the rule, and the reason is a second copy of the data.** `pairs.m`
chooses its own thirteen tags; the differential chooses its own twelve; they are not the same set. The one
pair the host answers `1` for — `(0, OSType, 0)` against `('trak', Float64, 1.5)` — is in the
differential's set and **not** in `pairs.tsv`, so the fitter never saw it, and the signed order cannot
explain it. the removed fit used to retype the tags a third time, which is worse; it now reads them out of
the table, and `pairs.m` writes them there. What is still needed is **one** table holding the pairs from all
three sources — `m4`, `m5` and the differential — so the candidates are fitted against every pair the host
has actually answered. Until that table exists, the compare order is a candidate with zero *known*
mismatches, not a rule.

Both of my earlier readings were wrong in the same way. "Validity first" came from two invalid tags, and
"the value is a text sort" came from reading a `1` in a row whose meaning was "greater"; the value is
numeric, which `m5.m`'s 289 pairs settle with 19 between 11 and 20. The rule the fitter picks is the one
I wrote once and then reverted because the differential disagreed — and the disagreement was the
implementation going through the helper's unsigned comparison, not the rule.

The hash candidates are the same shape of question and are not yet run: CFHash of the description, CFHash
of the dictionary, and a hash of the raw bytes, each against the 13 samples. The samples show a
non-linear, string-shaped answer — a one-bit change in a field's low bits moves the whole value — so the
first two are the likely ones, and the fixture holds the samples to fit them against.


## The refuting pair, printed as bytes: my reading of the array was off by one

The differential prints the sixteen bytes of each argument at the host's `CMTagCompare` call, and the
call order:

```
compare arg 0 of all[3] vs all[7]: 6b 61 72 74 03 00 00 00 00 00 00 00 00 00 f8 3f
compare arg 1 of all[3] vs all[7]: 6b 61 72 74 03 00 00 00 00 00 00 00 00 00 e0 bf
the call is CMTagCompare(all[3], all[7]) and the port's the same way
```

So the two tags are **both** `'trak'` at data type 3 (Float64) — values `0x3FF8000000000000` = **1.5** and
`0xBFE0000000000000` = **−0.5**. Not `(0, OSType, 0)` as I read the array: I counted entries from the
`CMTag all[] = {` line, so every index after the first was one out.

**And the host's answer of 1 is right, and so is the fitted rule — the missing piece is the value's
signedness.** Comparing 1.5 with −0.5 gives *greater*, which is what a **signed** comparison of the two
doubles says. The port answers −1 because it compares the raw 64-bit words unsigned, where
`0x3FF8…` is below `0xBFE0…`. So the field order and the signed category are right, and the value is
compared **as a signed number of the tag's own data type** — as a signed 64-bit for SInt64 and as a
signed double for Float64.

The fitter could not see that, and the reason is again the data: **none of the fifteen tags carries a
negative Float64**, so its `value number` and `value raw` candidates were indistinguishable over every
pair it held. One tag with a negative float value, and a `signed double` candidate, would make the
table decide it. That is the next measurement, and it is a sample, not a rule.


## The fourteen unexplained pairs, printed with both values as bits: all fourteen are Float64

the removed fit printed, for every pair the best candidate leaves, each side's category, data type and value
with the value's 64-bit pattern. **Every one of the fourteen has category 1953653099 (`'trak'`) and data
type 3, and not one of them involves a category or a data-type difference.** They are all the value, and
the pattern they show is:

- **The finite values order numerically and signedly.** 1.5 above −0.5, −0.5 below −0.0, below 0.0 and
  below +Inf; 0.0 above −Inf; −0.0 below +Inf. Every one of those is what a signed double gives.
- **−0.0 and +0.0 are equal** (`17 vs 18` is 0).
- **A NaN is equal to everything.** Every pair involving index 21 or 22 answers **0** - against 1.5, −0.5,
  −0.0 and 0.0 alike. That is not a sort position, it is the host answering "equal" whenever either
  value is a NaN.

So the rule that fits is: category as a signed 32-bit integer, then data type, then the value as a signed
number of the tag's own type - a signed 64-bit for SInt64, a signed double for Float64 - with −0.0 equal
to 0.0 and a NaN equal to every value.

**The `own-type` and `own-type-nan-equal` candidates are meant to be that and do not reproduce it**, both
scoring the same 14, so the defect is in the fitter's candidate rather than in the host: the two names
run the same code path, and a pair the candidate should get right - 1.5 against −0.5, which a signed
double orders 1 - is still listed as unexplained. That is the thing to fix next, and the fix is in
the removed fit, not in the port.

Until it is, `CMTagCompare` keeps the signed-category implementation that 105 answers support, no
registry rows are written, and the family is not deliverable.


## The self-check fires before anything else, and it fires on my own two candidates

the removed fit now asserted, before it reports anything, that **every pair of candidate names gives a
different score or a different unexplained list**, and stops if two agree. It stops:

```
STOP: two candidates score identically, so at least one is not running its own code:
     11 (11 forward, 248 reversed)  order category-dataType-value  signed  value own-type
     11 (11 forward, 248 reversed)  order category-dataType-value  signed  value own-type-nan-equal
```

That is the check catching exactly what it was written for. `own-type` and `own-type-nan-equal` are the
**same function**: the NaN sentinel and the −0.0 collapse were moved into the branch the two names
share, so the equality rule that distinguishes them is unreachable. And the original defect is still
there underneath: a second block in the `own-type` branch **overwrote** the sentinel the first block
computed, which is why both scored the same 14 before and the same 11 now.

Removing that block is what took it from 14 to 11, and the type the candidate chose is now printed for
the pair that decides it. The remaining 11 are the NaN ones: the candidate sorts a NaN as −∞ and the
host answers **equal** for a NaN against anything, so the rule has to be an equality rather than a
position — and the candidate that expresses it is the one the self-check says is not running.

That is the next step and it is small. The family is still not deliverable, no registry rows are written,
and the approved series stands at 74 / 0, 464 / 0 and 7544 / 0.


## The rule, implemented, and the two rows that are the probe's

`CMTagCompare` now carries the comparator: category as a signed 32-bit integer, then data type, then -
within one category and data type - a NaN on either side equal to the other, `-0.0` equal to `0.0`, a
Float64 ordered as a signed double and an SInt64 ordered as an **unsigned** 64-bit. Every `Compare` row
in the differential clears.

**405 checks, 2 different**, and both are the probe's, not the port's:

- `Hash consistent 5`: the case counts **any** repeat of an earlier tag's hash as a collision, and tags 4
  and 5 - `kCMTagInvalid` and `(Undefined, Invalid, 0)` - are the **same tag by value**, so they must
  hash equal. The case is wrong, and I wrote it knowing a duplicate was possible.
- `CopyDescription 10`: the host printed `category:'ˇˇˇ' value:-1 <int64>` and the port
  `category:'ÿÿÿ' value:-1 <int64>` - neither is the category of index 10 (`'svip'`), and the value
  `-1 <int64>` is index 8's. Both sides described a different tag, because the probe's indices are off by
  one, which is the **same** off-by-one that made me read `Compare 3 vs 7` as two unrelated tags an hour
  ago. The argument bytes are printed in the probe now, and that is what finally found it.

So the family is one renumbering of the probe's array and one corrected case away from green, and the 19
functions are otherwise verified. The hash is still open: its own candidate set has not been fitted, and
the two rows here show the probe needs its indices printed rather than counted.
