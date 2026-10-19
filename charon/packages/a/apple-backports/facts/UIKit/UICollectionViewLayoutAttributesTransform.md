# UICollectionViewLayoutAttributes.transform

iOS 7.0 adds an affine `transform` to layout attributes. iOS 6 already has `transform3D`, which the collection view
applies to the cell's layer, and 7.0's property is a view of it. The backport is
`UIKit/UICollectionViewLayoutAttributes+Transform7.m`.

## What the system does (measured)

The host's UIKit under Mac Catalyst, side by side with the backport in `tests/backports/host/uikit2`
(group `attributestransform`, 15 checks):

- Setting `transform` sets `transform3D` to `CATransform3DMakeAffineTransform(transform)`: identity, scale, rotation,
  translation and a scaled rotation all give the system's `transform3D` exactly.
- Reading `transform` gives the affine part of `transform3D` when `CATransform3DIsAffine` holds, and the identity
  otherwise: a z translation, a perspective (m34), a rotation about x, and two affine 3D forms all answer as the system's.
- Negative control: without the `CATransform3DIsAffine` branch, the rotation about x reads `[1 0 0 0.921061 0 0]`
  where the system answers the identity, and the test fails.

## Where this differs, and what is not measured

- The host's `frame` getter applies the transform (a scale of 2 on 100x50 at (10,20) reads (-40,-5,200,100)). The
  backport does not touch `frame`: iOS 6's `frame` getter is iOS 6's own. How 6.1.3's `frame` answers once
  `transform3D` is set has not been measured.
- That the collection view of 6.1.3 applies the transform to a cell is iOS 6's own behaviour for `transform3D`; it has
  not been checked on a device. Device-unverified.
