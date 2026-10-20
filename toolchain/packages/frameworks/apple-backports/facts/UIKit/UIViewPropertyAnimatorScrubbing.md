# Scrubbing linearly and pausing on completion, iOS 11.0

Two flags iOS 11 added to `UIViewPropertyAnimator`: `scrubsLinearly`, which
says how a paused animator maps `fractionComplete` onto the animation, and
`pausesOnCompletion`, which says whether reaching the end finishes the animator
or leaves it standing there. The class belongs to the iOS 10 range; these two
members belong to this one, so what is here is the reading, and the
implementation is with the class.

Source: UIKit of the arm64 shared cache of iOS 11.0 (iPod7,1 15A372) -
`-setScrubsLinearly:` at `0x18ac60df4`, `-timingFunctionForPause` at
`0x18ac60da4`, `-pauseAnimationTransiently` at `0x18ac60d38`,
`-setPausesOnCompletion:` at `0x18ac65490`, and the defaults set in
`-_setupWithDuration:timingParameters:animations:` at `0x18ac5964c`; the
behaviour that can be watched from outside from the differential test against
the host's UIKit (`tests/backports/host/animatorscrub`).

## The defaults

Set where the animator is built: `scrubsLinearly` starts **YES**,
`pausesOnCompletion` starts **NO**.

## What `scrubsLinearly` actually changes

It changes one thing, in one place. When the animator pauses -
`-pauseAnimationTransiently` is the path - it asks itself for
`-timingFunctionForPause` and hands the answer to `-_pauseAnimation:`. That
method is three instructions of consequence:

- `scrubsLinearly` is YES: it answers a `CAMediaTimingFunction` of
  `kCAMediaTimingFunctionLinear`, and the paused animation is re-timed with it,
  so `fractionComplete` maps straight onto the animation - a quarter of the
  fraction is a quarter of the way;
- `scrubsLinearly` is NO: it answers `nil`, and the animation keeps the timing
  curve it was built with, so the same fraction lands where that curve says -
  with an ease-in-out curve, a quarter of the fraction is less than a quarter
  of the way, and near the middle the same step moves further.

So the flag is not a mode of the animator but the timing function used while it
is paused. It is read at the moment of pausing and nowhere else, which is why
the release refuses to let it change under a paused animator.

## Changing the flag, and where the releases differ

`-setScrubsLinearly:` of iOS 11 reads `_animationState` first and, when that
state is 4, **returns without storing** - quietly. The current implementation
refuses instead: it raises `NSInternalInconsistencyException` with the reason
`Cannot modify scrubsLinearly while animation is already paused`.

The refusal is in the shared cache of iOS 18.0 too, where the paused branch goes
to the assertion handler. Measured against the host, the flag can be set while
the animator is inactive, while it is running, and after it has been stopped; it
raises only while the animator is paused - and scrubbing an animator built with
animations pauses it, so scrubbing first and setting the flag afterwards is a
case that raises. This package carries the newest behaviour, so the port raises
with the same name and the same reason.

## What scrubbing does, by state

`-setFractionComplete:` is the same method in 11.0 (`0x18ac6403c`), 12.0 and
18.0: it clamps the fraction to the unit range and then looks at
`_animationState`.

- **4, paused**: it stores the fraction and moves the tracked animations there.
- **3**: it starts the animator as paused and sets the fraction again, so the
  animator becomes active and not running, at that fraction.
- **1, running**: it pauses transiently, sets the fraction and continues with
  no new timing and a duration of zero, so the animation jumps there and keeps
  running.
- **Any other state**: it returns without doing anything.

Both 0 and 3 read as inactive from outside. Every new animator starts at 0,
set by `-_setupWithDuration:timingParameters:animations:`. Adding animations
to an inactive animator - `-addAnimations:delayFactor:durationFactor:`, which
is also where an animations block given to the initializer goes - runs the
block and moves it to 3. So an animator built with animations is scrubbed into
active and paused; one built without any stays inactive at a fraction of zero.
The host's UIKit does the same in each of these four cases, and the
differential test holds the port to all of them.

## What `pausesOnCompletion` does

The setter stores a flag and nothing else; everything happens when the
animation reaches its end. Measured on the host, with `pausesOnCompletion` YES
and an animator whose duration has passed:

- the animated value is at its end - the animation has run;
- the animator stays **active** and **not running**;
- the completion blocks have **not** been called;
- `-stopAnimation:NO` moves it to **stopped**, and the blocks are still not
  called;
- `-finishAnimationAtPosition:` then moves it to **inactive** and calls each
  block **once**, with the position it was finished at.

So the blocks are deferred rather than dropped: the animator waits at the end
for the application to say what that end means. With the flag NO, which is the
default, the end finishes the animator and calls the blocks itself.

## What the host cannot show

The mapping `scrubsLinearly` changes is the one thing a windowless host process
cannot measure: without a window nothing commits to Core Animation, the
presentation layer is absent and the model layer already holds the end value,
so both flavours read the same number. The check belongs on the device, in the
animator application that already runs there, where a fraction can be set on a
paused animator and the presentation layer read after a `CATransaction` flush
and a turn of the run loop.
