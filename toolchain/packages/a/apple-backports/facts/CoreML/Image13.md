# The CGImage constructors of Core ML's image feature value, measured against the host

The two constructors `+featureValueWithCGImage:pixelsWide:pixelsHigh:pixelFormatType:options:error:` and its
orientation form (both iOS 13.0) are measured by `tests/backports/host/coreml-image-constructors/probe.m`. The
probe builds the answers from two pictures (a 4x3 gradient and a 5x4 noise picture), 8 orientations, 8 crop
rects, 2 output sizes (2x2 and 8x6), 4 crop-and-scale options (nil, 0, 1, 2) and 3 formats (32BGRA, 32ARGB,
OneComponent8). That is 3072 cases, one line each. The probe compiles against the host framework, and against the
port's sources, so host and port are compared line by line.

The port does not match the host on every case, so these constructors are not in the port: their registry rows
stay `absent`, with the reasons pointing here. What is measured is below.

## What matches

- **Errors.** 1152 of the 3072 cases are errors, and the port's error lines are identical to the host's. The
  failing crop rects give these codes, all in the domain `com.apple.Vision`:

  | crop rect (x,y,w,h) | code | why |
  | --- | --- | --- |
  | 0,0,0,2 | 3 | no width |
  | 1,0,1,1 | 4 | one pixel wide, not at the origin |
  | 9,9,2,2 | 4 | wholly outside the picture |

  The rects 0,0,2,2, 1,0,2,2 and -1,0,2,2 are valid, and so is 0,0,1,1 (see below). The zero output size is error 3,
  from the size, not the crop.
- **Crop placement and the fill outside the picture.** With stretch, a 2x2 crop written to a 2x2 output is an
  identity, and it matches the host for every crop rect that is valid, on both pictures (32 of 32 for each group).
  The rect -1,0,2,2 runs off the left edge, so the match covers the fill outside the picture too.
- **Orientation.** Orientations 1 to 8 map as the EXIF numbering says. The port's stretch of the 4x3 gradient
  matches the host in all 8 orientations, BGRA and ARGB, at both sizes.
- **The default option.** On the host, nil answers exactly as option 2 in all 768 cases where both are present.
- **Stretch of the whole gradient.** The port's stretch (option 2, and nil) matches the host exactly in all 64 cases
  with no crop: the 4x3 gradient reduced to 2x2 and enlarged to 8x6, in every orientation and format.
- **Identity picture.** A picture already of the requested size comes back as its own bytes, on the host and in the
  port (a single 5x4 noise picture, BGRA, nil option, measured in scratch and not in the committed probe).

## What does not match

The largest difference in any channel, per uncropped case, comparing the port's draft with the host (`maxdiff`,
scratch; the probe's own output is in the run folder). Stretch is options nil and 2:

| case (per option) | cases | largest channel difference |
| --- | --- | --- |
| noise 5x4 to 8x6, stretch (nil and 2 each) | 16 | 1 |
| noise 5x4 to 2x2, stretch (nil and 2 each) | 16 | 65 |
| gradient 4x3 to 2x2 and 8x6, stretch | 16 per size | 0 (exact) |
| noise 5x4 to 2x2 and 8x6, cover (0) | 16 per size | 127 and 255 |
| noise 5x4 to 2x2 and 8x6, fit (1) | 16 per size | 128 and 255 |

- **Enlargement by stretch differs by one unit at most.** Noise enlarged to 8x6 is within 1 of the host in every
  channel, which is rounding in the port's kernel, not a different filter. The port's kernel is the Vision kernel
  (`RevenantVisionBilinear.c`); the host's enlargement impulse response is the same separable tent with a half-pixel
  centre, measured on a single white pixel.
- **Reduction by stretch differs.** Noise reduced to 2x2 differs by up to 65. The host's impulse sweep (one white pixel
  moved across a 5x5 picture into a 2x2 output) gives weights that the port's kernel does not reproduce. The host's
  2x2 noise values are 158, 129, 169 and 164 in red; the port's kernel gives 105, 160, 177 and 156. Tested and
  rejected, each against the sweep and the noise line: the port's kernel with every position mapping (offsets of a
  quarter, a half and minus a quarter, both scale conventions, rounded or truncated); the same kernel in two passes
  with 8-bit rounding between them, in both orders; a box filter; a tent, Lanczos 2 and 3, Keys and Catmull-Rom, each
  with its support scaled by the reduction ratio and without; flipped pictures; vImage's scaler, with no flags and
  with high-quality resampling; and CoreGraphics' draw at each interpolation quality. A final round tested Core
  Image's CILanczosScaleTransform (largest difference 66 on the noise 2x2), an exact area-weighted box (38), and a
  two-stage reduction (2x2 averaging to halve the picture, then bilinear: 36); vImage's high-quality scaler gave 38
  again. None of these matches on the sweep either. The reduction filter is not identified.
- **A one-pixel crop at the origin is ignored by the host.** A crop rect 0,0,1,1 answers the whole picture, not the
  pixel: on the host, all 384 such cases (both pictures, every orientation, size, option and format) equal the answer
  with no crop rect. The port takes the pixel, and its answer equals the host's in none of its 256 non-grey cases.
  The host's rule for a width-one rect at other offsets is the error (above); for a height-one rect at the origin it
  is not measured.
- **A 2x2 crop enlarged to 8x6 differs.** The host's first row of the 2x2 crop 0,0,2,2 enlarged to 8x6 is
  167 167 174 186 197 207 202 178 in red. No 2x2 sub-window of the noise picture, enlarged by the port's kernel,
  gives that row, and neither does a window of the whole picture with its taps reaching past the crop. The host's
  rule for the sample positions of a cropped source is not identified.
- **Cover (0) and fit (1).** On the gradient at 8x6, which has the picture's own aspect, all four options give the same
  answer on the host and in the port, so that size cannot separate them. At 2x2 they differ by up to 191 on the gradient
  and 128 on the noise, and at 8x6 by up to 255. The host's
  fit answers alpha 127 where the port answers 255, which is not explained. The numbering of 0 and 1 follows
  Vision's `VNImageCropAndScaleOption` (CenterCrop 0, ScaleFit 1, ScaleFill 2), and nil equalling 2 agrees with it,
  but the pixels do not yet confirm 0 and 1.
- **OneComponent8 (grey).** The host answers a grey image. The port's `MLFeatureValue` carries 32BGRA and 32ARGB
  pixel buffers only. It answers any other format as an undefined image value with no buffer, so all 640 valid grey
  cases come back with no buffer. The port's reader takes an image value's bytes as float32 (`MLFeatureValue.m`), so
  an 8-bit grey buffer cannot be carried until the reader takes one. The grey draw itself was measured in scratch
  (`grey5`, not committed): CoreGraphics' grey draw of the BGRA picture is within one level of the host's grey, with
  2997 of 3072 bytes equal and 75 one level off.

## What is owed, and why

The four CGImage rows stay `absent` until the port answers the host on every measured case. Three things are
missing: the host's reduction filter, which is not identified (the list above is what was rejected); the host's rule
for the sample positions of a cropped source, which is not identified; and the grey buffer, which needs the port's
image feature value to carry one. Cover and fit at a non-matching aspect are measured above and need the same
resampler. The error answers, the orientation mapping and the crop placement are matched, and are the part a port
can state now.
