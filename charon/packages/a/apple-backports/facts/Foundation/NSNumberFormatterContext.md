# The formatting context and the minimum grouping digits, iOS 8.0 and 18.0

Source: the SDK 26.2 headers; the host's own `NSNumberFormatter` (a fresh one answers
`formattingContext` 0 = `NSFormattingContextUnknown` and `minimumGroupingDigits` **1**, measured).

## The grouping is applied

The minimum grouping digits decide which of the groups the release's own formatter wrote are long
enough to keep a separator. The port formats with the release, then walks the result from the back --
so a group of digits is known before the separator that follows it is written or taken off -- and keeps
a separator only for a group of at least the number asked for. With the host's own default of 1,
`1.234` keeps its separator; asking for 2 takes it off a three digit group.

The walk only ever **removes** a separator the release wrote; it never adds one, because a number the
release wrote without a separator has no group to decide about. A separator is recognised by the
whole groups of three after it, so the locale's own decimal separator (one digit after it) and a sign
(no digits before it) are copied as they are.

`tests/backports/host/foundationbatch` found three wrong rules here, one after another, and the
third is still open:

| what the walk did | what it wrote | the host writes |
| --- | --- | --- |
| a separator in front of every run | `1,,234` and `--1,-234.-5` at a minimum of 0 | `1,234` and `-1,234.5` |
| the run before the separator | `1,234` at a minimum of 2 | `1234` |
| UTF-16 units escaped instead of UTF-8 bytes (in the URL file, not this one) | — | — |

**Closed: the rule is ICU's, and it is all or nothing.** The minimum applies to the integer part as a
whole and not to each group: the number is grouped at all when the integer part has at least
`grouping size + minimum` digits, and then every separator the release wrote stays. So `1,234` is four
digits and is not grouped at a minimum of two (4 < 3 + 2) while `1,234,567` is seven and keeps both of
its separators at a minimum of four (7 >= 3 + 4). The three attempts above were each right about one
number and wrong about the other, which is what a rule fitted to two cases looks like; the rule above
is the one the host answers over five numbers, five thresholds and three locales, and
`tests/backports/host/foundationbatch` holds all 123 of those checks and passes them.

Two details the rule needs and that the number itself cannot tell you: where the integer part stops
(the locale's own decimal separator, since a full stop groups in de_DE as well as separating) and
which character groups (the locale's own `groupingSeparator`, for the same reason). Both are read from
the locale rather than guessed.

## How the grouping reaches `-stringFromNumber:`

A category cannot take a release method over, and that is `attach.c`'s rule rather than a spelling:
`charon_collect` adds a category's method only when `charon_implements` says the class does not
answer the selector (attach.c:165). `-stringFromNumber:` arrived with the first release, so the
category's copy was dropped on every release this port is for and the grouping was never applied: the
port read back the minimum it was given and formatted without it, which
`tests/backports/device/foundation15batch.m` asks for and did not get.

Reaching the release's implementation the way a category is written does not work either. A
category's `[super ...]` skips the class it is written on, and naming the class in
`objc_msgSendSuper` does not skip it, so the lookup starts at the class, finds the port's own method
and calls it again. Measured, on the host: a stack of alternating
`-[NSNumberFormatter(CharonContext) stringFromNumber:]` and `charon_release_string` frames ending in
`objc_storeStrong`, which is what `tests/backports/host/foundationbatch` died on.

So the release's implementation is held by name instead, from a `+load` -- the only point at which the
class still has the release's own: the runtime finishes every `+load` in the image before it runs the
first constructor, and `attach.c` is a constructor. That is the arrangement
`UICollectionView+Prefetching10.m`, `UIImageView+Template7.m` and `CharonConfigurationHost.m` use.

The install is guarded on the release not answering `-minimumGroupingDigits`, asked with
`NSSelectorFromString` and not with `@selector`: where the release's own formatter has the minimum it
applies it itself, so its `-stringFromNumber:` is the answer and taking the name over would replace a
method the host differential still needs. The spelling matters for the same reason it matters in
`Foundation/NSNumberFormatter+Context8.m`: `tests/backports/host/prefix_selectors.py` moves an
`@selector` of a selector the file defines, and the release's own spelling is the one that must not
move.
