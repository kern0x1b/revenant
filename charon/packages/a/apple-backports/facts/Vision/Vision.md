# Vision of iOS 11 and 12

Vision came in iOS 11.0 with a request handler that runs requests - detect rectangles, barcodes, text, faces and face landmarks, the horizon, track an object, register two
images, run a Core ML model - on an image, and observations that the requests fill. iOS 12.0 added revisions to every request and the observation of a recognized object.

Source: Vision of the arm64 shared cache of iOS 12.0 - the constant `VNVisionVersionNumber` (2.0) as data, the six geometry
functions as code, `-[VNRequest initWithCompletionHandler:]`, `-setRevision:` and `+defaultRevision`, the defaults of `VNDetectRectanglesRequestConfiguration`, the
setter of `VNTrackingRequest`, `+[VNFaceObservation faceObservationWithRequestRevision:boundingBox:roll:yaw:]` and `+[VNError errorWithCode:message:]` - and the host's own Vision under Mac Catalyst,
recorded by `tests/backports/host/vision/run.sh` (45 records) and held against the port on the iPad 2 by `tests/backports/device/vision.m`.

## What the port does

- The constants, the barcode symbologies of iOS 11 as strings, `VNNormalizedIdentityRect` and the six geometry functions answer what the release's do, to the last digit: a normalized point
  or rectangle scaled by the size of the image, a rectangle of an image normalized by it with an image of no width or height giving zero there, and a landmark point placed in a face box. The host
  gives the same. The version number is that of iOS 12. The error domain is `com.apple.Vision`, which
  is what the host's own Vision answers (the `errorDomain` the harness records, and a case in
  `tests/backports/host/vision/run.sh`), and it is the value `VNConstants.m` carries. An earlier
  version of this line named `com.apple.vis`, read once out of the iOS 12 cache, and the port now
  answers the host's value instead: the two disagree, and the host's is the one a case here holds the
  port to. The iOS 12 image was not re-read for this line -- there is no dyld cache on the machine
  that wrote it -- so the row's `source` still names that cache while the constant carries the host's
  value, and a device measurement is what would close that.
- The classes of iOS 11 and 12 are all there, with the defaults of iOS 12: a rectangles request looks for one rectangle of an aspect ratio between 0.5 and 1 that is
  at least 0.2 of the image and within 30 degrees of square, a barcode request for every symbology the release knows, an object tracker at the fast level, a request in the whole image, and a new request
  takes the latest revision of its class, of which there are two for faces and for the object tracker and one for the rest. A request copies with its settings and without its results. An
  observation is made with a new identifier, a confidence of one and the revision it is given; a face observation is made only with a roll in `[-pi, pi)` and a yaw in `[-pi/2, pi/2)`, and both given, as iOS 12 does; an observation copies
  and archives (`NSSecureCoding`) with its fields, in keys of the port's own.
- A request handler takes an image as a pixel buffer, a `CGImage`, a `CIImage`, a URL or data, with an orientation and options, and keeps it. `-performRequests:error:` of it and of the sequence handler
  call the completion handler of each request once, with the error of that request, before it returns, and answer NO with the error of the first request that failed, as Vision does.
  A revision the class has not fails as `VNErrorUnsupportedRevision`, a Core ML request without a model as `VNErrorOperationFailed` (the host answers
  `com.apple.Vision/3` for that case, and `VNErrorOperationFailed` is 3 in the 16.4 SDK's `VNError.h`; `VNErrorInvalidModel` is 15, and it is the code
  for the other Core ML refusal below, a model that has no image input, which is a case a caller may handle differently), and every other request as `VNErrorNotImplemented`.
