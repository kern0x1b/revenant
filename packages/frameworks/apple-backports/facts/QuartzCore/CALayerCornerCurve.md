# CALayer.cornerCurve, iOS 13

Introduced in iOS 13: a layer's rounded corner is a circular arc or a continuous curve, the smoother one the system's own
icons have. `kCACornerCurveCircular` and `kCACornerCurveContinuous` name the two, and `CALayer.cornerCurve` holds one.

Source: the host's own QuartzCore, read for the two constants, the default and what a value that is not one of them does,
and compared in `tests/backports/host/uikit2` (`cornercurve`). The shared caches of iOS 6.0 and 7.0 have neither.

## What the port does as the system does

The constants are the strings "circular" and "continuous". A layer answers circular until it is given continuous; a value
that is neither, nil included, makes it circular again, as the system does; the answer is the same through key-value coding.

## What the port does with a continuous curve

iOS 6 rounds a corner with a circular arc only. A layer set to continuous that clips to its bounds with a corner radius gets a
mask of the continuous corner shape - a corner of two cubic curves that starts 1.34 radii along each edge, fitted to the shape the
host draws - laid over the circular clip, and the mask follows the layer's bounds, radius and clipping. On the host the covered
area of the two shapes differs by 0.02% to 1.3% for radii from 6 to 40 points on layers of 100x100, 120x60 and 300x44
(`tests/backports/host/uikit2`, `cornercurve`); the device test compares the area it draws with the host's.

## What it cannot do

A layer that does not clip to its bounds, or has a mask of its own, keeps its circular corners: the mask would clip its sublayers or
replace the application's. The border of a continuous layer follows the circular arc.
