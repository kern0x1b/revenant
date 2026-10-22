# Spatial: sources and the Float twin

## The files

- `SpatialFoundation.swift`, `SpatialGeometry.swift`, `SpatialMatrix.swift`, `SpatialProtocol.swift` and
  `SpatialTransform.swift` hold each scalar-dependent family once, written for `Double`. Their `Float` half is not
  in the tree: `frameworks/Backports/tools/spatial_float.lua` writes it into the target's generated folder as
  `<Name>Float.swift`, at configure time, from the Double text.
- `SpatialScalarIndependent.swift` holds what carries no scalar: `Axis3D`, `Dimension3DSet`, `SPEulerAngleOrder`,
  the un-parameterised protocols the two halves' concrete types are named through (`Primitive3D`,
  `Translatable3D`, `Rotatable3D` and the rest), and the two tolerances.
- `SpatialSIMDHelpers.swift` holds the helpers on `simd` that this release does not spell, written out for both
  scalars by hand: `identity3x3`, `first3`, `floor3`, `ceil3`, `indexOfFlip`, and the extensions on the matrices.

## The Float twin

The generator takes each Double file and rewrites it line by line:

- `Double` becomes `Float`; `simd_double...` becomes `simd_float...`; `simd_quatd` becomes `simd_quatf`.
- The C math is named per scalar: `Darwin.sin` becomes `Darwin.sinf`. The spelling `Foundation.acos` is not used
  for it: this runtime's Foundation is swift-corelibs-foundation, which declares no math, so `Foundation.acos`
  reaches the C library's `double acos(double)` and a Float argument does not convert. On the host, Apple's
  Foundation re-exports the shims that declare the Float half as `Float(acosf(CFloat(x)))`, which is the call made
  here.
- Every type a Double file declares takes the suffix `Float`, and so does every reference to it. `defaultTolerance`
  becomes `defaultToleranceFloat`.
- A conformance list is the one place the two halves differ beyond names: the Float half names its protocols per
  scalar and drops the un-parameterised ones. The table in the tool holds the lists that differ, one per row, and a
  list it does not hold fails the generation if it names an un-parameterised protocol.
- A string literal is never renamed.

The Float half's pi is the scalar's own, `Float.pi`, and not the Double's unqualified one: converting the Double
pi loses the Float's own rounding, and the host's `Angle2DFloat.degrees(30).radians` prints `0.5235988` where that
route prints `0.52359873`.

## The matrices

- The matrices are column-major, as `simd` and every graphics API on the platform spell them. A point and a
  direction are column vectors on the right of the matrix, which is why the geometry types apply one with
  `simd_mul(matrix, vector)`, and why a vector of the affine four-by-three carries a `w` of zero where the
  four-by-four carries one.
- `simd` gives no `inverse` on a four-by-four at this deployment target. The inverse is Gauss-Jordan elimination
  with partial pivoting, on a flat list with the matrix and the identity side by side and both halves row-major:
  the entry (row, column) of the matrix is at `row * 4 + column` and of the identity at `16 + row * 4 + column`.
  Row-major makes a row operation four consecutive entries and the pivot for a column the largest entry down it.
  The two halves are laid out one after the other and not interleaved row by row: an interleaved list puts the
  identity's row `r` at `8 * r`, and every row operation then lands on the wrong four entries. A column whose
  largest entry is zero leaves the matrix singular, which is the only way the inverse fails.
- The quaternion arithmetic is done on the four numbers a quaternion is made of, in the order real part then
  imaginary part. A `simd_quatd` at this deployment target has no operators, `==`, `.normalized` or `.inverse`:
  those come from the `simd` module's Swift overlay, which this release's headers do not bring. The SDK's
  `SPRotation3D` is a union of a `simd_double4` and a `simd_quatd`, so the arithmetic runs on the vector and the
  quaternion is only ever a reading of it.

## The geometry and the transformations

- Each geometry type is a union of a named struct and a `simd` vector in the SDK's C headers
  (`usr/include/Spatial/Structures.h`), so every `vector` member is that storage read one way or another, and a
  `simd_packed_*` initialiser fills it side by side.
- The algorithms are the SDK's C headers' own (`usr/include/Spatial`), named at each one. Where the SDK's Swift
  interface and the running system disagree, the system wins: the sign of `Point3D - Vector3D` was read off the
  host and not copied.
- `SPRay3DMake` normalises a direction that has a length and leaves a direction of zero length at zero.
  Normalising unconditionally does not match the host: `Ray3D(origin: .zero, direction: .zero).direction` is
  `(0, 0, 0)` and its `isZero` is true, where dividing `(0, 0, 0)` by its own length gives `(nan, nan, nan)`.
- `SPRotation3DMakeLookAt` builds the frame that looks along `forward` with `up` above it.
- An affine transformation's `isRectilinear` checks that its three-by-three part turns only by whole quarter turns,
  which is what the angle of its quaternion says, taken to the nearest quarter. `simd_angle` and
  `simd_quaternion` are each declared twice by the C headers, once per scalar, so the two calls are one statement
  apart and not nested.

The measurements behind these choices, and the host comparison, are in [the README](README.md).
