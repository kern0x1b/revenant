# `CASpringAnimation` on iOS 6

`CASpringAnimation` is the damping-spring animation that QuartzCore added in iOS 9. The backport supplies the class on
iOS 6, 7 and 8 with the SDK's public surface, and leaves the system class in charge where it exists.

`NSClassFromString(@"CASpringAnimation")` is not `nil` on iOS 6. The object returned is a `CABasicAnimation` subclass,
copies and archives as one, and can be added to a layer with `addAnimation:forKey:`. The layer plays the damped-spring
curve.

## Source

| File | Contents |
| --- | --- |
| `frameworks/Backports/src/UIKit/CASpringAnimation.m` | the category on the system class, the layer handoff, and the host build's comparison class |
| `frameworks/Backports/src/UIKit/RevenantCASpringAnimation.h` | the interface of the host build's comparison class |
| `frameworks/Backports/src/UIKit/RevenantSpringSolver.h`, `.m` | position, settling and perceptual-parameter maths |
| `frameworks/Backports/src/UIKit/RevenantSpringKeyframes.h`, `.m` | value interpolation and the keyframe builder shared with `UIView` |
| `frameworks/Backports/tests/QuartzCore/spring_animation_test.m` | the host comparison against the system class |

The former `CASpringAnimation+InitialVelocity.m` category is gone; its declarations and maths are in the class and the
solver.

## Surface and defaults

| Member | Default | Meaning |
| --- | --- | --- |
| `mass` | `1` | mass `m` |
| `stiffness` | `100` | spring constant `k` |
| `damping` | `10` | damping coefficient `c` |
| `initialVelocity` | `0` | initial velocity of the animated value |
| `allowsOverdamping` | `NO` | whether `ζ > 1` uses the overdamped curve |
| `settlingDuration` | derived | time to come within `0.001` of the final value |
| `perceptualDuration` | derived | `2π√(m/k)` |
| `bounce` | derived | `1-ζ` for `ζ ≤ 1`, `1/ζ-1` for `ζ > 1` |
| `initWithPerceptualDuration:bounce:` | — | builds the parameters from the pace and the bounce, then sets `duration` to `settlingDuration` |

The defaults match the system class. `duration` is still a `CAMediaTiming` property: `0` means "use the settling
duration", a positive value truncates or extends the curve.

## The curve

With `ω = √(k/m)`, `ζ = c/(2√(mk))` and `ω_d = ω√|1-ζ²|`, the position is the analytic step response:

- `ζ < 1`:
  `x(t) = 1 - e^{-ζωt}(cos(ω_d t) + ((ζω-v)/ω_d) sin(ω_d t))`.
- `ζ = 1`, or `ζ > 1` with `allowsOverdamping == NO`:
  `x(t) = 1 - (1 + (ω-v)t)e^{-ωt}`.
- `ζ > 1` with `allowsOverdamping == YES`:
  `x(t) = 1 - ½[(1+B)e^{-r_s t} + (1-B)e^{-r_f t}]`,
  where `B = -(ζω+v)/ω_d`, `r_s = ζω-ω_d`, `r_f = ζω+ω_d`.

The overdamped branch reproduces a measured property of the system class: its curve is not the physical solution for the
value in `initialVelocity`. It is the physical solution for `v + 2ζω`, which is what `B` above encodes. The measured
position agrees with the system class at the precision of `double`; the sign of the velocity does not change the rule.
The exponential form is written with the two decaying exponentials rather than `cosh`/`sinh` so that it does not
produce `inf * 0` for long times.

## Settling

`settlingDuration` uses the same threshold as the system class, `ε = 0.001`:

- Underdamped: `t = (ln(1/ε) + ln(1 + |(ζω-v)/ω_d|)) / (ζω)`.
- Critical: the fixed point of `t = (ln(1/ε) + ln(1 + |ω-v|t)) / ω`, quantized to `0.1 s`.
- Overdamped (and allowed): the last time
  `½|(1+B)e^{-r_s t} + (1-B)e^{-r_f t}|` exceeds `ε`, found from the entry root before the curve's zero and the tail root
  after its single extremum, quantized to `0.1 s`.
- `damping == 0`, or parameters that are not finite and positive, return `FLT_MAX`.

The critical and overdamped branches quantize to `0.1 s`; the underdamped branch does not. Both are what the system
class does, measured on macOS against the same parameter sets. The overdamped branch works on the signed sum rather
than on an envelope: near a cancellation between the two exponentials the envelope is the wrong curve, and the system
class follows the cancellation. A grid over masses, stiffnesses, damping ratios and velocities matched the system
class to below `2e-13`.

## Perceptual parameters

`initWithPerceptualDuration:bounce:` maps the pace `T` and the bounce `b` to the spring parameters:

