# CASpringAnimation.initialVelocity and .settlingDuration, iOS 9

`CASpringAnimation` is not new in iOS 9. The armv7 shared caches of iOS 6.0 and 6.1.3 already carry the class in
QuartzCore, with `mass`, `stiffness`, `damping`, `velocity`/`setVelocity:`, `+defaultValueForKey:` and the spring's own
`-_timeFunction:`; it exports `_OBJC_CLASS_$_CASpringAnimation`, so the release solves the spring itself and only the
class's declaration was private. iOS 9 made it public and added `initialVelocity`/`setInitialVelocity:`, `settlingDuration`
and `-_solveForInput:`; iOS 7 had already added `-durationForEpsilon:`. The port therefore adds three methods to the
release's own class and invents nothing.

Read from: the armv7 shared caches of iOS 6.0, 6.1.3, 7.0.1, 8.0, 9.0 and 10.3.4 for which release has which method, and
their method type encodings on 6.1.3, where `mass`, `stiffness`, `damping` and `velocity` are all `f` (a `CGFloat` on
armv7) and take `f`; the arm64 shared cache of iOS 12.0, disassembled, for what the two members do; the host's own
QuartzCore for the differential, `tests/backports/host/spring/run.sh`.

## initialVelocity is the release's own velocity

`-[CASpringAnimation initialVelocity]` on iOS 12 is one instruction and a tail call: it sends `velocity` to itself, and
`setInitialVelocity:` sends `setVelocity:`. The two names are the same property, the public one and the one the class
has had since iOS 6. The port's accessors forward exactly that way, so a value set through either name is read back
through both, which the host differential checks in both directions.

## settlingDuration is durationForEpsilon: with 0.001

`-[CASpringAnimation settlingDuration]` on iOS 12 is a tail call to `-durationForEpsilon:` with the constant 0.001, read
out of the cache's literal pool. `durationForEpsilon:` reads `mass`, `stiffness`, `damping` and `velocity` - the same
selector `initialVelocity` forwards to - and works in double:

- `omega` is `sqrt(stiffness / mass)` and `zeta` is `damping / (2 * sqrt(mass * stiffness))`.
- `zeta` of zero never settles.
- Below critical damping the answer is closed form:
  `(-log(epsilon) + log(1 + |(omega * zeta - velocity) / (omega * sqrt(1 - zeta * zeta))|)) / (omega * zeta)`, floored at
  zero. This is the same curve `UISpringTimingParameters.settlingDuration` already carries from
  `+[UIView _durationOfSpringAnimationWithMass:stiffness:damping:velocity:]`.
- At or above critical damping there is no closed form. Core Animation clamps the spring to critically damped - the answer
  does not change at all as the damping rises from 20 to 26 on a spring of mass 1 and stiffness 100 - and walks time
  forward in steps of 0.1 second, a step read out of the cache's literal pool beside the 0.001, until the remainder
  `|1 + (omega - velocity) * t| * exp(-omega * t)` has fallen to the epsilon and stays there. The answer is always a
  multiple of 0.1.
- `durationForEpsilon:` floors the epsilon it is given at 1e-06. `settlingDuration` always passes 0.001, so the floor
  never bites and the port does not carry it.

The port solves the last root of that remainder analytically, rounds it up to the step and then walks one step either way
until the step is the first one at which the remainder stays below the epsilon, which is the same answer with no loop
over the whole of time: a spring of mass 12, stiffness 7 and damping 100 settles in 12.1 seconds either way. The walk
matters where the velocity is greater than `omega`, because the remainder passes through zero once on its way and the
system does not stop there: mass 1, stiffness 100, damping 25 and velocity 15 settle in 0.9 seconds, not 0.2.

`tests/backports/host/spring/run.sh` compiles this file for Mac Catalyst with its selectors prefixed, adds it to the
host's own `CASpringAnimation` and compares both members over the 32 springs of `tests/backports/device/spring-cases.h`,
which cover the default spring, damping ratios from 0 to 25, velocities forwards, backwards and past `omega`, and an
undamped spring. All 98 checks agree, and a sweep of 4000 random springs over the same range agreed to the last bit of
the printed answer. The answers become `tests/backports/device/spring-expectations.h`, which the device test holds the
release's own class to.

## What differs, and why

- A spring that never settles answers `MAXFLOAT`, which is what the newest QuartzCore answers; the arm64 cache of iOS
  12.0 has `+inf` in that slot instead. The rule of this package is the newest implementation, and both say the same
  thing, so the port carries `MAXFLOAT` and this file names the older answer.
- The port answers `MAXFLOAT` as well where the release lets a spring through with a mass or stiffness of zero or a
  negative damping, which the newer releases refuse in the setter and iOS 6 does not check. Such a spring has no
  settling time, and saying so is better than an infinity or a not-a-number coming out of the arithmetic.
- The release's accessors are `CGFloat`, a `float` on armv7, so the arithmetic starts from single-precision inputs where
  the host starts from double. The difference is in the inputs, not in the formula, and it is the release's own.
- `-durationForEpsilon:` exists from iOS 7. The port does not defer to it on the iOS 7 and 8 bands: one computation
  answers on every band, and it is the one held to the host.
