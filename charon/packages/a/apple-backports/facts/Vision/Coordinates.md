# Vision's coordinate conversions of iOS 14 and 15

Five functions convert between image coordinates and the normalized coordinates Vision works in (origin at the lower left,
each axis in [0, 1] over the image):

- `VNNormalizedPointForImagePoint()` (iOS 14), in `Vision/Vision14_0.m`;
- `VNImagePointForNormalizedPointUsingRegionOfInterest()`, `VNNormalizedPointForImagePointUsingRegionOfInterest()`,
  `VNImageRectForNormalizedRectUsingRegionOfInterest()` and `VNNormalizedRectForImageRectUsingRegionOfInterest()`
  (iOS 15), in `Vision/Vision15_0.m`.

The region-of-interest functions take the region in normalized coordinates of the image, so a region of the whole image is
`{{0,0},{1,1}}` and they then agree with the plain conversions.

## What the host does

Measured on the host Vision of macOS 27.0.1 (build 26A434), arm64. The answers are compared bit for bit against the port in
`tests/backports/host/vision-coordinates15/run.sh`: 560 answers over seven image sizes (a picture, the unit image, a tall and
a wide one, a 1920x1080 frame, and a width, a height and both zero), five regions (the whole image, a sub-region, a
zero-width, a zero-height and a negative-width region) and eight points or rectangles each. Every one matches, and a plant
that swaps one axis is seen.

- An image point to a normalized point, plain: the point divided by the image size. An image with a zero width **or** a zero
  height gives the zero point, whichever axis is empty.
- A normalized point to an image point, in a region: the region's origin plus the point's share of the region's size, scaled
  to the image. `(ro + p * rs) * size`. No guard: a zero image size gives a zero coordinate on that axis.
- An image point to a normalized point, in a region: `(p - ro * size) / (rs * size)` for each axis, the form that matched
  every answer. The division written as `((p / size) - ro) / rs` differs from it in the last bit for some values, so it is
  not used. A zero image size gives the zero point; a zero-sized region gives the infinities and NaN the division gives.
- A normalized rectangle to an image rectangle, in a region: origin as the point case; size as `s * rs * size` for each axis
  with no edge arithmetic. A negative size times a zero region gives a negative zero, which the release answers and the
  edge distance does not, so the size is computed from the size.
- An image rectangle to a normalized rectangle, in a region: a zero image width or height gives the zero rectangle. A
  negative size is read as zero before the edges are taken, so the size comes out zero; a zero-sized region then gives NaN
  for the size, since both edges are infinite there. The origin is `(p - ro * size) / (rs * size)`, and the far edge is
  `(p + s' - ro * size) / (rs * size)` with `s'` the clamped size; the size is the difference of the two edges.

## What the measurement does not prove

- The host is macOS, not iOS 14 or iOS 15. The arithmetic is the same operations in the same order, measured bit for bit on
  the host; the release's own code is not read here, and a difference in its order of operations would show only on a
  device. No device run has been made for these functions.
- The zero-image guard is measured for every axis combination the probe covers, not for every size.
- Negative image sizes, which are not a real image, are not measured.
