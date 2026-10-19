# UICubicTimingParameters

Introduced in iOS 10.0. A cubic timing curve, either one of the four
`UIViewAnimationCurve` values, Core Animation's own default, or two control
points.

Source: UIKit of the armv7s cache of iOS 10.3.4, and the newest implementation
on the host where the two differ; the one place they do is named below.

## One number holds the curve

The class keeps a single number for the curve, and every value of it is a state:

| value | meaning |
|---|---|
| 0 … 3 | the four `UIViewAnimationCurve` values |
| 5 | Core Animation's own default curve, which `-init` sets |
| 6 | the curve is carried by two control points |

`-timingCurveType` answers `UITimingCurveTypeCubic` when that number is 6 and
`UITimingCurveTypeBuiltin` for everything else. `-animationCurve` answers the
number as it stands, so after `-init` it is 5, which is no valid
`UIViewAnimationCurve`.

| member | behaviour |
|---|---|
| `-init` | the curve is 5, Core Animation's default. |
| `-initWithAnimationCurve:` | the curve is the one given. |
| `-initWithControlPoint1:controlPoint2:` | the curve is 6 and a `_UIViewCubicTimingFunction` holds the points. |
| `-cubicTimingParameters` | the receiver. |
| `-springTimingParameters` | `nil`. |
| `-controlPoint1`, `-controlPoint2` | the timing function's points, or `CGPointZero` when there is none. |
| `-effectiveTimingFunction` | private; see below. |
| `-description` | `<%@ (%p) timing function = %@>` for a cubic curve, `<%@ (%p) builtin type = %@>` otherwise, where the name is `EaseInOut`, `EaseIn`, `EaseOut`, `linear`, `CA Default` or `unknown`. |

## Resolving a builtin curve

`-effectiveTimingFunction` does not answer a `CAMediaTimingFunction`. It makes
one - `+functionWithName:` for a builtin curve, mapping 0 to
`kCAMediaTimingFunctionEaseInEaseOut`, 1 to `…EaseIn`, 2 to `…EaseOut`, 3 to
`…Linear` and 5 to `…Default` - then reads its control points at indices 1 and 2
with `-getControlPointAtIndex:values:` and answers a `_UIViewCubicTimingFunction`
made from those two points. A number that is none of those raises
`NSInvalidArgumentException`: `Unknown/Unsupported UIViewAnimationCurve type %ld`.

## The one difference from iOS 10

On iOS 10 `-init` and `-initWithAnimationCurve:` call `-effectiveTimingFunction`
and **throw the answer away**: the ivar stays empty, so `-controlPoint1` and
`-controlPoint2` answer `CGPointZero` for every builtin curve. Ease-in-out, whose
curve really is (0.42, 0) to (0.58, 1), reads as two zero points.

A later UIKit keeps the resolved function, and those properties answer the real
points. Charon keeps it too, by the same rule as the coefficients in Foundation:
a property documented to answer a curve's control points and answering zeroes
instead is a defect Apple itself corrected, and carrying it forward would be
carrying a bug with our name on it. Nothing else changes - the type stays
builtin, and the archive still carries the curve rather than the points.

## Copying

`-copyWithZone:` (`0x20a4109a`) makes a cubic copy from the two control points
with `-initWithControlPoint1:controlPoint2:`, and a builtin one with
`-initWithAnimationCurve:` of the same curve, so the copy resolves its own
function. Making it with `-init` and changing only the number afterwards would
leave the copy holding Core Animation's default curve under the name of the one
it was asked for, and an animator, which keeps a copy of its parameters, would
run that curve instead.

## Archiving

| key | encoded with | decoded with |
|---|---|---|
| `curveType` | `-encodeInteger:forKey:` | `-decodeIntegerForKey:` |
| `timingFunction` | `-encodeObject:forKey:`, only for a cubic curve | `-decodeObjectForKey:` |
| `animationCurve` | `-encodeInteger:forKey:`, only for a builtin one | `-decodeIntegerForKey:` |

A coder that does not allow keyed coding raises
`NSInvalidUnarchiveOperationException`: `%@ only supports keyed coding.`
