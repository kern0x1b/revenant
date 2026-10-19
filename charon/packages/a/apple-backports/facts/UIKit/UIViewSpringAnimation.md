# UIView spring animations, iOS 7

Source: the host's own UIKit, under Mac Catalyst, asked for the spring of 72 animations - six durations from 0.1 to 2
seconds, six damping ratios from 0.05 to 1.5 and two initial velocities, 0 and -3 - and CoreAnimation's own
`CASpringAnimation` under AppKit, which draws the curves, held against the backport by
`tests/backports/host/uikit2/run.sh` (`spring_uikit`, `spring_ours` and `spring_sample`: 149 and 162 checks); and iOS
6.0 and 6.1.3 on the emulator, an iPhone 4S and an iPad 2, through `tests/backports/device/uikit2.m`.

## What UIKit makes of the arguments

`+animateWithDuration:delay:usingSpringWithDamping:initialSpringVelocity:options:animations:completion:` runs the
animations block and gives each property it changes a `CASpringAnimation`, whose stiffness and damping UIKit works out
from the duration, the damping ratio and the velocity so that the spring has settled at the end of the duration. The
numbers it works out are what the host answered for the 72 cases, and they are what the port is held to.

## What the port does

The port solves the same problem. The damping ratio is taken from 1.1920929e-07 to 1, the natural frequency is found from
a start of 2 pi over the duration by Newton's method, in at most 20 steps, until the amplitude of the spring at the
duration is 0.001, and the stiffness is the square of the frequency and the damping twice the ratio times the frequency.
Held against the host's own answers, the stiffness and the damping agree to a part in a thousand in all 72 cases,
and an undamped spring with no velocity, for which the equation has no solution, is answered with none.

The curve is the spring's own: the progress at a time is 1 minus the decaying oscillation the frequency and ratio
describe, with the initial velocity taken into account, and it is what the port samples 60 times a second of the duration,
at least twice and at most 600 times, into a linear keyframe animation, as many samples as it takes to be drawn where
`CASpringAnimation` would draw it: the port's samples agree with a real `CASpringAnimation` sampled at the same times.
The last sample is the target value itself.

The values interpolated are numbers, points, sizes, rectangles, edge insets, vectors and transforms - a transform as
the rotation, scale and translation it is made of when it has no shear, and component by component when it has -
and an animation of anything else, or between values of two types, is left as the release animates it.

Whatever is not solved is animated as an ease-out of the release: a duration of zero, an undamped spring, and an
animation whose duration is not the one asked for (more than one part in ten thousand off, which is one that another
block began). The keyframe animation takes the delay, the speed, the offset, the repeats, the reverse and the fill of the
animation it replaces, and the completion handler is called once when all of them have stopped, with NO if any was
interrupted.

## What iOS 6 differs in

iOS 6 has no spring animation of its own, so the port replaces what the block animated after the fact, and only the
layers of the application's windows are looked at: an animation that was begun outside them is not replaced. The
newest release's own spring also settles by a criterion of its own that was compared here only by the stiffness and damping it
resulted in.
