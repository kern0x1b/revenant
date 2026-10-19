# MPSImageGaussianBlur: the tap count is not a function of sigma that the port can state

`-[MPSImageGaussianBlur initWithDevice:sigma:]` (9.0) builds a blur of one sigma. The header (MPSImageConvolution.h:236-252)
gives the weights as `w(i) = 1/sqrt(2*pi*sigma) * exp(-i^2/2*sigma^2)` and the width as a rough estimate,
`ceil(sqrt(-log(0.01)*2)*sigma) ~ ceil(3.7*sigma)`. Measured on the macOS 26 host, that estimate is not the width Apple
uses, and Apple's width is not a closed form in sigma. So the port does not compute the blur's width from sigma, and
the class stays refused by name (`MPSImageConvolution13.m`) until the coordinator decides how the row is closed.

## What Apple's object reveals

* `MPSImageGaussianBlur` has no width property. `kernelWidth` is not a member of the class, so the width cannot be read.
* An impulse of 1.0 at the centre of a 401 x 401 R32Float image, blurred by Apple's kernel, has a nonzero extent that
  is the tap count. The host encodes this (the legacy queue path reports Completed), so the measurement is possible.
  `tests/backports/host/gaussian-blur-width/run.sh` runs the sweep over sigma 0.1 to 12.0 in steps of 0.1.

## The measured half-widths (taps = 2 x half + 1)

| sigma | half-width | sigma | half-width |
| --- | --- | --- | --- |
| 0.5 | 2 | 2.2 | 6 |
| 1.0 | 3 | 2.3 | 11 |
| 1.5 | 5 | 2.6 | 13 |
| 2.0 | 6 | 2.7 | 11 |
| 3.0 | 11 | 5.0 | 17 |
| 5.0 | 17 | 9.4 | 31 |
| 7.0 | 23 | 9.5 | 39 |
| 8.0 | 27 | 9.6 | 47 |
| 10.3 | 39 | 10.5 | 47 |

The half-width is not monotone in sigma: it goes 2.2 to 6, then 2.3 to 11, then 2.7 back to 11, and 9.5 to 39 then
9.6 to 47 then 10.3 to 39. The first pattern is what a multi-pass approximation of a large blur would produce, and it
is a hypothesis, not a measurement. The header's estimate `ceil(3.7*sigma)` gives 4 at sigma 1.0 where Apple gives 3,
and 2 at 0.5, where it agrees.

The centre weights are also not a normalised Gaussian. At sigma 1.0 the one-dimensional weights are
0.3830, 0.2422, 0.0603, 0.0060 (normalised to sum 1), where a Gaussian at sigma 1.0 normalised over the whole line gives
0.3989, 0.2420, 0.0540, 0.0044.

## Consequence for the port

A width table would be a fake for any sigma not in it, and a width from the header's estimate is wrong at sigma 1.0.
So the port refuses `-initWithDevice:sigma:` and encodes nothing. Closing the row needs one of: a measured width and
weight rule, the same kind of measurement across a second axis (the sweep is one-dimensional and the rule may depend
on the device or the image size), or the owed status, which removes the class from the port.

## Not measured

* Whether the width depends on the image size, the device or the edge mode. Only one image size and the zero edge mode
  were measured.
* The encode of Apple's blur on the device. The host is the only place it was run.
