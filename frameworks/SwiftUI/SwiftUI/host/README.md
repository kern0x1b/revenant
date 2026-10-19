# host probes

The programs here are how a value that only Apple's framework knows was measured, kept in the tree so
the number next to it can be reproduced by whoever reads it. They build and run on the **host** — macOS
with the toolchain of `pkg-env.sh` — and are not part of the module.

```
$ swiftc -O hostrenderer.swift -o hostrenderer && ./hostrenderer
colorMode=nonLinear rendersAsynchronously=false isOpaque=true
drawsPlatformViews=true prefersDisplayCompositing=false
maxDrawableCount=3 rbColorMode=nil
```

Those are the seven defaults of `_RendererConfiguration.RasterizationOptions` in
`eidolon/Sources/SwiftUI/Rasterizations.swift`. The SDK interface declares the seven properties and a
bare `init()` and gives no value for any of them, so the framework itself is the only source there is,
and the type is underscored — which in Swift is public, so the host can name it.

`springcmp.swift` compares the port's `Spring` with Apple's `SwiftUI.Spring` over value, velocity, update and the
Animatable forms of both, for critical, under-damped and over-damped springs; the command is in its header, and
its last line is `compared N numbers; worst difference ...` after a `DIFF` line for every number that is not Apple's.
It also compares equality and hashing of springs and of the animations made of them, and, for
`Animation.interpolatingSpring`, the mass, stiffness and damping Apple's animation holds (read out of it by reflection)
and the values it answers. Those values are asked of `Animation.animate(value:time:context:)`, whose `AnimationContext`
has no public initializer, so the program builds one in memory from an `AnimationState` and `EnvironmentValues`
(a 26-byte struct on this host: the state at offset 0, the environment at 8, two flags after); if a later macOS changes
that layout, the values come out wrong or the program crashes, and the held numbers and equalities still stand alone.
The same context answers for `Animation.spring` and its named forms, asked in step order from one context (the animation
integrates from the state it kept, and a question asked cold far into it is answered wrongly): `FluidTrack` is compared with
its staircase of steps of a three-hundredth of a second and with the step after which it answers nothing, over the responses,
fractions and distances of the program, for a pair of numbers as a distance, and for the springs no one means (a response of
nothing, a negative or undamped or runaway one, a number that is not one).
Where Apple's answers stop is measured, not assumed, and there is no limit of the port's own: the fluid spring is asked step by
step from one context until the step it answers nothing at, for fractions of a thousandth, ten-thousandth and hundred-thousandth
(a fraction of 0.00001 rests after 12751650 steps, eleven hours and forty-eight minutes, and the port's `FluidTrack` finds the same
step, taking steps only as far as it is asked). `Spring.settlingDuration` looks at 1013 tenths of a second and answers nothing when the last
is still out, and a critical interpolating spring is over at once when none of its first 1012 tenths is inside a thousandth; the
program bisects the response, and the stiffness for masses of a half, one and two, at which Apple's starts to, and compares just
under and just over (not at the ulp the bisection ends at, where the two sides round differently). The whole program takes
about four seconds on this host, the long fluid springs included.

`retargetcmp.swift` is the one that needs a window server: a value told to go somewhere else while it is on its way, Apple's against
the port's `Passage` (`Flights.swift`). Apple's is a `Shape` in an `NSHostingView` in a window that is never shown, which records the data it
is drawn with and the time, the first animation begun from nothing and the second (or none) a number of seconds into it. The port is asked for
the number at the time of each record, and a record is matched if the port has it at any time within three thousandths of a second of
it (the run loop gives the moments, and the fluid spring is a staircase of steps of a three-hundredth). The command is in its header; it
takes about ten minutes, and `retargetcmp pins` prints the lines for `Tests/main.swift` instead (the width of a bar at moments after the
second animation began). A fluid spring that is delayed or sped up and told to go somewhere else is the case left out: no rule fitted
it (a curve, fresh from where the value is, fresh from where it is when the delay is over, a speed from the first, or any speed at all,
none within a hundredth), so the port starts it from where the value is with no speed, as it did before.
