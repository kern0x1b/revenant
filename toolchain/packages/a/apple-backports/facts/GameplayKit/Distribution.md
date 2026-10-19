# The distributions, and the shuffle NSArray carries

`GKRandomDistribution`, `GKGaussianDistribution`, `GKShuffledDistribution`, and the two methods
`NSArray` carries for the framework. GameplayKit.framework carries no code at all before iOS 8, the SDK
declares all three at 9.0 (`GK_BASE_AVAILABILITY` is `NS_CLASS_AVAILABLE(10_11, 9_0)`), and the 6.1.3
armv7 cache exports no GameplayKit class at all. All of it is therefore this port's own, measured
against the host's own by `tests/backports/host/gameplaykit-core/measure.m` and held to it by
`differential.m`.

## Why a written script and not a seed

The port's own random sources are **not** the host's. `facts/GameplayKit/GKRandomSource.md` records the
measurement: the three generators are unidentified and the sequences differ under every seeding and
every scaling tried. So no number that came out of one source can be compared with the same number out
of the other, and a differential that seeded both sides with 1 and compared the draws would be comparing
two different things.

What has to agree between the two sides is what the families **on top of** a source do with it: which
protocol methods they call, in which order, and how they combine the answers. None of that needs a
generator. So `CharonGKScriptedSource.h` is a `GKRandom` that answers a written list of lines -- `int=7`,
`bounded:6=2`, `uniform=0.5`, `bool=1` -- and writes down what it was asked; a call whose kind does not
match the next line records a `MISMATCH` and a list that runs out records `starved`. The same script
prints the same trace on the host and on the port, so any difference in which method a distribution
reached for shows up as a difference in the text.

## What each distribution asks of its source, measured

- `-[GKRandomDistribution nextInt]` asks for `numberOfPossibleOutcomes` and adds `lowestValue`. Over a
  d6 with the script `bounded:6=2 bounded:6=5 bounded:6=1 bounded:6=4 bounded:6=0 bounded:6=3` the
  host answers `3 6 2 5 1 4`, having asked exactly those six things.
- `-[GKRandomDistribution nextBool]` is the source's own `-nextBool`, over the script
  `bool=1 bool=0 bool=1` the host answers `1 0 1`.
- `-[GKRandomDistribution nextUniform]` is that integer over the highest value, so it is quantised in
  the steps its header describes: over the script `bounded:6=3 bounded:6=0 bounded:6=5` the host
  answers `0.666667 0.166667 1`.
- `-[GKRandomDistribution nextIntWithUpperBound:]` asks the source for `MIN(upperBound - lowestValue,
  numberOfPossibleOutcomes)` -- **except that a bound of exactly zero asks for the whole range**, which
  is the one rule the archived version of `GKRandomDistribution.m` did not have: it asked for
  `upperBound - lowestValue`, which over a range whose lowest is below zero is a number below the whole
  range. Measured with one fresh source per call, one call per source, over the ranges `-2..2`,
  `0..2`, `2..5` and `3..3` and every bound from 0 to 8:

  | range | outcomes | the spans asked for, bounds 0, 1, 2, 3, ... 8 |
  | --- | --- | --- |
  | -2..2 | 5 | 5, 3, 4, 5, 5, 5, 5, 5, 5 |
  | 0..2 | 3 | 3, 1, 2, 3, 3, 3, 3, 3, 3 |
  | 2..5 | 4 | bounds 0 and 1 raise, then 0, 1, 2, 3, 4, 4, 4 |
  | 3..3 | 1 | bounds 0, 1 and 2 raise, then 0, 1, 1, 1, 1, 1 |

  A bound below `lowestValue` raises `NSInvalidArgumentException` with the host's own reason, `upper
  bound provided is less than lowestInclusive`. The answer is that draw added to the lowest, and to
  nothing when the lowest is below zero, so a range below zero still answers inside its own range: with
  a source that answers 3 over `-2..2`, a bound of 2 answers 3 and not 1.
- `-[GKRandomDistribution init]` is the degenerate distribution over 0 and 0: one outcome, and a
  `-nextUniform` of `nan` because it divides its own lowest by itself. An **inverted** range (lowest 5,
  highest 1) is kept rather than refused, and `-numberOfPossibleOutcomes` wraps to
  `(NSUInteger)(1 - 5) + 1` = 18446744073709551613, which is what the host answers; the archived
  version raised `NSInvalidArgumentException` at init, which is a rule of its own the host does not have.
- `+d6`, `+d20` and `+distributionForDieWithSideCount:` give the ranges their names say (1..6, 1..20,
  and 1..sideCount, so a one-sided die is over 1..1).
- `GKGaussianDistribution` over a range takes the middle of the range as its mean and a sixth of the
  range as its deviation -- `1..20` gives mean 10.5 and deviation 3.16667 -- and over a mean and a
  deviation it runs over `mean +/- 3 deviations`, so `(10.5, 19/6)` gives the same 1..20. `-nextInt`
  asks the source for **two** uniforms per draw and applies Box-Muller,
  `z = sqrt(-2 ln u1) cos(2 pi u2)`, then rounds `mean + deviation * z` and clamps it to the range. Over
  the script `uniform=0.25 uniform=0.75 uniform=0.5 uniform=0.1 uniform=0.9` the host answers
  `50 66 58` over the range 0..100.
- `GKShuffledDistribution` keeps a bag of every value in the range, shuffles it forward with a
  Fisher-Yates that asks the source for bounds 1, 2, 3 ... and hands the values out from the back,
  refilling the bag only when it has run out: six draws of a d6 ask for 1..6 once, the next six ask
  for 1..6 again. Over the script `bounded:1=0 bounded:2=1 bounded:3=2 bounded:4=0 bounded:5=3
  bounded:6=5 bounded:1=0 bounded:2=1 bounded:3=0` the host answers `6 1 5 3 2 4 5 4 3` for nine draws.

## The two methods NSArray carries

- `-[NSArray shuffledArrayWithRandomSource:]` **hands the array to the source** and returns what the
  source answers: measured, a source that implements only `-arrayByShufflingObjectsInArray:` is asked
  for it with the whole array, and the method returns that source's answer untouched. It does not draw
  bounds of its own.
- `-[NSArray shuffledArray]` is that same method over `+[GKRandomSource sharedRandom]`, so a shuffle
  with no source is the framework's own shuffle with its own source.
- The shuffle itself is `-[GKRandomSource arrayByShufflingObjectsInArray:]`, which `GKRandomSource.m`
  carries and whose row is in `registry/GameplayKit/random.json`. There is no second copy of a shuffle
  here, and none in the distribution family either.
- The archived version of this family ran a Fisher-Yates of its own over `nextIntWithUpperBound:` and
  shared it with the distribution family through a `charon_` category in a file of its own
  (`CharonGKShuffle.m`). That file is gone with this commit: it was a second copy of a shuffle the
  framework already has, and the host measures it as one -- the source is asked for the array, not for a
  sequence of bounds.

What is not here: nothing of the three classes and nothing of the two methods. What a distribution
draws is decided by the source it is given, and the sequences themselves belong to
`facts/GameplayKit/GKRandomSource.md`.