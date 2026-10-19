# UIViewPropertyAnimator

Introduced in iOS 10.0. An animation that can be paused, scrubbed, reversed and
carried on.

Source: UIKit of the armv7s cache of iOS 10.3.4. There is no host to compare
against - Mac Catalyst raises no `UIWindow`, and there is neither a simulator nor
a device of iOS 10 here - so every expectation is read off the algorithm and then
held to on iOS 6.

## Interruptible decides everything

`-startAnimation` runs the blocks through UIView's own animation and then, **if
the animator is interruptible**, immediately pauses what it added and replaces the
curve with a linear one, taking the timing into its own hands. That is not a
choice Charon made to save work: it is what UIKit does, in `-startAnimation:`,
the moment such an animator starts, and `interruptible` is what an animator is
unless it is told otherwise. An animator that is not interruptible is left to
Core Animation.

So the cost of driving an animation by hand is a cost Apple pays too, on iOS 10,
for the ordinary case.

## Only its own animations

UIKit keeps a register of the animations **it** added, under a UUID, through
`+[UIView _enableAnimationTracking:]` and the pair that brackets the blocks, and
`-modifyTrackedAnimations:removeOnCompletion:animationFactory:block:` rebuilds
them when the fraction moves.

Charon does the same by other means: the animation keys of every layer are taken
before the blocks run, and only the keys that appear afterwards belong to this
animator. It then holds a layer **and a key**, not a layer.

This matters more than it looks. Stopping a layer stops everything on it, so an
animator that froze every layer it found animating would freeze animations it
never started, two animators at once would each stop the other, and clearing up
would remove another animator's work. Charon stops the **animation's** own
`speed`, not the layer's, so anything else on the same layer keeps running.

A running animation cannot be changed where it lies, so moving the fraction means
building the animation afresh and putting it back under the same key - which is
what Apple's animation factory is for.

## Assertions, not exceptions

Seven of the complaints are `NSAssert`, which goes through `NSAssertionHandler`
and is **silent in a release build**. They are carried as assertions, so a
release behaves as Apple's does:

- `An animator (%@) must have at least one animation block to start!`
- `An animator (%@) can be only started in the paused state if it is interruptible!`
- `An animator %@ that is not interruptible cannot be paused!`
- `An animator %@ that is not interruptible cannot be stopped!`
- `Animator %@ is already stopped!`
- `An animator %@ that is not interruptible cannot be continued or reversed!`
- `A paused animator (%@) cannot be started with a delay!`
- `finishAnimationAtPosition: should only be called on a stopped animator!`

Two are real exceptions and are raised as such:

| when | what |
|---|---|
| `-setInterruptible:` on an active animator | `NSGenericException`: `It is not allowed to set the interruptible property of an active animator (%@)` |
| `-startAnimationAfterDelay:` with a delay below zero | `NSInvalidArgumentException`: `The delay should be greater than or equal to zero.` |

## State, and what it tells

`state`, `running`, `reversed` and `fractionComplete` are sent by hand with
`-willChangeValueForKey:` and `-didChangeValueForKey:` - the class does not rely
on automatic notification. `-_stateAsString` answers `inactive`, `stopped`,
`active` or `unknown`, and the description reads
`<%@(%p) [%@]%@%@%@>` with ` running`, ` reversed` and ` interruptible` appended
where they hold.

Inside, the state is one of five numbers, and `-state` maps them through a table
(`0x20cf7e40`, mask `0x1b`): 0 and 3 read as `inactive`, 1 and 4 as `active`, 2 as
`stopped`. The two inactive states are not the same. A new animator is 0;
`-addAnimations:delayFactor:durationFactor:` moves an inactive one to 3
(`movs r0, #3` at `0x20a446ea`), so an animator built with its blocks is 3 from
the start. 1 is running and 4 is paused.

`-setFractionComplete:` (`0x20a48b6c`) clamps to `[0, 1]`, does nothing if the
value is the one it already has, and then:

- at 3 it starts the animator paused and sets the fraction on it, so scrubbing an
  animator that has blocks and has not started leaves it **active and not
  running** at that fraction;
- at 4 it moves the paused animation to the fraction;
- at 1 it pauses, sets the fraction and carries on (`-pauseAnimationTransiently`,
  `-setFractionComplete:`, `-_continueOrReverseAnimations:timingParameters:duration:`
  with none and zero), so a running animator **jumps and keeps running**;
- at 0 and 2 nothing happens.

11.0, 12.0 and 18.0 do the same.

`-stopAnimation:` (`0x20a48690`) acts only on an active animator. With **YES**
it drops the completion blocks (`-_setCompletions:nil`), stops where it stands
and leaves the animator **inactive**: no completion is ever called. With **NO**
it stops where it stands and leaves the animator **stopped**, and
`-finishAnimationAtPosition:` then calls the blocks with the position given.

`-finishAnimationAtPosition:` (`0x20a441f0`) asserts that the state is 0 or 2
(`orr r1, r0, #2; cmp r1, #2`), and works only at 2: on an inactive animator
that has no blocks waiting it quietly does nothing, and on one that has blocks
waiting it is the assertion.

`-copyWithZone:` carries the duration, the curve, `userInteractionEnabled` and
`interruptible`, and carries **neither** the blocks, the completions nor the
state.

## What it costs

One scrub step rebuilds the animation, and on an iPhone4,1 running 6.1.3 that
is about 109 microseconds against a display frame of 16667; freezing the layer
instead would be 4.4 and wrong, since it stops animations this animator never
started.
