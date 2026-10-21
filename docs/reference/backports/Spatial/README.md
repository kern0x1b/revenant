# Spatial: what is built here, and what is measured

(a file of an earlier layout, not in the repository) is the source of the `Spatial` module `xmake.lua` builds
into `libswiftSpatial.dylib`, for a release that has no Swift module of its own: the SDK carries
Spatial for arm64 only, and every release this runtime targets is armv7. The five templates are
gyb's, and each writes both scalars, because every type has a `Float` twin that differs only in the
scalar.

## The build, and what it was measured with

`swiftc -target armv7-apple-ios6.1.3 -emit-module -emit-object` over the generated sources, with
the recipe's own flags, against the armv7 standard library built in
(a workflow file kept outside the repository) (Swift, SwiftOnoneSupport and the supplemental
libraries for `armv7-apple-ios`, plus `layouts-armv7.yaml`) and the compiler's own `clang`,
`apinotes`, `module.modulemap` and the study's `shims`: EXIT 0, `Spatial.swiftmodule` 1262020
bytes and `Spatial.o` 1121024 bytes written. The recipe's install path itself is not run here: no
swift-runtime install exists in the shared store (`~/.xmake/packages/s/swift-runtime/6.4.0` is
empty), and building the package is the coordinator's, not a band's.

Two spellings in the templates are the port's own and are named where they are used, because the
host's own Foundation hides both:

- the C library's math is named per scalar and through `Darwin` (`acos` beside `acosf`), and not as
  `Foundation.acos`. Apple's Foundation re-exports the shims that declare the Float half as
  `Float(acosf(CFloat(x)))` (macOS SDK, `_DarwinFoundation1.swiftinterface:237`); this runtime's
  Foundation is swift-corelibs-foundation and declares no math, so `Foundation.acos` reaches the C
  library's `double acos(double)` and every Float call was a type error - 58 of them, one per call
  site, before the change.
- the transformations compose on the right. The host's scale of (2, 3, 4) turned by 0.7 rad about
  (1, 2, 3) answers the first column `(1.5632783478140497, 1.650351692113075, -1.1758315137543223)`,
  which is `self * r`; `r * self` is `(1.5632783478140497, 1.1002344614087167, -0.58791575687716113)`.

## The host differential found, and what it still finds

`tests/backports/host/spatial` builds one file of 943 values twice - against Apple's
Spatial.framework and against this module - and compares them number by number. It is **red**:
**940 agree, 3 differ**, so nothing in this module is claimed verified and no registry row is
written for it ((a workflow file kept outside the repository)).

Closed against it, each one a measured difference:

| what | the host answers | what it was |
| --- | --- | --- |
| `Foundation.<math>` for the Float half | 58 type errors before the change | swift-corelibs-foundation declares no math, so the name reached `double acos(double)` |
| `floor`, `ceil`, `remainder`, `simd_angle` | each is declared twice, once per scalar, and this release's headers bring the double one first | named per scalar and through `Darwin` |
| `Rotation3D.rotated(by:)` | `a.rotated(by: b)` is `(b * a)` | returned the argument; the quaternion form returned `self` |
| `Ray3D.init` | a direction of zero length stays (0, 0, 0) | became (nan, nan, nan), and `Ray3D.zero.isZero` false |
| `contains(anyOf:)` | any of the points | `allSatisfy` |
| `Rect3D.scaledBy` | the origin is scaled with the size | kept the origin |
| the transformations' composition | on the right, and a translation composes through the linear part | on the left, and a translation overwritten |
| `invertedMatrix` | no trap | a sixteen-entry array indexed to 31, and then a column-major list with row operations run on it |
| `invertedMatrix3x3` | the inverse | three coordinates of the matrix, not the adjugate |
| `AffineTransform3D.inverted()` | the elimination's own answer | the adjugate's, right for a diagonal and wrong for a general three-by-three |
| `Pose3D.matrix`, `ScaledPose3D.matrix` | the position in the fourth column, unrotated | `translated(by:)` composed it through the rotation |
| `flipped(along:)` | `D * M * D`: the row and the column of that axis, and the translation's component | the translation's component alone |
| `EulerAngles`' order | one extraction per order | one extraction for both, composed in the order given |
| `ProjectiveTransform3D.scaleComponent` | the length of each column of the three-by-three | the fourth column, which is the translation |
| `Point3D.rotation(to:)` | the rotation of the two points' own vectors | the rotation of their difference onto zero, which is no rotation |
| the Float half's pi | `Float.pi` | the Double's, so the Float's arithmetic left the Float |

Three values do not agree with the host, and the coordinator ruled on 2026-10-04 that they are
**named, measured divergences** rather than a widened tolerance. `check.lua` carries them in
`DIVERGENCES`, each with the host's value, the port's value and the reason, and then compares both
columns **exactly** against what the run produced - so a difference anywhere else still fails, and
one of the three moving in either column fails too. No tolerance is widened anywhere, and the
green suite is what lets the mutation control run at all:

```
values: 943, agree: 940, named divergences: 3, differ: 0, largest relative difference: 4.76667e-07
mutations: all caught
```

The three, as recorded:

| value | host | port | why |
| --- | --- | --- | --- |
| `d.rotation.eulerAngles.xyz.z` | 0.61327141523361206 | 0.61327139037901746 | the last term of the extraction, on a matrix the two sides print the same seventeen digits for; the other two terms agree to one ulp |
| `d.rotation.eulerAngles.zxy.y` | 0.40688398480415344 | 0.40688398209126875 | the last term of that order's extraction, on the same matrix; six formulas computed on it, the Float-rounded ones included, reach no better than 4e-9 |
| `f.description` | `(radians: 0.5235988)` | `(radians: 0.52359873)` | the Float half's degrees to radians rounds three ulps from the host's, on operands both sides agree on - `Float.pi` prints 3.1415925 either way |

Both controls, run on this tree: a planted 0.5 over `d.angle.radians` exits 1, and one of the three
moved by a unit in the last place exits 1.

## What of Apple's surface this module does not carry

Measured by the two compiles in `run.sh`, not by this file: the coordinate-space family
(`CoordinateSpace3D`, `CoordinateSpaceValue3D`, `WorldReferenceCoordinateSpace`), `swingTwist`,
`slerp`, `spline`, `changeBasis(from:to:)`, `Point3D.unapplying(_: ScaledPose3D)`,
`ProjectiveTransformable3DFloat.applying`, the C-level `__SPEulerAngleOrder.pitchYawRoll`, and the
per-axis `minX`/`midX`/`maxX` of `Rect3DFloat`. And what this module carries that Apple's surface
does not declare: `AffineTransform3D.applying`, `ProjectiveTransform3D.matrix3x3`,
`Rotation3D.affineTransform`, `Rotation3D.isUnit`, `Rotation3D.rotation(to:)`, `EulerAngles.vector`,
`Rect3D.mid`, `Rect3D.merged`, `Ray3D.contains`, `Point3D.uniformlyScaled`, `Vector3D.translated`,
`SphericalCoordinates3D.isZero`, `Vector3D.vector`/`simd`, and `ProjectiveTransform3D.scaleComponent`
as a `SIMD4` where Apple's is a `Size3D`. Those are the names rule R4 of (a file of an earlier layout, not in the repository)
section 4 is about: a name no SDK header declares.