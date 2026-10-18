# CGAffineTransformDecompose and CGAffineTransformMakeWithComponents, iOS 16

Introduced in iOS 16.0 (SDK 26.2 `CGAffineTransform.h`). The header gives the form: the transform is
scale * shear * rotation, with the translation last, and `CGAffineTransformComponents` holds `scale`, `horizontalShear`,
`rotation` and `translation`. The release's answers are measured on the host, not read off the header's matrix alone,
because the header does not say which of the two sign choices a flip takes, nor what a degenerate matrix answers.

Source: the host's CoreGraphics (macOS 27, SDK 26.2), through `tests/backports/host/affine-components`, which holds the
port's own source against it on 36 fixed transforms and two sweeps of 1000 generated ones (129 checks).

## The matrix

With the matrix `[a b; c d]` acting on row vectors and the translation `(tx, ty)` last, the components give

    a = sx * cos t        b = sx * sin t
    c = sy * (sh * cos t - sin t)        d = sy * (sh * sin t + cos t)

so the first row is `sx` times the rotation's unit vector `u`, and the second row is `sy` times `sh * u + v`, `v` being
`u` turned a quarter. `MakeWithComponents` builds the matrix from these; `Decompose` inverts them.

## Decompose

- `length = hypot(a, b)`.
- If `length` is not zero: `angle = atan2(b, a)`, and `across = d*cos(angle) - c*sin(angle)`, which is the second row's
  component across the first row's direction. The flip is `across < 0` (a negative zero is not a flip). Then
  `sx = flip ? -length : length`, `sy = flip ? -across : across`, and `rotation = angle` less pi where the flip is,
  brought back into `[-pi, pi)` by adding 2 pi when it falls below -pi. The sign of `sx` is the flip, `sy` is not
  negative, and a flip in x gives rotation 0 and a flip in y gives -pi, the host's own signed zero and sign included.
- If `length` is zero (`a` and `b` both zero): the flip is `d < 0`, `sy = |d|`, `sx = 0`, and the rotation is zero or
  -pi with the flip. The first row says nothing here, so this is the only rule the host gives for it.
- `horizontalShear = sy != 0 ? (c*cos t + d*sin t) / sy : 0`.
- `translation = (tx, ty)`.

The sine and the cosine of an angle are taken through `__sincos_stret`, the one call the host's compiler makes for the
pair. The rounding of that pair decides the sign and the size of `sy` and `horizontalShear` for a singular transform,
so the two functions the port makes separately do not reproduce the host there.

`determinant` does not appear: `across` is the same quantity divided by `length`, and taking the sign and the size
from `across` is what the host's rounding follows. A matrix with two non-zero rows that are multiples of each other
(`(2, 2, 1, 1)`, `(3, 1, 6, 2)`) therefore comes back with `scale.height` of about 1e-16 and `horizontalShear` of about
1e16 on both sides.

## Measured answers the rule rests on

| matrix | scale | shear | rotation |
| --- | --- | --- | --- |
| `(-2, 0, 0, 3)` | (-2, 3) | 0 | 0 |
| `(2, 0, 0, -3)` | (-2, 3) | 0 | -pi |
| `(-2, 0, 0, -3)` | (2, 3) | 0 | +pi |
| `(0, 1, 1, 0)` | (-1, 1) | 0 | -pi/2 |
| `(0, 1, -1, 0)` | (1, 1) | 0 | +pi/2 |
| `(0, 0, 0, -2)` | (0, 2) | 0 | -pi |
| `(0, 0, 1, -1)` | (0, 1) | -1 | -pi |
| `(1, 0, 0, 0)` | (1, 0) | 0 | 0 |
| `(-1, 0, 0, 0)` | (1, -0) | 0 | +pi |
| `(2, 2, 1, 1)` | (2.8, 1e-16) | 1e16 | pi/4 |
| `(1, 3, -2, -6)` | (-3.2, 1e-16) | 6e16 | -1.89 |

The last two rows are singular transforms with two non-zero rows; their scale and shear are rounding, and they are in the
battery as `sing1`..`sing8`; the two sweeps hold 2000 generated transforms, 1000 singular and 1000 general.

## Precision

The host's cosine and sine are rounded, so the host's zeros come back as about 1e-16. The battery accepts a relative
difference of 1e-12 (or the absolute difference for a value below 1); the largest measured difference is 6.7e-16.
Of the 129 checks, the round trip (the components rebuild the matrix) is held only for a transform whose determinant is
not zero, since a singular transform with two non-zero rows does not come back from its components on the host either;
the port's components are checked against the host's rebuild of the same components instead.
On armv7 `CGFloat` is a float and the port's answers are float answers; the host test runs the arm64 double path, so the
armv7 rounding of the singular cases is not measured.

## Rounding of the singular case

For a singular transform with two non-zero rows, the shear and the y scale are quotients of rounding, and their last
bits depend on the sine and the cosine the decomposition takes. The header promises no particular rounding for them,
and the release's own pair differs between architectures, so the port does not chase the host's last bit.

What is measured on the host, macOS arm64 (scratch measurement, `__sincos_stret` against `sin` and `cos` over 200000
angles uniform in [-4, 4] with a 1e5 band): the cosine of the pair equals libm's `cos` on every angle; the sine equals
libm's `sin` except on 479 angles (0.24%), every one of them with |x| < 1 and one ulp apart. A double-double reference
(the true value, rounded once) agrees with libm's sine where the pair does not, so the pair itself is not correctly
rounded: it differs from the true value on about 3.7% of the same angles.

The port takes the pair through `__sincos_stret`. The image links it: a build for a release before 7.0 links
apple-compat's `__sincos_stret`, which takes the sine and the cosine as two separate calls, because iOS 6.1.3 exports no
pair: its armv7 dyld cache names neither `_sincos` nor `__sincos_stret`, the 7.0 armv7 cache names `__sincos_stret`, and
the 10.3.4 armv7s cache names `_sincos`.

The separate calls do not reproduce the host on every singular transform. Measured with the affine differential
(`sweep("generated singular", 1, 1000)`), one generated singular transform disagrees with the host by a relative 4.78
(a flip of the rotation, where `across` is at rounding level), and the same battery with the system pair agrees on all
1000 (largest relative difference 6.7e-16 over the whole test). So the iOS 6 path differs from the host by more than
rounding on at least one singular transform, and the earlier figure of 12 differences in the last digits came from an
earlier generator. The crutch is recorded in coordination/crutches.md.
