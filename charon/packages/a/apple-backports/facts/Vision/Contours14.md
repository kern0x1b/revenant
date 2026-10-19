# Vision's contours of iOS 14: VNDetectContoursRequest, VNContoursObservation, VNContour

The request finds the boundaries of the dark or light shapes in a picture. Its answer is an observation of the top-level
contours, each with its children, and each contour is a closed chain of points. The three classes are implemented in
`Vision/Vision14_0.m` (the contrast pivot, a 15.0 property, in `Vision/Vision15_0.m`), and the detection is the tracer in
`Vision/CharonVisionContours.h`. The handler runs the request in `Vision/VNHandlers.m`.

## What the host does, measured

`tests/backports/host/vision-contours14` draws seven pictures of white and black with CoreGraphics, runs the request on each
with both polarities of `detectsDarkOnLight`, and prints every contour's point count, nesting, aspect ratio and every point.
These are the facts the port is held to:

- **Points are the midpoints of the unit edges that separate the foreground from the background**, in pixel units, so a
  contour has one point per unit edge: a filled rectangle of width w and height h has 2(w + h) points.
- **Coordinates are normalised with the origin at the bottom left**: x is the column over the width, and y is `(H - row)` over
  the height, with the row measured from the top. A vertical edge's x is a whole pixel boundary; a horizontal edge's x is a
  pixel centre.
- **The walk starts on the outgoing edge of the bottom-right vertex** of the contour, which is the largest row and then the
  largest column, and it keeps the foreground on its left.
- **The foreground is the set of pixels darker than the pivot when `detectsDarkOnLight` is YES, lighter when it is NO.** The
  dark region that reaches the edge of a picture is bounded by the edge too, so it has a contour of the picture's perimeter.
- **Foreground is joined through all eight neighbours and background through four**: two squares that touch only at a corner
  are one contour of their combined boundary (scene 5 in the test), and a checkerboard's white cells are one region.
- **`aspectRatio` is the picture's width over its height** (4/3 for a 64 by 48 picture), not the contour's.
- **`contourCount` counts every contour at every depth; `topLevelContourCount` counts the outer ones.**

The host's answers and the port's agree to 1e-5 on every point of the seven pictures, in the canonical order the probe prints
(sorted by point count, then by the first point). The test's plant, which turns the tracer's diagonal preference around, makes
the comparison red.

## What is not reproduced, or not measured

- **Sibling order is not reproduced.** The release lists the children of one contour (and the top-level contours of a picture)
  in an order that the port's raster order does not give: in scene 2 with dark-on-light the host lists the left square first and
  the port the right one, and in scene 6 the host's three holes come in a different order again. No simple rule (raster from
  the top or bottom, x, y, or the start point) fits every scene, so the order is not claimed. The index paths the observation
  gives are the port's own order, and the test does not compare them.
- **Grey pictures are not thresholded the way the release does.** A 0.6 square on a 0.4 field gives no contour at all with
  polarity NO, and one contour with a child at polarity YES; the port's threshold after the contrast adjustment gives one
  contour with a child at polarity NO. The release does not threshold a grey picture at the pivot; its edge rule is not measured
  here, and the test does not compare grey pictures.
- **Antialiased edges differ.** A disc drawn with antialiasing has 128 points on the host and 132 in the port's threshold. The
  test draws its disc without antialiasing.
- **Scaling** to `maximumImageDimension` (512 by default) is a plain bitmap draw in the port. Every test picture is within the
  maximum, so the scaling is not measured.
- **The contrast pivot's default** (automatic on the host, 0.5 in the port) is not measured; the test pictures are binary, where
  the pivot does not change the answer.
- **`polygonApproximationWithEpsilon:error:`** is the classic Douglas-Peucker on the closed polygon; the release's own
  simplification is not measured, so its answer may differ.
- **The errors of the index lookups** (`childContourAtIndex:error:`, `contourAtIndex:error:`, `contourAtIndexPath:error:`) use
  VNErrorInvalidArgument; the code the host gives for an index out of range is not measured.
- **The observation's `normalizedPath`** is the union of the contours' points as one path; the release's path is not compared.
- **Core Video pixel buffers** are read by nearest-pixel sampling in the luma of the blue, green and red channels. The test
  uses CGImages only.

## Registry

`VNDetectContoursRequest`, `VNContoursObservation` and `VNContour` are `implemented` in `absent_Vision.json`, with this file as
`facts`. The surface of the three classes is `tests/backports/host/vision-contours14/surface.tsv`, read from the IR, and the
reflection probe is the one in `tests/backports/host/vision-results14`.
