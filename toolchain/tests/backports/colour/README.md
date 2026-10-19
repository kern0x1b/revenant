# colour - what this directory holds, and what is owed

One probe and nothing else yet. `AXNameFromColor` is **owed**, not carried: the host answers a curated
named-colour vocabulary with a nearest-match rule, not the components of a colour, so the work is a
black-box fit and not a lookup, and the fit has not been done. There is no registry row for the
function - not an `absent` one either, because `absent` says the API is not carried and that is not
what is true here.

`probe.m` is the host's own function over nineteen colours, chosen so that every pair shows something a
component lookup could not produce:

| colour | the host answers | a component lookup would say |
| --- | --- | --- |
| (128,128,128) and (200,200,200) | `gray` and `gray` | two different grays |
| (255,165,0) | `bright orange` | orange |
| (0,0,255) | `very dark blue` | blue |
| (255,255,0) | `very light vibrant yellow` | yellow |
| (128,0,128) and (255,0,255) | `dark magenta` and `dark magenta` | purple and magenta |

Build and run it with the host's SDK, no user data anywhere in it:

```
xcrun clang -target arm64-apple-macos26.0 -isysroot "$(xcrun --show-sdk-path)" -fobjc-arc -O0 -w \
    tests/backports/colour/probe.m -framework Foundation -framework Accessibility -framework AppKit \
    -o .agent-work/runs/colour-probe && .agent-work/runs/colour-probe
```

## What is measured, and what it rules out

`probe-dense.m` asks the host's own function over a dense sample and writes what it answers, and the two
fit scripts read that file. The run, copied from `sh tests/backports/colour/run.sh` on the branch:

```
=== the probe
probe	AXNameFromColor is in /System/Library/Frameworks/Accessibility.framework/Versions/A/Accessibility
fit	grid 4913	boundary-neighbour points 11983	random 20000	edge 21
vocabulary	267
first	amber
last	yellow orange
sample	7936644 bytes, 331967 lines

=== the known-answer check: the host's answers to the 21 edge cases
known-answer	21 recorded, 0 mismatched
known-answer	ok

=== the four spaces, nearest prototype per hue word
fit rows: 331966
distinct names: 267
distinct hue words: 28
near-neutral gray   2365
near-neutral black  63
near-neutral white  3
space srgb     hue-word agreement 47878 / 129466 = 0.3698
space linear   hue-word agreement 44201 / 129466 = 0.3414
space lab      hue-word agreement 52015 / 129466 = 0.4018
space oklab    hue-word agreement 42788 / 129466 = 0.3305

=== the hue angle as a partition
distinct colours: 129466
chromatic points: 128987   neutral: 479
contiguous runs of the angle, in angle order: 31180
```

331,966 rows over **129,466 distinct colours, 267 distinct names, 28 distinct words**. The names are
composed, not tabulated - a modifier from {very, light, dark, pastel, grayish, vibrant, bright} and a hue
word from the other 21, and the hue words include the neighbouring pairs (blue green, spring green, pink
magenta, magenta pink, red pink, red orange, yellow orange), so the vocabulary is a hue circle divided
into named sectors. Three names are the near-neutrals: gray on 2,365 points, black on 63, white on 3.

**Two models are measured and both are wrong, which is worth more than the one that might have been.**

  * *Nearest prototype per hue word*, with the prototype the mean of that word's points: over the 129,466
    distinct colours, sRGB 0.3698, linear sRGB 0.3414, CIE Lab 0.4018, OKLab 0.3305. The hue word is not
    a nearest-prototype rule in any of the four spaces the plan named, and Lab - the best of them - is
    two fifths.
  * *A partition of the hue angle*, which is what a hue circle divided into sectors would be. The answer
    is not a contiguous interval of the OKLab hue angle: sorted by it, the 128,987 chromatic points fall
    into **31,180** runs rather than 28.

## Owed

The dense probe is delivered: `probe-dense.m` wrote 331,966 rows over 129,466 distinct colours, and the
two fits above read it. What is owed is **the model**, and three things belong with it.

1. **A model that explains the 28 words.** The names are a modifier and a hue word, and the hue words
   include every adjacent pair, so the sector names are interpolations along a circle. Nearest prototype
   is measured and wrong in four spaces, and a partition of the hue angle is measured and wrong too, so
   the next model is neither of those. The hypothesis worth trying first: the boundaries are set by angle
   *ranges* in a space where that angle is the one that matters, with each prototype placed by its
   sector's midpoint rather than by the mean of the points answered with it - nearest prototype puts a
   prototype where the points are, and a range wants it where the boundary is.
2. **A held-out sample, once there is a rule to hold against it.** At least 200,000 colours the rule did
   not see, the exact number of disagreements and where they cluster, and the row `implemented` only for
   what agrees, with the rest an owed line carrying the number. There is no held-out probe in the tree
   and that is why: the rule does not exist yet, and a probe that measures nothing is a file that asserts
   nothing.
3. **The known-answer set is held, and nothing about a rule is.** `run.sh` records the host's answers to
   the 21 edge cases and fails if any of them moves, and `--wrong-expectation` is the control for that
   check, so the check can be seen to fail. What is not held is anything about a rule, because there is
   none to hold.

The registry has no row for `AXNameFromColor()` and that is the honest state: the registry has no status
for a rule that is not yet known, and the row this series owes is owed to the fit, not to a guess.
