# CIFilterShape, carried for iOS 6

10 rows, `registry/CoreImage/shape9.json`. iOS 6 has no `CIFilterShape`: the 6.1.3 armv7 cache's
selector table has neither `shapeWithRect:` nor `insetByX:Y:`, and the class arrived in iOS 9.

A filter shape is the rectangle a filter is told to work over. Every operation is the same operation on
that rectangle: two shapes intersect where their rectangles do, two take a union that bounds both, an
inset moves each edge in, and a transform either bounds the transformed shape or cuts it back to its
interior — which is what the `interior:` flag asks.

## What the pixel probe measured

`tests/backports/host/ciimage/pixel/`, the same two-process shape as the accumulator's: the port's
classes built under names of their own, the framework's in the same process and never asked. The probe
asks for every pair of three rectangles — one whole, one offset, one at a fractional origin with a
fractional size — through the union, the union with a rectangle, the intersection, the intersection
with a rectangle, two insets and four transforms each with and without the interior, and for each one
prints the shape's extent, the extent of an image cropped to it, and the length and checksum of the
bytes that image renders to.

**`ciimage: 252 measurements, 252 the same, 0 different, 0 one side only`**, at a tolerance of 5e-4.
That is every extent and every rendered pixel, for every operation, matching the framework.

**That was the count the old comparator gave, and the tree's own run gives nine differences in this
family, all of them the `interior:` flag:**

    ciimage: 527 measurements, 479 the same, 40 different, 42 one side only (tolerance 0.0005)

`-[CIFilterShape transformBy:interior:]` with `interior:YES` moves the extent on the system and does
not move it in the port:

    shape moved interior      the system  4.0000 -6.0000 10.0000 10.0000   the port 4.0000 0.0000 6.0000 4.0000
    shape turned interior     the system -5.0000  0.0000 13.0000 13.0000   the port 0.0000 0.0000 9.0000 10.0000
    shape scaled interior     the system  0.0000  0.0000 20.0000  5.0000   the port 0.0000 0.0000 10.0000 5.0000

and the three cropped pixel counts follow the extents: 400 against 96, 676 against 360, 400 against
200. Every other operation, with `interior:NO` and without, is equal - including the two the first
review named, which `dec31f42e` fixed: `shape 0 2 intersect` is `0 2 0 7` on both sides and
`shape 2 0 left` is `-4 2 4 7` on both, because `+shapeWithRect:` now rounds the rectangle to the
whole pixels the system rounds it to (CIFilterShape.h:61 declares `extent`, and the system's rule
measured over seven rectangles is CGRectIntegral's).

**This is owed, not claimed.** Nine lines, all one flag, and the row is `implemented`; the difference
is in `facts/CoreImage/Differences.md` and it says the same thing.

## What the probe found, which the header settles

`-insetByX:Y:` was written as `insetByX:y:` with floating-point amounts. Selectors are case-sensitive
and the header's own signature is `- (CIFilterShape *)insetByX:(int)dx Y:(int)dy`, so the port answered
a selector no caller names and the framework threw on the probe's first inset. The spelling and the
types are the header's now.

`CIFilterShape` conforms to `NSCopying` and `-copyWithZone:` was not there. It is.