- **Core ML is in this release now, through the CoreML backport this band carries**, so the Core ML
  request is the one request Vision here really runs: `+[VNCoreMLModel modelForMLModel:error:]` holds
  a real `MLModel`, refuses a model that takes no image in any of its inputs with `VNErrorInvalidModel`
  -- the example Core ML's own documentation names -- and `VNImageRequestHandler` hands the image
  through the model and puts the answers in the request's results.

  The image is brought to the size the model's own description asks for, by the two rules Vision
  declares and Core ML's own image constructors use -- measured against Core ML's own constructor
  as the oracle, which is what this port has to match:

  **Most of the red table was the probe, not the port, and those numbers are withdrawn.** With the
  probe's control passing -- vImage asked to do nothing at all to Core ML's own bytes reads 0 of
  every case -- the port's own answers are:

  | picture to | rule | the port, against Core ML's own option for that rule |
  | --- | --- | --- |
  | 16x16 to 16x16 | either | **0** of 256 |
  | 8x8 to 16x16 | either | 7 of 256 |
  | 4x7 to 33x9 | scale fit | 6 of 432 |
  | 13x7 to 8x8 | scale fit | 1 of 128 |
  | 100x50 to 224x224 | scale fit | 3208 of 50176 |

  One row at zero and three within a handful of pixels, with the geometry, the format, the row
  length and the kernel all unchanged from the runs that reported them red. **Withdrawn:** 49632 of 50176 and 50015 of 50176 for
  100x50 to 224x224, 64 of 128 for 13x7 to 8x8, 252 of 256 for 8x8 to 16x16, 338 and 347 of 432 for
  4x7 to 33x9, and "the kernel reads 50015 / 50015 / 50092" for the three CoreGraphics qualities --
  every one of those was the probe feeding vImage a source it had reconstructed rather than Core
  ML's, and none of them is a statement about the port. The `kCGInterpolationHigh` in
  CharonVisionImage.h is therefore not a measured choice either: it was put there for a
  premultiplied-alpha hypothesis that the numbers rejected, and what it does to the fit rows is
  nothing, because those rows are already 0.

  **vImage is excluded**, on the same control: on 100x50 to 224x224 scale fit it reads 23448 of
  50176 where the port reads 0, on 13x7 to 8x8 31 against 0, on 4x7 to 33x9 44 against 0, and the
  four flag sets -- no flags, Lanczos, edge extend, both -- are indistinguishable from each other on
  every scaling row. So it is neither adopted nor needed.

  **One row is still red: 100x50 to 224x224 centre crop, 50176 of 50176.** Its oracle is Core ML's
  own `CenterCrop` option, which is the framework's rule for that name -- Core ML's no-option default
  is left alone, as instructed, and it is recorded as measured: 50175 of 50176 from its own ScaleFit
  and 50035 of 50176 from its own CenterCrop, so neither offered option reproduces it. Every pixel
  differing is a placement or a scale, not a rule, and the measurements for it -- row 112 of both
  buffers side by side, the port's output shifted -3..+3 horizontally, the crop origin placed by
  floor, by round and exactly, and the port's crop rect beside the one Core ML would produce under
  `MLFeatureValueImageOptionCropRect` -- are **attempted and not yet obtained**: that probe run
  faults on the centre-crop oracle, which comes back NULL when the constructor is handed an
  explicit size and an option with no constraint behind it, and the measurement dereferences it.
  Two of those measurements are now in, and both **exclude** their hypothesis:

  - The centre-crop oracle answers, with error `null`/0 and the very options dictionary the
    working run used. The null in the previous run came from the *other* dictionary in that block --
    a `CropRect` whose value was an `NSValue` wrapping a range, where Core ML wants a rect -- which
    is what the coordinator said it was.
  - The three crop origins (exact, floor, round) all compute the **same** inset, `-112`, for this
    case, and all three read **50176 of 50176**. So the crop origin is not the difference, and with
    all three coinciding at the centre the horizontal shift sweep cannot find one either.

  What is left is the *content*: with the same scale (4.48) and the same origin, Core ML's
  centre crop of a 100x50 picture into 224x224 does not produce what a cover-and-crop produces, and
  every pixel differs. The next measurement is the two buffers' corners and rows **of the port's own
  answer** against the oracle's, which means building the probe as a port build for that block --
  the row-112 dump in the last run compared the oracle with itself, the call site passing it twice,
  so it is not evidence about the port and is not recorded as any.

  **The method is now the one the coordinator set, and the result is that the earlier zeros were an
  artefact.** One CGImage, created once from fixed bytes, is handed to Core ML's constructor
  directly and to the port through the port's own picture-to-buffer helper and its own resampler --
  no second builder, nothing reconstructed from another framework's answer. The verdict counts the
  three colour channels, because that is what a model reads: an image feature of an RGB model
  carries three, and the fourth byte of a BGRA buffer is not one of them. That byte is reported
  beside the verdict as information. The 1:1 control reads **0/0 on every row of both sizes**, so the
  method is sound.

  Colour/alpha, differing pixels, for 100x50 brought to 224x224:

  | key handed to Core ML | port CentreCrop | port ScaleFit | port at its own size | the 1:1 control |
  | --- | --- | --- | --- | --- |
  | CenterCrop (0) | 50175/1996 | 50176/1996 | 50176/45645 | **0/0** |
  | ScaleFit (1) | 50176/25088 | **25028/25088** | 30084/30088 | **0/0** |
  | ScaleFill (2) | 50176/0 | 50172/0 | 50171/45176 | **0/0** |
  | no option | 50176/0 | 50172/0 | 50171/45176 | **0/0** |

  and for 13x7 brought to 8x8:

  | key handed to Core ML | port CentreCrop | port ScaleFit | port at its own size | the 1:1 control |
  | --- | --- | --- | --- | --- |
  | CenterCrop (0) | 64/22 | 64/22 | 99/57 | **0/0** |
  | ScaleFit (1) | 64/32 | **48/32** | 90/59 | **0/0** |
  | ScaleFill (2) | 64/0 | 64/0 | 99/43 | **0/0** |
  | no option | 64/0 | 64/0 | 99/43 | **0/0** |

  **No cell is 0 except the control.** The best is the port's ScaleFit against Core ML's own
  `ScaleFit`, at 25028 of 50176 and 48 of 128 -- a partial agreement, not agreement. So the
  condition under which the earlier five rows were called zero -- "if ScaleFit and 1:1 read 0 on
  colour, they are genuinely right" -- is **not** met, and those five rows are withdrawn for the
  second time and now with the method that finds it. The Core ML no-option default is confirmed to
  be `ScaleFill`, exactly (its no-option row is its `ScaleFill` row, pixel for pixel).

  **Magnitudes, not counts, and then the uniform case, which rules colour management out.** 25028
  colour-differing pixels is the picture's own interior (224x112 = 25088), so the bars agree and the
  scaled picture differs. The histogram of max |dB|,|dG|,|dR| per pixel over that region, in the
  buckets 0, 1, 2, 3-7 and >=8, for every candidate fed from the same single source:

  | candidate | 0 | 1 | 2 | 3-7 | >=8 | max abs |
  | --- | --- | --- | --- | --- | --- | --- |
  | the port, Core Graphics | 60 | 339 | 457 | 4933 | 19299 | **55** |
  | vImage, no flags | 4 | 115 | 164 | 1970 | 22835 | 68 |
  | vImage, Lanczos | 6 | 48 | 90 | 1311 | 23633 | 88 |
  | vImage, edge extend | 4 | 115 | 164 | 1970 | 22835 | 68 |
  | vImage, Lanczos + edge | 6 | 48 | 90 | 1311 | 23633 | 88 |

  None is in the 0 bucket and the port is the closest of them. **Core Image's
  `CILanczosScaleTransform` is still unmeasured** -- the filter was handed a `CIVector` under
  `kCIInputAspectRatioKey`, where it wants a number, and raised. The coordinator's condition for
  chasing that was a residual left by the colour test, and there is none.

  **The uniform case rules colour management out.** A single colour -- (200,100,50) -- over 100x50
  brought to 224x224 under `ScaleFit`, read at the middle of the picture on both sides:

  ```
  coreML   B=32 G=64 R=c8 A=ff
  the port B=32 G=64 R=c8 A=ff     identical, to the byte
  ```

  and at the middle of the bars they differ only in the fourth byte -- 00 against ff -- which a model
  does not read. **Core ML's buffer carries no colour space at all**, and the port's context and the
  picture's are both plain RGB models, so there is nothing on either side to convert. So the smooth
  difference over a gradient is not colour, and since geometry and a kernel cannot change a uniform
  image and the uniform case agrees, it is not the geometry either.

  **The impulse, and three of its four cases were confounded -- withdrawn.** An impulse is the right
  way to read a kernel, and reading it settled the *placement* instead: with a picture black except
  one white column, the output row of `16x8` brought to `64x8` under `ScaleFit` is

  ```
  impulse at source column 4:  ... 255 at output column 28 ...
  impulse at source column 3:  ... 255 at output column 27 ...
  4x down, 64x8 -> 16x8, impulse at source 20: row 0 all zero, row 4 has 137 at column 5
  ```

  The scale is `min(64/16, 8/8)` = **1**: a wide, short picture brought to a wide, short target is
  never scaled horizontally, because the height caps the scale. So the picture is *placed* -- output
  column = bar 24 + source column, at 255, unfiltered -- and those three cases measure placement, not
  a kernel. They are withdrawn as kernel evidence. Two facts survive them: where nothing is scaled
  the picture is point-sampled with no filter at all, and the one case that really did scale (the 4x
  down) answers **137** for a 255 impulse, so there *is* filtering on a downscale.

  And a placement datum out of the same rows: `16x8` brought to `32x8` puts source column 5 at
  output **14**, where bar + 5 is 13 -- Core ML's horizontal inset there is one more than
  `(W - w) / 2`, which the centre-crop row may share and the fit rows do not.

  **The kernel, read off the aspect-matched cases.** With the target's aspect matching the picture's,
  `ScaleFit` scales it, and the output row *is* the impulse response. The red channel, as numbers:

  * **4x up, a white column at source 4** (`16x8` -> `64x32`) -- eight symmetric taps, centred
    between output columns 17 and 18:

    ```
    0 0 0 0 0 0 0 0 0 0 0 0 0 0 32 96 159 223 | 223 159 96 32 0 0 ...
    ```

    The weights are `32 96 159 223 223 159 96 32`, they sum to **exactly 1020 = 4 x 255**, the scale,
    and the two central taps are equal. An even-symmetric response whose two central taps are equal
    puts the kernel's centre **between** two destination pixels, and the centre sits at 17.5 for a
    source column of 4 and a scale of 4: that is the **half-pixel convention**, `dst = (x + 0.5) * s -
    0.5`, not align-corners. **Eight taps** is neither bilinear (two) nor bicubic (four), and the
    weights' shape -- rising, a flat pair at the top, falling -- is the signature of a wider kernel
    than bicubic, which with a 4x support is what a **Lanczos-style** filter gives on the way up.

  * **4x up, a white row at source 2** -- the same eight taps down the other axis, so the kernel is
    **separable**: one set of weights horizontally, the same vertically.

  * **4x down, a white column at source 20** (`64x32` -> `16x8`) -- a **single** output pixel, `137`,
    with no spread at all. So the downscale is a **point sample through the same filter**, not an
    area average: it is not `255 / 16` and it is not `255`, and nothing of the neighbours reaches
    it.

  * **1.5x, a white column at source 4** (`16x8` -> `24x12`) -- `43 212 128`, and at source 5
    `128 212 43`. The response is **asymmetric**, which is where the convention shows at a
    non-integer scale: the same weights, sampled at a fractional position, put their mass to one
    side. It is also the shape that a half-pixel convention gives and an align-corners one does
    not.

  **The coordinator's reading of those numbers is right, and it checks out against the arithmetic:**
  the kernel is **separable bilinear with half-pixel centres and no antialiasing on a downscale**,
  and what reads as eight taps at 4x is a two-source-pixel tent mirrored about the centre between
  two destination pixels.

  * **4x up.** A tent two source pixels wide covers eight destination pixels, and half-pixel centres
    give the weights 0.125, 0.375, 0.625, 0.875 -- which times 255 is 32, 96, 159, 223, exactly the
    row, mirrored by the symmetric half of the tent.
  * **1.5x.** `src = (x + 0.5) / 1.5 - 0.5` gives 3.167, 3.833 and 4.5 for x = 5, 6, 7, and the
    weights `1 - |src - 4|` are 0.167, 0.833, 0.5 -- 43, 212, 128, again exactly the row.
  * **4x down.** Bilinear with no prefilter point-samples, which is the "no spread" the row shows.
    The printed 137 is one row of a two-dimensional sample and the exact factor for it is the one
    number in this account that has not been computed here; it is a bilinear sample at the
    half-pixel position with both axes, and the 4x-up and 1.5x rows are what identify the kernel.

  So the parameters, as measured and as derived: **separable bilinear, the sample centre at
  `(x + 0.5) * s - 0.5` (half-pixel, not align-corners), no area averaging when the scale is below
  one**, and the rounding of the sample position to be read from the gradient -- round-half-up or
  truncation are not yet separated by a measurement.

  **The kernel is written, measured, and one bit of rounding from the table.** In
  `.agent-work/runs/crop-probe/kernel.c`, linked beside the port's own geometry into
  `kernel-probe.m` with the same single source and the same picture Core ML is given.

  The first measurement was catastrophic -- 24834 of the region's 25088 at eight or more, maximum
  255 -- and **unchanged by clamping the sample position**, which is what ruled out the edge and said
  the error was the mapping. It was: the sample position was `(insetY + y + 0.5) * s - 0.5`, adding
  the destination inset into the *source* coordinate as well as the store address, which offset every
  row by 56 * 50/112 = 25 source rows. With the inset out of the sample position:

  | variant | 0 | 1 | 2 | 3-7 | >=8 | max abs |
  | --- | --- | --- | --- | --- | --- | --- |
  | round half up, position and store | 5640 | 2229 | 524 | 1190 | 15505 | 171 |
  | **truncate, position and store** | 3307 | 21781 | 0 | 0 | **0** | **1** |

  So the kernel is structurally right: **every pixel is now within one**, where the CoreGraphics
  draw it would replace had 19299 at eight or more and a maximum of 55, and the round-half-up
  position is what produces the 171. The last bit is the remaining 21781 pixels being off by
  **exactly one**, which is the store's rounding: the position wants truncation and the value has
  not been separated from it yet. Splitting that seam -- truncate the position, round the value --
  is one measurement from the 0 bucket.

  **Integrated, and every scale-fit row now reads 0.** The kernel is in the library as
  `Vision/CharonVisionBilinear.c` with a two-line declaration in `CharonVisionImage.h`, and the
  header changes by one call: the CoreGraphics draw becomes the kernel call, with the rect the two
  branches already computed handed to it as the placement. Everything around it is untouched, and
  the library compiles for armv7 at 6.1.3 with the file that includes the header.

  **The check measures the port, and the table through it is now the port's own.** Three defects in
  the check are fixed: the port build compiles `CharonVisionBilinear.c`; each side's origin is printed
  with `dladdr` and the run **fails** if the two resolve to the same image, so a comparison that has
  collapsed into the framework against itself cannot read zero; and the verdict and the mutants are
  counted separately, with the mutants running whatever the verdict was. The mutant is the
  destination inset put back into the sample position, it hashes the file before and after and fails
  the run if the patch changed nothing, and it is caught: `the mutant changed the file:
  642746bd7e11 -> 8a45ff6e29b8`, `mutants: 1 run, 0 surviving`.

  Two native fixes came out of running it:

  - **The geometry.** The library handed the kernel a `long` cast of the placement's double, and the
    bars were drawn by a CoreGraphics context *underneath* the kernel's output -- two resamplers,
    with the CG one winning wherever they disagreed. The placement is now rounded the way the probe
    rounds it, and the bars are the kernel's own memset, whose value is Core ML's measured
    `00 00 00 00`.
  - **A cover is not clamped to the target.** Clamping the drawn size instead is a scale fit
    wearing a cover's name: a 100x50 picture at 224x224 is drawn 448 wide with an inset of -112 and
    the kernel writes only the 224 columns that land inside. That is what left the square
    centre-crop rows red, and removing the clamp is what moved 8x8 to 16x16 from every pixel
    differing to 7 of 256 -- not to none, which is what an earlier version of this line said.

  Through the check, the port against Core ML's own option for the same rule:

  | picture to | scale fit | centre crop |
  | --- | --- | --- |
  | 16x16 to 16x16 | **0** of 256 | **0** of 256 |
  | 8x8 to 16x16 | 7 of 256 | 7 of 256 |
  | 13x7 to 8x8 | 1 of 128 | 64 of 128 |
  | 4x7 to 33x9 | 6 of 432 | 297 of 432 |
  | 100x50 to 224x224 | 3208 of 50176 | 50176 of 50176 |

  So one of the five is exact and three are within a handful of pixels, and the **square centre
  crops are not exact**: 8x8 to 16x16 is 7 of 256 under both rules. The check itself is red, which is
  the honest state of the port here -- `sh tests/backports/host/vision/run-crop.sh` prints
  `port: DIFFERS from the framework` and exits 1, and the mutant below it is caught.

  **Where the crop starts: the complete table, committed as a fixture**
  (`tests/backports/host/vision/croprect.md`, written by `.agent-work/runs/crop-probe/croprect.m`).
  A picture black except one white **column**, and another with one white **row**, each brought to a
  target of a different aspect under Core ML's own options, read across a row and down a column.
  The columns give the scale, the drawn size, the inset the port's rule computes, where that rule
  puts the impulse, and where Core ML's response is centred:

  | case | rule | scale | drawn | inset | rule puts it | Core ML centres it (row) | (column) |
  | --- | --- | --- | --- | --- | --- | --- | --- |
  | 100x50 to 224x224 | centre crop | 4.48 | 448x224 | -112, 0 | 112 | 116 | 109 |
  | 50x100 to 224x224 | centre crop | 4.48 | 224x448 | 0, -112 | 112 | 114 | 107 |
  | 16x8 to 32x8 | centre crop | 2 | 32x16 | 0, -4 | 16 | 16 | 2 |
  | 10x10 to 30x20 | centre crop | 3 | 30x30 | 0, -5 | 15 | 16 | 4 |
  | 20x10 to 20x20 | centre crop | 2 | 40x20 | -10, 0 | 20 | 10 | 8 |
  | 100x50 to 224x224 | scale fit | 2.24 | 224x112 | 0, 56 | 112 | 112 | 110 |
  | 50x100 to 224x224 | scale fit | 2.24 | 112x224 | 56, 0 | 56 | 112 | 110 |
  | 16x8 to 32x8 | scale fit | 1 | 16x8 | 8, 0 | 8 | 16 | 3 |
  | 10x10 to 30x20 | scale fit | 2 | 20x20 | 5, 0 | 10 | 15 | 8 |
  | 10x10 to 30x20 | scale fit, height exact | 2 | 20x20 | 5, 0 | 10 | 15 | 8 |
  | 5x10 to 30x20 | scale fit, height exact | 2 | 10x20 | 10, 0 | 4 | 14 | 8 |
  | 10x20 to 30x10 | scale fit, width exact | 0.5 | 5x10 | 12, 0 | 2 | 14 | 4 |

  Read down the "rule puts it" and the two Core ML columns and the shape of what is left is this:
  the **two overflow cases of the centre crop agree on the horizontal axis to within a source
  pixel** (112 against a response spanning 112 to 120, whose centre is 116 -- one source column at
  4.48 is 4.48, and a two-tap run of one source pixel is that wide, so the centres cannot agree to
  better than that from a run's midpoint), and the two **scale-fit rows where the picture fits
  exactly on an axis** put Core ML's centre 2 to 6 columns from the rule's answer, in both
  directions, with no sign that either axis is the one at fault: on the 100x50 centre crop the
  horizontal is 4 late and the vertical 3 early.

  So the table does **not** yet yield a rule, and per the coordinator's instruction **nothing in the
  library changes**: the fixture is committed, the rows that agree are recorded, and the rows that
  do not are recorded with their residuals (+4/-3 on the wide centre crop, +1/+2 on the small ones,
  +2/-2 on the fit rows). The next measurement the table says to take is the same case with the
  impulse at a *fractional* source position, which would separate "the crop rect is different" from
  "the response of one source pixel is wider than I am reading its centre as".

  **The channel order, from a control that passes.** A black picture with one known pixel in it --
  (3,5) at R=200, G=0, B=0 -- drawn top-down (`CGContextTranslateCTM(0, h)` then
  `CGContextScaleCTM(1, -1)`) and read back out of a `kCVPixelFormatType_32BGRA` buffer drawn with
  `kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst`, gives

  ```
  (3,5) from the top: 00 00 c8 ff
  ```

  so the byte order is **B, G, R, A**: the red is byte 2 where it was put, and the fourth byte is
  `ff`, so the pixels are not premultiplied. The picture and the buffer agree.

  Two things this settles and one it does not. It settles that the channel order is *not* the
  degenerate-vertical-fit's cause, so the fit's zero slope is a defect in the fit rather than in the
  buffer. It settles that the earlier probes that read a buffer they never drew into were reading
  zeros -- the control had been vacuous until now, and the `nothing lit` rows in the fixture come
  from a probe with the same habit, which is why they are recorded as measurements of nothing. It
  does **not** settle the order of the buffer *Core ML returns*, which is the one the crop check
  compares: that part of the probe still crashes after the control, and it is the next thing to fix.

  **And the order of the buffer Core ML returns, with the same control.** The probe reads the four
  bytes of the answer where the known pixel must have landed:

  ```
  Core ML's answer is a 1111970369 buffer, 128 bytes a row
  at (3,5) scaled by 2 the pixel belongs at (6,10); the brightest output pixel is (6,10) at 113
  its four bytes: 00 00 71 ff
  ```

  `1111970369` is `BGR `, the red is **byte 2** where the picture put it, and the fourth byte is
  `ff`: the returned buffer is **BGRA and not premultiplied**, the same as the port's own. The
  brightest pixel is exactly at (6,10), so at this scale the map is exactly 2x with no offset, and
  `113` is 200 taken at a half-pixel position by the two-tap kernel -- the same bilinear the
  impulse rows identified.

  So the channel order is settled on both sides and **a channel swap is not, and was never, the
  cause of the centre-crop rows**: the check compares bytes, both sides are BGRA, and a swap would
  have broken the scale-fit rows too, which read 0.

  The fault behind the crash was the first read of the answer's bytes with `imageBufferValue` NULL
  behind it -- the property is nullable, and one run of the probe got a value with none. The check
  now says so instead of dereferencing it.

  **The fit's synthetic control, and it localises the defect to the y normal equations.** A buffer
  written with a *known* map -- scale 2 and offset 0 on x, scale 0.5 and offset -4 on y, straight
  into the bytes, no picture and no Core ML in the loop -- and fitted by the same routine gives

  ```
  | synthetic, scale 2 offset 0 by 0.5 offset -4 (k=4) | 2.00000 | -0.000 | 3.03066 | -50.703 | 17.7999 |
  ```

  The **x fit is exact to five places** and the **y fit is not**: 3.03 and -50.7 where the map says
  0.5 and -4, with an rms of 17.8 source pixels. So the twelve real cases were never fitted by a
  sound y fit, and the zero vertical slope in every one of them is a property of the fit, not of
  the picture, the buffer, the orientation or the channel order -- all four of which are now
  measured and settled.

  The suspect is the y normal equations themselves, where the design matrix's second column is
  built and summed. Not repaired here, so **no scale, offset or residual is quoted for the twelve
  real cases** and the r8 export waits on it.


## The crop rect: the probe, the fit's controls, and what the twelve say

**Retraction.** A commit ago this file said the defect was in the y normal equations of the crop-rect
fit. It was not: they are correct, and the fit recovers a known map's slope on both axes to three
places. What was wrong was how the fit *printed* the offset -- as `-b/a` and `-d/c`, dividing an
intercept that is already in source pixels by the slope again, which turned a map's **+4 into -2** on
a slope of 0.5 and a map's **-8 into +24** on a slope of a third. The probe made two mistakes of
its own before that: it wrote a map whose values ran off the end of a byte, and it read buffers it
never drew into. None of that was a property of Core ML, and none of it is in what follows.

**The probe** is `tests/backports/host/vision/crop-probe/coords.m`, in the tree, with its build and
run in its header. **Its controls**, which is what makes its numbers mean anything:

| map it is given | scale x | offset x | scale y | offset y | rms | pixels |
| --- | --- | --- | --- | --- | --- | --- |
| x = 0.5d + 1, y = 1d + 3 -- no rounding anywhere | **0.50000** | **+1.000** | **1.00000** | **+3.000** | **0.0000** | 1952 |
| x = 2d + 0, y = 0.5d + 4 | 1.99854 | +0.238 | 0.50000 | +4.000 | 0.2499 | 1920 |
| x = 1.5d + 2, y = 3d - 8 | 1.50083 | +2.011 | 3.02222 | -7.904 | 0.3813 | 1020 |

The first has maps that land on whole source pixels, so the answer must be exact, and it is, to five
places on the scale and three on the offset, with a residual of zero. The other two have a half-step,
and come back within a quarter of a source pixel, which is the staircase of a nearest-neighbour step
and not an error in the fit.

**The twelve real cases**, each against Core ML's own option for that rule. Scale and offset are in
source pixels, and the offset is the source position at destination 0.

| case | scale x | offset x | scale y | offset y | rms | pixels |
| --- | --- | --- | --- | --- | --- | --- |
| 100x50 to 224x224, centre crop | 4.63073 | +24.397 | 4.56821 | -0.155 | 3.2769 | 50176 |
| 50x100 to 224x224, centre crop | 4.56821 | -0.155 | 4.69761 | +25.793 | 3.7462 | 50176 |
| 16x8 to 32x8, centre crop | 2.01925 | -0.158 | 2.02266 | +1.814 | 0.0555 | 256 |
| 10x10 to 30x20, centre crop | 3.39385 | -0.033 | 4.29270 | +3.002 | 1.2014 | 600 |
| 20x10 to 20x20, centre crop | 2.00116 | +4.753 | 2.03460 | -0.154 | 0.0700 | 400 |
| 100x50 to 224x224, scale fit | 2.24129 | -0.244 | 2.24064 | -25.245 | 0.2057 | 25084 |
| 50x100 to 224x224, scale fit | 2.24064 | -25.245 | 2.24129 | -0.244 | 0.2057 | 25084 |
| 16x8 to 32x8, scale fit | 1.00000 | -8.000 | 1.00000 | +0.000 | 0.0000 | 127 |
| 10x10 to 30x20, scale fit | 2.02845 | -2.649 | 2.02845 | -0.184 | 0.0947 | 399 |
| 5x10 to 30x20, scale fit | 2.11381 | -4.860 | 2.02789 | -0.186 | 0.1035 | 199 |
| 10x20 to 30x10, scale fit | 0.87500 | -12.802 | 0.60281 | +0.445 | 2.9810 | 60 |

**What these numbers are, and what they are not.** They are a measurement, not a crop rect. The one
case with a residual of **exactly zero** is 16x8 to 32x8 scale fit, and it reads scale 1.00000 on both
axes with offsets -8 and 0 -- a pure translation, which is what a picture of sixteen columns inside a
thirty-two wide target is, with an eight column bar. The other ten have residuals between 0.06 and
3.7, and the reason is the **blend**: a bilinear kernel puts every output between its neighbours, so
what comes back is a weighted point rather than a source pixel, and the fit recovers the blend rather
than the sample. The controls show the same thing from the other side -- a residual of zero only where
nothing is blended. So the rule for the crop rect **cannot be read off this table** until the blend is
accounted for, and doing that is the next piece of work, not a claim this table supports.

## The crop rect, read with the blend inverted rather than fitted

`tests/backports/host/vision/crop-probe/invert.m`, in the tree, with its build in its header. The
source is a ramp with **R = the column and G = the row**, so each channel is a function of one axis,
and a bilinear kernel puts a destination pixel between its two neighbours -- so for a ramp that *is*
the index, the value that comes out is `(1 - f) * floor(s) + f * ceil(s) = s` exactly. The red channel
of an output pixel **is** the fractional source column and the green channel **is** the fractional
source row: no fit, no staircase, nothing to interpret. The quantisation is `1/k` of a source column,
`k` being 255 over the largest position the case reaches.

| case | the geometry | the first lit output pixel | the source it sampled |
| --- | --- | --- | --- |
| 16x8 to 32x8, scale fit | scale 1, drawn 16x8, k=17 | (8, 1) | column 0, row 1 |
| 10x10 to 30x20, scale fit | scale 2, drawn 20x20, k=13 | (5, 1) | column 0, row 0.23 |
| 100x50 to 224x224, scale fit | scale 2.24, drawn 224x112, k=1 | (0, 58) | column 0, row 1 |
| 50x100 to 224x224, scale fit | scale 2.24, drawn 112x224, k=1 | (56, 2) | column 0, row 1 |
| 20x10 to 20x20, centre crop | scale 2, drawn 40x20, k=6 | (0, 1) | **column 4.833**, row 0.33 |

**Every scale fit starts exactly at `(target - drawn) / 2` on that axis**, which is the rule the port
implements: drawn 16x8 inside 32x8 bars at 8, drawn 20x20 inside 30x20 at 5, drawn 224x112 inside
224x224 at 56 vertically, drawn 112x224 at 56 horizontally. So the **-25 offsets in the fitted table
were the fit's own bias, not the framework's** -- a least-squares line through a blended ramp is
biased, and this reading, which needs no fit, contradicts them.

**And the one centre crop with a usable reading agrees with the port too.** A cover of 20x10 into
20x20: scale 2, drawn 40x20, the crop takes the middle 20 of the 40, so the source column at the
target's edge is `10 / 2 = 5.0`, and the measurement is **4.833** -- one sixth of a column low, which is
`1/k` at k=6, the quantisation and not a displacement.

So the crop rect is **measured, and it is the rule the port already implements**, which moves the red
centre-crop rows somewhere this probe has not looked: for a cover of a picture whose aspect differs,
the geometry agrees and every pixel still differs.

### The same ramp through both sides, and the difference

`tests/backports/host/vision/crop-probe/delta.m`, in the tree, links the port's own resampler beside
Core ML's constructor and decodes both answers back into source coordinates, then subtracts. For
**100x50 to 224x224 centre crop** (scale 4.48, drawn 448x224, inset -112, 0, k=1):

| axis | min | max | mean | spread | the difference along the middle row, every sixteenth |
| --- | --- | --- | --- | --- | --- |
| x (red) | 8 | 73 | 48.600 | 65 | 13 28 32 35 38 42 46 49 53 56 59 63 67 70 0 0 |
| y (green) | 1 | 49 | 24.712 | 48 | |
| pixels compared | | 49275 of 50176 | | | |

**Linear, and not either of the other two things.** A pixel-centre convention would be flat; this
runs from 8 at the target's left edge to 70 near its right, about 3.4 every sixteen output columns,
with a mean of 48.6 and a spread that covers the whole range -- so it is neither a constant nor noise.
(The last two samples fold to zero because the ramp wraps at 256 and the difference is taken modulo
it; the fold is at the source's far edge, which is itself the sign that the gap has grown by a whole
ramp.)

**The vertical is the alarming one**: the difference spans 1 to 49 -- the picture's whole height --
on an axis where the cover fits **exactly**, drawn 224 against a target of 224, so there is no crop
on that axis to differ about. Whatever is going on, it is not a placement.

### Core ML's centre crop, on every lit pixel, against two rules

`tests/backports/host/vision/crop-probe/four.m`, in the tree, fits four lines over Core ML's own
answer for 100x50 to 224x224 centre crop -- every one of the 49275 lit pixels, not a sample:

| what is fitted | slope | offset | rms | pixels |
| --- | --- | --- | --- | --- |
| red against x | 0.21618 | +24.493 | 2.3958 | 49275 |
| red against y | -0.00342 | +48.987 | 14.1794 | 49275 |
| green against x | 0.00072 | +24.632 | 14.0176 | 49275 |
| green against y | 0.21882 | -0.127 | 1.8443 | 49275 |

**No transposition**: each channel follows its own axis and nothing else -- green against x is
0.00072, red against y is -0.00342. **And the same rule scored, not fitted**, because a free fit
finds a line whatever the answer is and a rule has to be predicted:

| candidate rule | rms against the measured source columns |
| --- | --- |
| **A: the centre square, `src = (dst + 0.5) * (50/224) - 0.5 + 25`** | **2.6003** |
| B: the port's cover, 4.48, drawn 448, inset (448 - 224) / 2 = 112 | 49.1578 |

**So Core ML's centre crop is a centre *square* of the source, scaled to the target** -- A, by a
factor of nineteen -- and **the port implements a cover**, which is a different rule. That is why every
cover row of the check is red, and it is not a rounding, a kernel or a placement: the two rules are
different shapes.

The fits agree with A's prediction where it can be checked without a blend: the **offset is +24.493
against A's +24.61**, a tenth of a source column, which is the quantisation; the slope reads 0.216
against A's 0.2232, and the three per cent is the blended ramp's own bias -- the same bias the
earlier fits showed. The vertical carries the same 0.2232 scale and **no offset**, which is what
"the centre square" means: a square has the source's full height, so only x is offset by
(100 - 50) / 2 = 25.

### Which shape: the centre square, or the target's aspect?

`tests/backports/host/vision/crop-probe/shape.m`, in the tree. A square target cannot tell them
apart -- both give 50x50 of a 100x50 source -- so both are scored on the targets that are **not**
square, and on the control where they must coincide. Every lit pixel.

| case | rule | rms on x (source columns) | rms on y (source rows) | pixels |
| --- | --- | --- | --- | --- |
| 16x8 to 32x8 | the centre square, 8x8 | 2.2650 | 1.1594 | 256 |
| 16x8 to 32x8 | **the target's aspect, 16x4** | **0.0713** | **0.0488** | 256 |
| 10x10 to 30x20 | the centre square, 10x10 | 0.9025 | 1.9215 | 600 |
| 10x10 to 30x20 | **the target's aspect, 10x6.67** | 0.9025 | **1.2868** | 600 |
| 20x10 to 20x20 | both, 10x10 -- a square source | 0.0192 | 0.0653 | 380 |

**The target's aspect wins outright on 16x8 to 32x8** -- 0.07 of a source column against the square's
2.27, the square being 0.05 of a row off and the aspect 0.07 of a column, both the quantisation at
k=17. On 10x10 to 30x20 they tie on x, as they must, and separate on y: 1.92 against 1.29. The last
row is the control, and the two print the same numbers because a square source into a square target
has one rect.

**So the rule is the largest centred rect of the source with the target's aspect**, and on a square
target that is a 50x50 rect of a 100x50 source -- which is what the 224x224 case measured, the
+24.493 against a predicted +25. The square and the aspect are therefore **one rule** on a square
target, and a rule I was about to code as "the centre square" would have been wrong on every
non-square one.

**A sign error of mine, in the candidate I called "the port's rule".** The 49.16 that probe reported
for candidate B is *not* a measurement of the port. B was written by hand as
`src = (dx - 112 + 0.5) * (100/448) - 0.5`, and the inset is **negative** in the store address, so
the index within the drawn picture is `dx + 112`, not `dx - 112`. With the sign right the prediction
is `(dx + 112.5) * 0.2232 - 0.5 = 24.61 + 0.2232 dx`, which is candidate A to two places. So the
port's rule and Core ML's rule are the same, the 49.16 was my arithmetic, and the red cover row is a
defect in the port's **code** that this does not locate.

## What is not carried

The Core ML request is the one request Vision here really runs, and the paragraph above says so with
its measurements. These are the parts of the surface that are still not carried, each one against
what the tree and the registry say rather than against an intention.

- Detecting a barcode, a rectangle, a face and its landmarks is still next: `-performRequests:error:`
  answers `VNErrorNotImplemented` for every request but the Core ML one, so no request of those kinds
  runs. Their observations are implemented as classes with the properties and accessors the release
  declares, and an application can make one itself, but nothing in the port produces one: the
  landmark regions answer no points, because there is no request to make them from.
- `+[VNDetectFaceLandmarksRequest revision:supportsConstellation:]` arrived in iOS 13 and is not
  carried. Its row in `registry/Vision/ios11.json` is `absent`, with the reason the port does not
  detect the constellation of face landmarks, and the selector is in none of the port's own sources.
- The host's Vision is newer than the releases read here and differs in what it does with a tracker's
  level (it ignores it), a copy of an observation (it returns the same object), a yaw out of range
  (it clamps) and the symbologies it reads by default (it has more). The port follows iOS 12 there,
  and the records leave those out.

## Vision of iOS 11.0 and later, on releases that have none of it

`libVisionBackports.dylib`, built with the `vision` config, carries the parts of Vision that a release
without Vision can still answer: the request objects, and the constants a caller may name directly. This
file is what the work was read out of, what the store is, and where the constants' values come from.

### What was measured, and from what

**The framework is absent from the port's releases.** Neither the armv7 shared cache of iOS 6.1.3 nor the
one of iOS 4.3 holds a Vision image, and neither exports a name of it. Read with the repository's own
reader, `tools/corpus/dump-cache.lua`, over both caches:

    cache      export lines   Vision   Foundation   UIKit
    6.1.3          264,243        0        1,171    3,147
    4.3            164,907        0          900    2,816

Foundation and UIKit are the controls that say the probe finds what is there: a reader that found nothing
anywhere would prove nothing, and these two are present in both. `PassKit` is a third control and is
counted in 6.1.3 (308) and absent from 4.3, which is correct - PassKit arrived in iOS 6.0 - so it is not
offered as a control for the older rung. **So nothing here is a release's own, and every Vision row is the
port's.** That single fact is why 138 rows are `absent`, and each of those rows' reason cites this page.

**The constants' values are not in the headers.** A declaration such as

    VN_EXPORT VNHumanBodyPoseObservationJointName const VNHumanBodyPoseObservationJointNameNose
        API_AVAILABLE(macos(11.0), ios(14.0), tvos(14.0), watchos(14.0));

carries the type, the name and the availability, and **not the value**: an `NS_TYPED_ENUM` string constant's
value lives in the framework image, not in a header line. So a header can say when a constant arrived and
what it is called, and nothing about what it equals. **The name is never the value**, and no value is typed
here.

Where the value comes from, and which release has Apple's own body for the class:

    $ xmake l tools/cache-index/first-rung.lua VNDetectHumanBodyPoseRequest VNRecognizeAnimalsRequest
    VNDetectHumanBodyPoseRequest   16.0
    VNRecognizeAnimalsRequest      16.0

`first-rung.lua` is a PRESENCE oracle, not a version oracle: it says the name is real and which held release
has Apple's own implementation of it. 16.0 is the nearest held release that carries Vision at all - the
held set is dense to 12.0 and then jumps to 16.0 and 18.0, so a name the SDK dates to 13.0 or 14.0 reads as
"16.0" here. The SDK headers and `coordination/corpus/sdk-26.2-surface.tsv` are the VERSION oracle, and
`introduced` comes from them.

### What a caller gets on a release with no Vision

A Vision class is not there: `NSClassFromString` answers nil and a compile-time reference to it crashes. A
Vision constant that this port exports is the framework's own text, so a code path that names it directly,
without a check of the release, links and does not read a null pointer - and then nothing on this release
can act on it, because there is no Vision to act with. Both halves belong in a constant row's `effect`, and
neither half alone is honest.
