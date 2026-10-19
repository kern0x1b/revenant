# `CMTimeMultiplyByRatio` on a release that has no `CMTimeMultiplyByRatio`

iOS 6 has 66 `CMTime` and `CMTimeRange` functions, and `CMTimeMultiplyByRatio` is not one of
them: it first appears at 7.1 (`coordination/corpus/caches/7.0.1.tsv`, 67 functions, against 66
at 6.0). What iOS 6 does carry is enough to hold the answer, because a `CMTime` is a
`(value, timescale, epoch, flags)` quadruple and the arithmetic is on those fields.

## What the port does

`(time * multiplier) / divisor`, as an exact rational, kept whenever a `CMTime` can hold it:

1. An invalid time, an indefinite time, and an infinity are answered as themselves. An infinity
   multiplied by zero is `kCMTimeInvalid`, and its sign follows the multiplier and the divisor
   together. Every answer carries `kCMTimeFlags_HasBeenRounded`, which is what the host does.
2. A zero multiplier, and a zero value at epoch 0, give zero at the *input* timescale, not at 1.
3. A zero divisor gives `kCMTimeInvalid` when the multiplier or the value (at epoch 0) is zero,
   and otherwise an infinity of the sign of `multiplier * divisor`, or - when the time carries a
   non-zero epoch, so it is not the zero the sign test sees - of the sign of the multiplier alone.
4. Otherwise the multiplier and the divisor are reduced by their greatest common divisor, the
   divisor is made positive, and the answer is `value * multiplier` at `timescale * divisor`. The
   fraction is **not** reduced any further: `CMTimeMultiplyByRatio(CMTimeMake(1, 3), 3, 1)` is
   `3/3`, and `CMTimeMultiplyByRatio(CMTimeMake(1, 2147483647), 2147483647, 1)` is
   `2147483647/2147483647`. This is measured, not inferred (see the grid below).
5. Where the value does not fit an `int64`, or the denominator is not a legal `CMTimeScale`, the
   answer is the exact value at the timescale chosen for it, rounded half away from zero, with
   `kCMTimeFlags_HasBeenRounded` set; and an infinity when even that does not fit.

The 96-bit helpers exist because armv7 has no `__int128`, and the exact rational needs the
product of a 64-bit value and a 32-bit multiplier.

## The claim, and what was measured against it

`tests/backports/host/coremedia7` runs the port's function and the host's own side by side over a
grid of 32 values, which includes 2^60, 2^61, 2^62, 1e18, both `int64` bounds and the largest value the
port answers, and 10^12; x 32 timescales, which include 0, -1, -2, -1000 and -48000; x 29 multipliers
and 29 divisors, which include 8, 16, 20, 1000000000 and both `int32` bounds. Every case is asked again
with `kCMTimeFlags_HasBeenRounded` set, with a non-zero epoch, and for the five special times.

- **2 094 716 answers are the same**, including every degenerate rule above.
- **0 differ where a `CMTime` can hold the exact rational.** That is the claim the registry entry
  makes, and the test fails if one ever does. The claim boundary in the test forms the product in
  128 bits, not in 64, so it cannot repeat the implementation's arithmetic: an earlier version of it
  multiplied in `int64_t` and so agreed with a wrapped numerator on both sides, which is what
  `coordination/reviews/2026-09-27-api-coremedia-time-1.md` finding B caught.
- 493 041 fall outside the claim, where no `CMTime` holds the exact rational. 365 340 of them answer
  the host's own status and value; the rest are the two corners below.

The same two probes the review kept (`coordination/reviews/probes/2026-09-27-coremedia-ratio-big.m`
and `-bounds.m`), built against this file the way `run.sh` builds it, report **0 differing rows**.

## Where the host leaves the documentation, and the port does not

In that corner Apple's implementation truncates the *value* against the input timescale before it
multiplies, so it loses the answer entirely for a value smaller than its own timescale. Measured
on the host:

Where the exact numerator is past an `int64`, the host reduces numerator and denominator by their
greatest common divisor until the value fits, and only when that runs out does it truncate the value
against the input timescale and answer at timescale 1. Both are measured, and both are what the port
does:

| input | exact | host | port |
| --- | --- | --- | --- |
| `4611686018427387904/1073741824 * 3 / 1` | 12884901888 s | `12884901888/1` | `12884901888/1` |
| `6148914691236517205/1000000000 * 3 / 1` | 18446744073.71 s | `3689348814741910323/200000000` | `3689348814741910323/200000000` |
| `9223372036854775807/3 * 1 / 1` | 3074457345618258602.33 s | `3074457345618258602/1` | `3074457345618258602/1` |
| `4611686018427387903/1 * 3 / 2` | 6917529027641081854.5 s | `6917529027641081855/1` | `6917529027641081855/1` |
| `4611686018427387904/1 * 4 / 1` | 1.8446744e19 s | `+inf` | `+inf` |

The first two are the reduction, the last three the truncation, and the fourth is a rounded quotient:
the host rounds half away from zero there and so does the port.

**The two `int64` bounds.** The host answers an infinity for a result of `INT64_MIN` *or* `INT64_MAX`:
`INT64_MIN/1 * 1 / 1` and `INT64_MAX/1 * 1 / 1` are `-inf` and `+inf`, and `INT64_MAX/1 * 3 / 2` is
`+inf`. So a value a `CMTime` cannot hold is an infinity, and the port's domain test stops at `2^63 - 2`
- the largest magnitude the host does answer, `4611686018427387903 * 2`, comes out as
`9223372036854775806/1`. The port answers the infinity for both bounds too.

**A negative timescale is legal.** `CMTIME_IS_VALID` is only the `kCMTimeFlags_Valid` bit, so
`{1000, -1, Valid, 0}` is a time any caller may hold, and the host multiplies through and normalises
the sign into the value: `1000/-1 * 3 / 2` is `-3000/2`, `1000/-48000 * 7 / 3` is `-7000/144000`, and
`5/0 * 1 / 3` is `5/0` - with a zero timescale the host never divides at all, so the divisor is dropped
and only the multiplier applies. The port normalises a negative denominator the same way.

## The source

The host's own CoreMedia (`xcrun clang` against `/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk`,
macOS 27.0), which the port is held against case by case by the test above. iOS 6.0's exports were
read from `coordination/corpus/caches/6.0.tsv`, the symbol table of the iOS 6 armv7 shared cache.