```
m = 1
ω = 2π/T
k = ω²
ζ = b ≥ 0 ? 1-b : 1/(1+b)
c = 2ζω
v = 0
allowsOverdamping = YES
duration = settlingDuration
```

A negative `c` (from `b > 1`) leaves the default `c = 10`. A `T` that is not positive produces an infinite stiffness.
These are the values the system class produces for the same initializer, including the `duration` assignment.

## Delivering the curve on iOS 6

The iOS 6 render server has no spring animation. The object the application holds is still a `CASpringAnimation`; the
layer receives an equivalent `CAKeyframeAnimation`:

- `CALayer -addAnimation:forKey:` is swizzled once at load, and `-runActionForKey:object:arguments:` covers implicit
  actions. A `CASpringAnimation` is converted; every other animation is passed through untouched.
- The duration is the animation's `duration` when positive, otherwise `settlingDuration`.
- The curve is sampled at `60 Hz`: `ceil(duration * 60) + 1` values, with the interval count capped at `4096`.
- `fromValue` and `toValue` are used as given. Missing values are resolved from `byValue` and the layer's current model
  value using the same rules as `CABasicAnimation`: `to - by`, `from + by`, or the current value. Additive animations use
  the zero value where the basic animation would use zero.
- Values may be `NSNumber`, `CGPoint`, `CGSize`, `CGRect`, `UIEdgeInsets` (iOS only), `CGVector` or `CATransform3D`.
  `CATransform3D` values are interpolated by decomposing affine transforms into rotation, scale and translation, and
  component-wise otherwise.
- An unsupported value type, a cumulative animation, a value function, or a non-positive or non-finite duration is left
  as the inherited `CABasicAnimation`. The iOS 6 render server then runs it as a basic animation, not as a spring.
- Timing properties, `additive` and `delegate` are copied to the keyframe animation. `beginTime` is copied; the `UIView`
  spring path still offsets it by its delay.

Two consequences for an application that inspects the animation: `-[CALayer animationForKey:]` returns the keyframe
animation, not the spring, and a delegate's `animationDidStop:finished:` receives the keyframe animation. The
application's own `CASpringAnimation` object is unchanged, and copying or archiving it preserves the spring parameters.

## The class

The class is the device's own `CASpringAnimation`, which iOS 6.1.3 has with `mass`, `stiffness`, `damping` and
`velocity`. The backport adds a category to it (`CASpringAnimation (Revenant)`): `initialVelocity` over `velocity`,
`allowsOverdamping` in associated storage, the computed durations and the perceptual initializer. The binary defines no
`_OBJC_CLASS_$_CASpringAnimation` and `shadowed-classes.txt` has no entry for it, so an application that names the class
binds the device's class and finds the added members on it.

`copyWithZone:`, `encodeWithCoder:` and `initWithCoder:` are replaced with `class_replaceMethod` on `CASpringAnimation`
only, and only when the class itself implements the selector. The replacements call the implementation they found and
add `allowsOverdamping`. `CABasicAnimation`, `CAKeyframeAnimation` and `CAAnimationGroup` keep their own methods; the
runtime case `caspring_animation_coding` copies and archives each of them and a spring and measures that.

The host build, which has no device class, compiles `RevenantCASpringAnimation` for the comparison test.

## Limits

- The curve on iOS 6 is piecewise linear between 60 Hz samples. It is not the render server's own spring solver, and a
  layer with a very short duration gets fewer samples.
- Colour values (`CGColorRef`), `CGPath` and other types that are not in the list above fall back to the basic
  animation.
- The affine decomposition ignores shear; a sheared transform takes the component-wise path.
- The system class on iOS 9 and later is used as it is. The backport does not add properties or methods to it.

## Tests

`frameworks/Backports/tests/QuartzCore/spring_animation_test.m` runs on macOS. It builds the solver, the keyframe
builder and the class with `REVENANT_HOST_BUILD`, and compares:

- `settlingDuration` for 21 fixed parameter sets, over underdamped, critical and both overdamped branches, with
  tolerance `1e-6`, and for a 2,464-set grid over four masses, four stiffnesses, fourteen damping ratios and eleven
  velocities, with the same tolerance;
- 101 position samples per fixed set against the system class's `_timeFunction:`, with tolerance `1e-9`; the probes
  behind the solver measured errors around `1e-16`;
- the perceptual constants, `settlingDuration`, `perceptualDuration`, `bounce` and `duration` for 12 pace/bounce pairs,
  with relative tolerance `1e-9` for the constants and `1e-6` for settling;
- defaults, copy, secure archiving and the keyframe builder's samples, `byValue` resolution and unsupported-value
  fallback.

`_timeFunction:` is a private method of the system class. The test uses it only as the measurement oracle; the shipped
code does not call it.
