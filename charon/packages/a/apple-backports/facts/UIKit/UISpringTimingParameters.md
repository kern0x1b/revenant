# UISpringTimingParameters

Introduced in iOS 10.0. A spring, given either as mass, stiffness and damping or
as a damping ratio, with an initial velocity.

Source: UIKit of the armv7s cache of iOS 10.3.4.

## Two forms, one flag

A private `implicitDuration` says which form the object is in. It is set by
`-setMass:`, `-setStiffness:` and `-setDamping:`, so the mass form has it and the
damping-ratio form does not, and everything that has to tell the two apart -
copying, archiving, the description - reads it.

| member | behaviour |
|---|---|
| `-init` | mass 3, stiffness 1000, damping 500, through the setters, so the mass form. |
| `-initWithMass:stiffness:damping:initialVelocity:` | the mass form. |
| `-initWithDampingRatio:initialVelocity:` | the ratio form. |
| `-initWithDampingRatio:` | the same with a zero velocity. |
| `-timingCurveType` | `UITimingCurveTypeSpring`. |
| `-springTimingParameters` | the receiver; `-cubicTimingParameters` is `nil`. |
| `-dampingRatio` | the stored ratio in the ratio form; `damping / (2 * sqrt(mass * stiffness))` in the mass form, and 0 rather than an infinity when that divisor is 0. |
| `-description` | `<%@ (%p) mass=%.3f, stiffness=%.3f, damping=%.3f, velocity=(%.3f,%.3f)>` for the mass form, `<%@ (%p) dampingRatio=%.3f, velocity=(%.3f,%.3f)>` for the other. |

The default spring, mass 3 against stiffness 1000 with damping 500, has a damping
ratio of about 4.56: it is heavily overdamped and does not overshoot.

## Archiving

| key | encoded with | decoded with |
|---|---|---|
| `implicitDuration` | `-encodeBool:forKey:` | `-decodeBoolForKey:` |
| `mass`, `stiffness`, `damping` | a scalar, only in the mass form | the same |
| `dampingRatio` | a scalar, only in the ratio form | the same |
| `velocity` | `-encodeCGVector:forKey:` | `-decodeCGVectorForKey:` |

The scalars are encoded at the width of a `CGFloat`: `-encodeFloat:forKey:` where
it is a float, as it is on every architecture this package is built for, and
`-encodeDouble:forKey:` where it is a double. Apple's own code is the same source
built for both, and reading the armv7s binary alone would have said float
everywhere; the host, where a `CGFloat` is a double, is what shows the other half.

Non-keyed coders raise `NSInvalidUnarchiveOperationException`:
`%@ only supports keyed coding.`

`-encodeCGVector:forKey:` and `-decodeCGVectorForKey:` are themselves later than
iOS 6, and the SDK header carries **no** availability for them, so nothing warns
at compile time and the archive simply raised an unrecognised selector on a
release without them. They are carried beside this class. UIKit writes the vector
as a string through `-encodeObject:forKey:` and reads it back with
`-decodeObjectOfClass:[NSString class] forKey:`, in the shape
`NSStringFromCGPoint` writes, so an archive crosses to a release that has them.
The package's own selector check is what found this; the host could not, because
the host has the methods.

## Settling

`-settlingDuration` is private and answers how long the spring takes to come to
rest. On iOS 10 it calls
`+[UIView _durationOfSpringAnimationWithMass:stiffness:damping:velocity:]`, which
iOS 6 has not got, so the formula is carried here. It is read off UIKit of the
armv7s cache of iOS 10.3.4.

A spring in the damping-ratio form carries no mass, stiffness or damping, and
answers **0**, not an infinity.

Otherwise the duration is taken for **each component of the initial velocity
separately and the larger of the two answered** - the `fmaxf` at the end of the
method. That one step explains everything that looks strange from outside: a
velocity of (10, 0) and one of (0, 10) settle alike, (6, 8) settles as 8 does
rather than as its length 10 would, and reversing the sign changes the answer.

For one component:

```
zeta = damping / (2 * sqrt(mass * stiffness)), clamped to [0, 1]
zeta == 0                    -> the duration is infinite
frequency = sqrt(stiffness / mass)

zeta < 1:
    decay  = frequency * zeta
    damped = frequency * sqrt(1 - zeta * zeta)
    duration = max( (-ln(0.001) + ln(1 + |(decay - velocity) / damped|)) / decay , 0 )

zeta >= 1:
    reach     = frequency - velocity
    logarithm = ln| 0.001 * frequency * exp(-frequency / reach) / reach |
    amplitude = -1 - logarithm
    fitted    = 1 + (0.3361 * sqrt(amplitude / 2))
                  / (1 - 0.0042 * amplitude * exp(-0.0201 * sqrt(amplitude)))
    corrected = logarithm + (-5.9506097239272915) * (1 - 1 / fitted)
    duration  = -(frequency + reach * corrected) / (frequency * reach)
```

`-ln(0.001)` is in the binary as `6.9077552314846873`, and 0.001 separately: the
spring is called settled when it is within a thousandth. The square root of a
negative gives a NaN rather than raising, as `vsqrt.f32` does, and the logarithm
is taken of the magnitude by clearing the sign bit.

That the transcription is right is not only a matter of comparing answers: at a
velocity of zero the second branch collapses to `9.235036526651854 / frequency`,
and the host, measured independently, answers `9.235037` - seven digits from the
code rather than from fitting.

The upper half of the clamp on `zeta` cannot be observed. The branch is chosen by
whether `zeta` is below one, and the clamped value is only used where it is, so
clamping it to one changes nothing; the differential test cannot tell the two
apart. It is kept because Apple's code has it.

## The host as an oracle

Everything here was checked against the host's own UIKit over a grid of four
masses, four stiffnesses, five dampings and six velocities - 480 springs - and
every one agrees. That is worth stating because the host is a later UIKit than
the one the formula was read from, and the two **have** differed elsewhere: they
differ over the control points of a builtin cubic curve, which
`UICubicTimingParameters` documents. Here they do not.

A settling duration is compared with a tolerance rather than bit for bit: UIKit
computes it in the width of a `CGFloat`, a float where this package is built and
a double on the host, and the two round apart in the ninth digit.
