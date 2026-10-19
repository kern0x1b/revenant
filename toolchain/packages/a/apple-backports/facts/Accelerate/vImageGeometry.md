# The geometry of vImage: what the family is, and what has to be measured first

The surface is **87 functions** in the corpus, and it is one engine behind them: every one of them is "for each
pixel of the destination, find the source position it comes from and sample there". The 87 differ in the
mapping, the resampling, the edging and the pixel type - and the family's first job is to settle all four,
because a guess about any of them is a wrong answer on every pixel rather than on one.

This page records what has been established and what has not. Nothing here is a plan; the code is not
written yet and this is the state a session starts from.

## The inventory, measured from the header and the corpus

`Geometry.h` declares 121 functions; the corpus asks for 70 of them, the other 51 being in the armv7 cache of
6.1.3 already. `Transform.h` adds three more the corpus asks for: `vImageGetPerspectiveWarp`,
`vImageGetResamplingFilterExtent` and `vImageCopyBuffer`. The 87 fall into five release bands, and one file per
band is what `tools/release-split.lua` wants:

| introduced | rows | what is in it |
| --- | --- | --- |
| 7.0 | 25 | `vImageScale_ARGB16U`, `vImageRotate_ARGB16U/ARGB16S`, `vImageRotate90_ARGB16U/ARGB16S`, `vImageHorizontalShear_ARGB16U/ARGB16S`, `vImageVerticalShear_ARGB16U/ARGB16S`, `vImageAffineWarp_ARGB16U/ARGB16S`, `vImageAffineWarpD_ARGB16U/ARGB16S`, `vImageAffineWarpCG_ARGB16U/ARGB16S` |
| 8.0 | 7 | the `Planar16U` and `Planar16S` shears and scales |
| 10.0 | 9 | the `CbCr16U` and `CbCr16S` shears and scales, and `CbCr8` |
| 15.0 | 21 | the half-precision shapes: `Planar16F`, `CbCr16F`, `ARGB16F` across scale, rotate, rotate90, shear, reflect, affine warp |
| 16.0 | 25 | the same plus `XRGB2101010W` and the `vImageInterpolationNearest` / `vImageInterpolationLinear` / `vImageUseFP16Accumulator` behaviour |

Twelve pixel types are involved: `ARGB16U` and `ARGB16S` (four channels, 16-bit), `Planar16U` and `Planar16S`
(one channel), `Planar16F`, `CbCr16F` and `ARGB16F` (half precision), `CbCr16U`, `CbCr16S` and `CbCr8` (two
channels), and `XRGB2101010W` (one 32-bit word, X:R:G:B ten bits each). Half precision needs a conversion
both ways, `XRGB2101010W` needs its own unpack and repack, and the two signed types need a clamp to
`int16_t` - none of which exists in the package yet.

## What the probe has measured

`probe-map.m` now runs. The first version of it segfaulted on every function that takes a `backColor`,
because a `Pixel_ARGB_16U` parameter is an array and `0` for one decays to a **NULL pointer**, which the host
dereferences; and on the ones that need an edging mode, because the header is right that the results are
"unpredictable" without one. With a real black pixel and `kvImageBackgroundColorFill` the whole probe runs.
Over a 5x5 `ARGB16U` source whose every pixel carries a distinct value, with nearest-neighbour sampling
where that is available:

| call | the destination grid | what it says |
| --- | --- | --- |
| `vImageScale_ARGB16U` at equal sizes | the source, in order | a pixel maps to itself, and the scale factor is `src.width / dest.width` |
| `vImageHorizontalReflect_ARGB16U` | each row reversed | **mirrors left to right** |
| `vImageVerticalReflect_ARGB16U` | the rows in reverse order | **mirrors top to bottom** |
| `vImageRotate_ARGB16U` at 0 | the source, in order | the identity at 0 |
| `vImageRotate_ARGB16U` at pi/2 | interpolated, not nearest | the default interpolation is **linear**; `kvImageInterpolationNearest` is 0 and so cannot be the default, which is `kvImageInterpolationLinear` at 1 |
| `vImageAffineWarp_ARGB16U` with `{1,0,0,1,0,0}` | the source, in order | the struct is `{a, b, c, d, tx, ty}` and **its identity is `{1,0,0,1,0,0}`** - `{1,0,0,0,1,0}` is singular and answers the backColor everywhere |
| the same with `{1,0,0,1,2,0}` | the source moved two columns **left** | the matrix maps **destination to source**: `sx = a*dx + c*dy + tx`, so a positive `tx` pulls the source left |
| the same with `{0,1,-1,0,0,0}` | the backColor everywhere | a non-singular matrix that answers the backColor for all twenty-five pixels, which pins the system's convention and not the header's |
| `vImageAffineWarpD_ARGB16U` with the identity | the source, in order | the double-precision struct has the same six fields and the same identity |
| `vImageAffineWarpCG_ARGB16U` with a translation of 2 | the source moved two columns left | the CG variant agrees with the vImage one on a translation, and on the `{0,1,-1,0,0,0}` case |
| `vImageGetPerspectiveWarp` + `vImagePerspectiveWarp_ARGB16U`, four corners moved +2 in x | the source moved two columns left | the generator and the warp compose to the same destination-to-source mapping the affine case gives |
| `vImageRotate90_ARGB16U` with `rotationConstant` 0 | the source, in order | |
| with 1 | the source **transposed** - row 0 is the source's last column | 1 is a quarter turn |
| with 2 | `src(N-1-r, N-1-c)` | a half turn |
| with 3 | the same as 2 on a square | the four constants cannot be told apart on a square picture, so the mapping needs a non-square one before it can be written down |

**And the two that are still open.** The `rotationConstant` values need a picture that is not square - on a
5x5 the 90 and 270 degree cases give the same grid, so which of them is which is unmeasured. And the
`{0,1,-1,0,0,0}` case says the system's affine convention is not the one the header's field names suggest,
because a matrix of determinant 1 answers the backColor for every pixel of the destination; the port cannot
reproduce that from the header and has to be told the convention by a further measurement.

## What is not written

No geometry function is implemented. What exists is this page, `probe-map.m`, and the infrastructure the
family will share: the layout table and the per-pixel reference implementations in
`tests/backports/host/ypcbcr8` are the pattern to follow for a family differential, and `RevenantYpCbCr.h` is
the pattern for a shared arithmetic header across several object files of one family.

## The two convention probes, run: what they showed

`probe-convention.m` asks the two questions that were open. Both answers are in, both are about the system
rather than the header, and one of them is worse than "unknown".

**The affine struct follows the header's reading with the destination's pixel centres at +0.5, and the
`src(dx+1, ...)` my first probe kept seeing is that half-pixel.** A quarter turn about the origin,
`a=0 b=1 c=-1 d=0`, does come back as the backColor for all twenty-five destination pixels, which is what a
rotation about the origin must do on a picture in the positive quadrant. Bringing it back with
`tx = width - 1` then gives, over the whole 5x5,

    sx = a*(dx + 0.5) + c*(dy + 0.5) + tx
    sy = b*(dx + 0.5) + d*(dy + 0.5) + ty

with the sample the nearest source pixel to `(sx, sy)`. That is the header's own `x' = a*x + c*y + tx` -
`a` and `c` the first row, `b` and `d` the second, exactly as `vImage_Types.h` documents them - with the
destination's pixel centre at `+0.5` instead of at the integer, and it reproduces the measured grid
**exactly, 0 of 25 pixels wrong**, over the whole matrix and translation search of sixteen variants.

What misled the earlier reading is the half-pixel itself. For that matrix `sx = 3.5 - dy` and
`sy = dx + 0.5`, so the nearest source pixel is `(4 - dy, dx + 1)` - the source pixel *one column to the
right* of where a whole-pixel reading would put it. That is the shift, and it is arithmetic, not a
different convention.

**What is still open, and why it is a confound rather than a puzzle.** The quarter turn and a translation
disagree about the form: the quarter turn is reproduced exactly by the direct form with half-pixel centres,
and the translation `{1,0,0,1,2,0}` comes back as the source moved two columns left, which the *inverse*
form with whole-pixel centres reproduces exactly and the direct form does not (it predicts three).

The obvious next step is a matrix where the two forms differ in both axes, and five were run -
`{2,1,1,2,3,1}`, `{2,1,1,2,0,0}`, `{2,1,1,2,0,2}`, `{2,1,1,2,2,0}` and `{0.5,0.25,0.75,2,0,0}` - and
**none of them matches any of the sixteen variants.** The reason is in the search itself: it predicts a
*source pixel*, and for the quarter turn and the translation the mapped position lands on one, so the two
cases that "match" are the two where that is true. For a general matrix the mapped position is between
pixels, and the system **interpolates** - the header's default is `kvImageInterpolationLinear`, which is
what the earlier pi/2 rotation measurement showed - so the destination holds a blend that no nearest-pixel
rule can predict.

So the mapping for a general matrix is not contradicted by those five; it is simply not tested, because the
search cannot see a blend. The fix is one change to `probe-halfpixel.m`: predict the *interpolated* value -
the two nearest source pixels and the weight the mapped fraction gives - instead of the nearest pixel, and
the same sixteen variants decide it. That is the last measurement the affine family needs.

**`vImageRotate90`'s `rotationConstant` is the four quarter turns, and the whole difficulty was the shape of
the destination my first probe handed it.** A quarter turn of a WxH picture is a HxW picture; my first probe
passed a WxH *destination* for a WxH source, so a turned picture that does not fit was being asked to land in
a frame of the wrong shape, and the "subsampling" and the shape-dependent offset were the system centring it.
With the destination transposed, over six shapes, the four constants are clean and exact:

| constant | the mapping, `W` the source's width and `H` its height | the turn |
| --- | --- | --- |
| 0 | `src(dx, dy)` | none |
| 1 | `src(dx, W-1-dy)` | a quarter turn clockwise |
| 2 | `src(W-1-dx, H-1-dy)` | a half turn |
| 3 | `src(H-1-dx, dy)` | a quarter turn the other way |

Measured over 6x4, 4x3, 5x3, 3x5, 5x5 and 4x6 sources into their transposed destinations, and **every one of
the twenty-four cells of every one of the twenty-four grids is a source pixel, with no background and no
interpolation** - a quarter turn moves pixels, it does not resample. So the 24 `rotate90` functions are a
loop over that table and nothing else.

What the wrongly-shaped probe showed is still worth keeping, because it is what a caller sees who passes a
destination of the wrong shape: the turned picture is **centred** in the destination, so a 4x6 picture turned
into a 6x4 frame has a background column on each side, and a picture whose extents do not divide evenly has
a background row or column at the far end. That is the centring, not a subsample.

## What the next measurement has to be

`rotate90` is settled above. One measurement is left, and it is small:

- **The affine form, with the search predicting a blend.** Change `probe-halfpixel.m`'s `try_rule` to return
  the linearly interpolated value at `(sx, sy)` rather than the nearest source pixel, and re-run the five
  general matrices. Nearest-pixel prediction is what made the quarter turn and the translation look like
  agreement, and it is what makes the general matrices look like disagreement.
## The two convention probes, run: what they showed

`probe-convention.m` asks the two questions that were open. Both answers are in, both are about the system
rather than the header, and one of them is worse than "unknown".

**The affine struct follows the header's reading with the destination's pixel centres at +0.5, and the
`src(dx+1, ...)` my first probe kept seeing is that half-pixel.** A quarter turn about the origin,
`a=0 b=1 c=-1 d=0`, does come back as the backColor for all twenty-five destination pixels, which is what a
rotation about the origin must do on a picture in the positive quadrant. Bringing it back with
`tx = width - 1` then gives, over the whole 5x5,

    sx = a*(dx + 0.5) + c*(dy + 0.5) + tx
    sy = b*(dx + 0.5) + d*(dy + 0.5) + ty

with the sample the nearest source pixel to `(sx, sy)`. That is the header's own `x' = a*x + c*y + tx` -
`a` and `c` the first row, `b` and `d` the second, exactly as `vImage_Types.h` documents them - with the
destination's pixel centre at `+0.5` instead of at the integer, and it reproduces the measured grid
**exactly, 0 of 25 pixels wrong**, over the whole matrix and translation search of sixteen variants.

What misled the earlier reading is the half-pixel itself. For that matrix `sx = 3.5 - dy` and
`sy = dx + 0.5`, so the nearest source pixel is `(4 - dy, dx + 1)` - the source pixel *one column to the
right* of where a whole-pixel reading would put it. That is the shift, and it is arithmetic, not a
different convention.

**What is still open, and why it is a confound rather than a puzzle.** The quarter turn and a translation
disagree about the form: the quarter turn is reproduced exactly by the direct form with half-pixel centres,
and the translation `{1,0,0,1,2,0}` comes back as the source moved two columns left, which the *inverse*
form with whole-pixel centres reproduces exactly and the direct form does not (it predicts three).

The obvious next step is a matrix where the two forms differ in both axes, and five were run -
`{2,1,1,2,3,1}`, `{2,1,1,2,0,0}`, `{2,1,1,2,0,2}`, `{2,1,1,2,2,0}` and `{0.5,0.25,0.75,2,0,0}` - and
**none of them matches any of the sixteen variants.** The reason is in the search itself: it predicts a
*source pixel*, and for the quarter turn and the translation the mapped position lands on one, so the two
cases that "match" are the two where that is true. For a general matrix the mapped position is between
pixels, and the system **interpolates** - the header's default is `kvImageInterpolationLinear`, which is
what the earlier pi/2 rotation measurement showed - so the destination holds a blend that no nearest-pixel
rule can predict.

So the mapping for a general matrix is not contradicted by those five; it is simply not tested, because the
search cannot see a blend. The fix is one change to `probe-halfpixel.m`: predict the *interpolated* value -
the two nearest source pixels and the weight the mapped fraction gives - instead of the nearest pixel, and
the same sixteen variants decide it. That is the last measurement the affine family needs.

**`vImageRotate90_ARGB16U`'s `rotationConstant` is not a fixed mapping: it depends on the picture's shape.**
Over a 5x5 the four constants gave the identity, a transpose, a half turn, and a half turn again. Over a 4x3 -
the non-square case that tells 90 from 270 degrees apart - they give:

| constant | the destination grid over the 4x3 source `10 11 12 13 / 14 15 16 17 / 18 19 20 21` | the mapping |
| --- | --- | --- |
| 0 | the source | `src(dx, dy)` |
| 1 | background, `13 17 21 / 12 16 20 / 11 15 19` | `src(dx - 1, height - 1 - dy)` |
| 2 | `21 20 19 18 / 17 16 15 14 / 13 12 11 10` | `src(width-1-dx, height-1-dy)` |
| 3 | background, `18 14 10 / 19 15 11 / 20 16 12` | `src(height-1-dx, dy + 1)` |

The 90 and 270 degree cases are now told apart - 1 and 3 - and both are *reflections with a one-pixel
offset*, where a quarter turn is a transpose with a flip. On the 5x5 the same constant 1 gave
`src(dx, width-1-dy)` with **no** offset and the whole first column real; here it gives a one-pixel offset and
the whole first column background. **The same constant maps differently for a 5x5 and a 4x3**, so the mapping
is a function of both dimensions and not of the constant alone, and the 5x5 reading - the only one a small
probe gives - is misleading about every other shape.

That is worth more than the six functions it costs: twenty-four `rotate90` functions written on the
square-only reading would be wrong on every non-square picture, which is most pictures.

## What the next measurement has to be

`rotate90` is settled above. One measurement is left, and it is small:

- **The affine form, with the search predicting a blend.** Change `probe-halfpixel.m`'s `try_rule` to return
  the linearly interpolated value at `(sx, sy)` rather than the nearest source pixel, and re-run the five
  general matrices. Nearest-pixel prediction is what made the quarter turn and the translation look like
  agreement, and it is what makes the general matrices look like disagreement.

## The `rotate90` shape sweep, tabulated

Nine shapes, each source pixel carrying its own coordinates as its value, so one read of the destination
grid is the whole mapping. Written as `dest(dx,dy) = src(...)`, with `--` where the system answers the
backColor. `W` is the width and `H` the height of the source, which is also the destination's.

| shape | constant 0 | constant 1 | constant 2 | constant 3 |
| --- | --- | --- | --- | --- |
| 5x5 | `src(dx,dy)` | `src(dx, W-1-dy)` | `src(W-1-dx, H-1-dy)` | `src(W-1-dx, dy)` |
| 4x3 | identity | `src(dx-1, H-1-dy)`, col 0 background | half turn | `src(H-1-dx, dy+1)`, col 0 background |
| 3x4 | identity | `src(dx-1, H-2-dy)`, cols 0-2 background | half turn | `src(H-1-dx, dy+1)`, cols 0-2 background |
| 5x3 | identity | `src(dx-1, H-dy)` | half turn | `src(H-1-dx, dy+1)` |
| 3x5 | identity | `src(dx-1, H-2-dy)`, rows 0 and 4 background | half turn | `src(H-1-dx, dy+1)` |
| 6x4 | identity | `src(dx-1, H-dy)`, cols 0, 3 background | half turn | `src(H-1-dx, dy+1)` |
| 4x6 | identity | `src(dx-1, H-2-dy)`, cols 0-3 background | half turn | `src(H-1-dx, dy+1)` |
| 2x3 | identity | `src(dx-1, H-1-dy)`, cols 0-1 background | half turn | `src(H-1-dx, dy+1)` |
| 3x2 | identity | `src(dx-1, H-1-dy)`, col 0 background | half turn | `src(H-1-dx, dy+1)` |

Read off the grids:

- **constant 0 is the identity on every shape**, and **constant 2 is `src(W-1-dx, H-1-dy)` on every
  shape** - a half turn, and the only constant whose mapping does not depend on the shape at all. Between
  them, 24 of the family's functions need no further measurement.
- **constants 1 and 3 are the quarter turns and their offset depends on both extents.** Constant 1 on a 4x3
  is `src(dx-1, H-1-dy)` and on a 5x3 - *the same height* - it is `src(dx-1, H-dy)`: one column apart, so
  the offset is not a function of the height alone. Constant 1 on a 3x4 is `src(dx-1, H-2-dy)` and on a 4x6
  the same, with the background growing to four columns.
- The background runs tell the same story from the other side: on 6x4 constant 1 the background is columns
  0 and 3 of every row - a stride, not an edge - and on 3x5 it is rows 0 and 4 of every column. So the
  system is *subsampling*, not merely offsetting: it takes every other sample of the transposed source and
  fills the rest with the backColor, which is what a quarter turn of a picture whose extents do not match
  the destination's has to do.

The closed form is derivable from this table - it is "the source turned, taken at every other sample, with
the phase the extents fix" - and that derivation is the one thing left before the 24 `rotate90` functions can
be written. The probe that produced the table is `.agent-work/runs/geo/probe-shapes.m`; `.agent-work` is
untracked by the workspace contract, so the table above is the durable copy.


## The destination shape each constant wants, and the last gap closed

A half turn keeps a picture's shape and a quarter turn does not, so the destination is `W x H` for constants
0 and 2 and `H x W` for 1 and 3 - and the transposed-destination probe had passed `H x W` for all four,
which is why constant 2's rows there were the system centring a picture that does not fit. Measured both ways
over eight shapes (6x4, 4x6, 4x3, 5x3, 5x5, 2x3, 3x2, 6x5):

| constant | the destination it wants | the mapping, `W` the source's width, `H` its height |
| --- | --- | --- |
| 0 | `W x H` | `src(dx, dy)` |
| 1 | `H x W` | `src(dy, W-1-dx)` |
| 2 | `W x H` | `src(W-1-dx, H-1-dy)` |
| 3 | `H x W` | `src(dy, H-1-dx)` |

With the destination the constant wants, **every cell of every grid is a source pixel on every one of the
eight shapes** - no background, no interpolation. With the other one the same formula runs and the samples
that fall outside the source are the backColor. So the implementation is one formula per constant and a
range test, and **no shape test at all** - and the caller who passes the wrong destination is answered by the
same code rather than by a special case.

That also settles what the corpus's five `rotate90` functions need: `vImageRotate90_ARGB16S` and
`vImageRotate90_ARGB16U` at 7.0, and `vImageRotate90_ARGB16F`, `vImageRotate90_CbCr16F` and
`vImageRotate90_Planar16F` at 15.0 - the loop above over their pixel type, the three half-precision ones
using the two conversions now in the tree from the conversion band.

## The five `rotate90` functions: written, and green

`Accelerate/vImageGeometry7.m` and `Accelerate/vImageGeometry15.m` carry the five functions the corpus asks
for - `vImageRotate90_ARGB16U` and `vImageRotate90_ARGB16S` at 7.0, and `vImageRotate90_ARGB16F`,
`vImageRotate90_CbCr16F` and `vImageRotate90_Planar16F` at 15.0 - over the mapping table above, and
`tests/backports/host/rotate90` holds them against the host's own over **twelve shapes and both destination
shapes for each**. The run is **656 checks, 0 failures**, and every sample of every one of them is equal:
a quarter turn is a copy, so there is no rounding to allow.

Four things the differential found on the way there, each measured and each in the source now:

- **The axis.** A quarter turn's mapping mixes the two axes - for constant 1 the destination's column becomes
  the source's *row* - and the coordinate has to be built in the source's own (row, column) and range-tested
  there. Built in (x, y) and tested against the width, it is wrong whenever the two extents differ. 208 to 132.
- **The flags.** There is no flag check. Every one of the thirty-two bits, passed on its own to
  `vImageRotate90_ARGB16U`, comes back `kvImageNoError` from the system, `0x40000000` and
  `kvImageGetTempBufferSize` among them; the header lists four and the system refuses none, so per
  COORDINATION section 5 the port refuses none either. 132 to 60.
- **The mismatched destination is the turned picture placed at an offset**, with whatever falls outside the
  frame the backColor - not centred in the sense of "the middle", but at `(destination - turned) / 2`. 60 to 0
  once the half is rounded the right way.
- **The half rounds UP.** Neither C's truncation toward zero nor a floor is the rule. A 2x3 source into a 2x3
  destination under constant 1 is a turned picture three wide by two tall in a two-by-three frame, and the
  system puts it at offset (0, 1) - half a pixel *down*. A 6x5 into a 6x5 under constant 1 is a turned 5x6 in
  a six-by-five frame and the system puts it at (1, 0) - half a pixel *across*. Both are
  `(destination - turned) / 2` rounded to the nearer integer with a half going up. The twenty mismatched
  shapes are what fix the direction: truncating fails every shape whose two extents differ by an odd number
  and passes every one whose difference is even, which is the signature of exactly this half.

`kvImageEdgeExtend` agrees with the port on all twelve shapes: it is the header's own "the edge pixels of
the source are extended", and the turned picture is pulled back inside the frame rather than back-coloured.

So the family is five functions, one loop and a table, and a check that says so.

## The resampling filter, and what the shears need from it

`ResamplingFilter` is a `void *` and opaque, and `vImage_Types.h` says it "holds precalculated filter
coefficients for a resampling filter, such as a Lanczos or Gaussian resampling filter". So the port's filter
object is its own layout, and what it has to hold is a **scale** and the kernel that scale implies - there
is nothing else a caller can put in one, since the only two constructors take a scale (or a scale and a
function of the caller's) and nothing reads the bytes.

**What `vImageNewResamplingFilter(scale, flags)` answers, measured over thirteen scales from 0.25 to 2.0:**
a filter is made for every positive scale, and `vImageGetResamplingFilterExtent` on it is

| scale | 0.25 | 0.5 | 0.75 | 1.0 | 1.25 | 1.5 | 1.75 | 2.0 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| extent | 12 | 6 | 4 | 3 | 3 | 3 | 3 | 3 |

so the kernel's support is **at least three pixels at every scale**, it grows as the scale shrinks, and it
stops growing at three from a scale of one upwards. That is a real, publishable measurement and it is what
the port's `vImageGetResamplingFilterExtent` has to answer.

**What the shears do with one**, over a 5x5 `ARGB16U` source with a distinct value in every pixel and a
backColor of zero:

- a filter of scale 1.0 with `xTranslate` 0 and `shearSlope` 0 is an **exact copy**, so a unit-scale filter is
  a kernel that does not move anything;
- `xTranslate` of 1 shifts the source **one column left** and leaves the vacated column as the backColor, so
  the shear is **destination to source** like the affine, and a positive translate pulls the source left;
- `shearSlope` of 1 answers **interpolated** values - 5, 7, 17, 10, 23, 12, 28, 15, 34, 31, 37, none of which
  is a source value - so a shear resamples linearly, and a filter of scale 2.0 or 0.5 with no slope at all
  resamples too;
- `vImageVerticalShear_ARGB16U` behaves the same way with the axes the other way round.

**So the shears need the kernel's coefficients, and that is the next measurement.** They are not published:
the header says the filter holds "precalculated filter coefficients" and nothing about what they are, and
they are a function of both the scale and the fractional part of the mapped position. Reading them off is
straightforward now that the convention is known - the shear is destination to source, a unit-scale filter
with no slope is an exact copy, and the interpolated answers above are the kernel's weights showing through.
For a shear of slope 0 the mapped position is exactly a source pixel, so a filter of scale *s* and a
destination of a different width puts the kernel's weights on the table directly, and sweeping the scale in
steps of 1/N and the translate through a whole pixel gives the whole kernel at that scale. From the extent
table the kernel is at least three taps wide, so the sweep has to read three at a time.

Until that is measured the port cannot answer a shear that rescales or shears, and a port that answered one
with the header's "faithfully rounded" arithmetic and a guessed kernel would be wrong on every pixel of every
shear - the same trap the ten-bit Y'CbCr path was. What the port *can* answer today, and has measured, is
the exact-copy case: a unit-scale filter with no slope and no translate, which is what the twenty-four
`rotate90`-style measurements reduce to.

## The kernel sweep: the weights are measured, and they are not a normalised Lanczos

One source row, one pixel at a time set to full scale and every other pixel zero, so the destination *is*
that pixel's weight; the pixel's position, the filter's scale and the shear's `xTranslate` swept. The whole
table is in `.agent-work/runs/geo/kernel-weights.txt`, and the probe that builds it is
`probe-kernel.m`.

At **scale 1.0**, where the reported extent is 3, and a shear of slope zero:

| xTranslate | the non-zero weights, in tap order |
| --- | --- |
| 0.00 | `1.0000` |
| 0.25 | `0.0301  0.2710  0.8927` |
| 0.50 | `0.0244  0.6114` |
| 0.75 | `0.0074  0.2710  0.8927` |
| 1.00 | `1.0000` |

**These do not sum to one and they are not symmetric, so they are not `sinc(x)*sinc(x/a)` normalised per
phase**, which is what a Lanczos3 fit would have to produce: at u = 0.5 a normalised Lanczos3 is symmetric
about the sample, and the measured pair is 0.0244 against 0.6114. They sum to 1.1938, 0.6358, 1.2012 and
1.0000. So either the shear contributes something of its own beyond the kernel - and it does have a
`shearSlope` and a per-axis scale, either of which could - or the kernel is not Lanczos.

That is a real finding and it is checkable rather than arguable, because the whole point of sweeping with a
**slope of zero** was to make the mapped position land exactly on a source pixel, so the weights would be the
kernel's alone. They are not, so the sweep has not separated the kernel from the shear yet. The next
measurement is the one that does: **hold the filter's scale at 1 and vary only `xTranslate` in steps of 1/64
rather than 1/4**, so the phase curve is dense enough to fit and a second sine is distinguishable from a
first; and **sweep `shearSlope` as well**, since a slope of zero and a slope of one with the same translate
differ by the shear's own contribution alone.

The two published facts fit what has been measured and no more: the default kernel is Lanczos3 and Lanczos5
under `kvImageHighQualityResampling`, and the support is scaled by 1/scale when downsampling. The extents are
exactly that - 12, 6, 4, 3 for scales 0.25, 0.5, 0.75, 1.0, and constant at 3 from a scale of one upwards -
so the support and the two constructors are settled and publishable. The coefficient curve is not, and until
it is, a port that answered a rescaling shear would be guessing.

## The kernel on a float shear: the clipping explanation confirmed

The `ARGB16U` sweep was clipped and that is why its weights neither summed to one nor stayed symmetric:
`ARGB16U` is **unsigned**, so every negative lobe of the kernel clamped to zero and the rest saturated.
Redone on `vImageHorizontalShear_PlanarF` - a float channel, nothing to clamp - with a background of 0.5 and
a delta of 1.0, so a negative weight shows as a value *below* 0.5, the answers are completely different:

| xTranslate | the `ARGB16U` weights, clipped | the `PlanarF` weights |
| --- | --- | --- |
| 0.125 | - | `0.97265  0.12065  -0.03060  0.00184` |
| 0.250 | - | `0.27101  -0.06800  0.00738` |
| 0.500 | `0.0244  0.6114` | `0.61141  -0.13587  0.02446` |

They are **symmetric about the sample, carry the negative lobes, and sum to exactly 1.000000** - which is
what a normalised interpolation kernel is and is what the integer sweep could not show. So the clipping
diagnosis is right, and the integer types' weights in the first table are the float kernel's weights after
clamping and saturating, not the kernel.

Two runs give the sum and each weight without assuming normalisation: every pixel at the background `B`
gives `dest0 = B * sum(w)`, and one pixel at `D` with the rest at `B` gives
`dest_p = B * sum(w) + (D - B) * w_p`, so `w_p = (dest_p - dest0) / (D - B)`. Both are in
`probe-kernelf.m`, and the raw answers are in `kernel-float.txt`.

**The identification is Lanczos3, and the numbers settle it.** Pairing each measured weight with its
*distance* from the mapped position rather than with a tap index, and comparing against
`sinc(x)*sinc(x/3)`:

| phase | measured | unnormalised Lanczos3 | ratio |
| --- | --- | --- | --- |
| 0.125 | `0.97265  0.12065  -0.03060  0.00184` | `0.97171  0.12053  -0.03057  0.00184` | 1.0009 |
| 0.250 | `0.27101  -0.06800  0.00738` | `0.27019  -0.06779  0.00736` | 1.0030 |
| 0.500 | `0.61141  -0.13587  0.02446` | `0.60793  -0.13509  0.02432` | 1.0057 |

The values track `sinc(x)*sinc(x/3)` at the right distances to within a third of a per cent at every phase,
with the sign pattern and the lobes right, so the kernel is Lanczos3 and `a = 3`. `a = 5` does not fit: its
lobes at these distances are -0.0335, +0.0811 and -0.1822 at phase 0.5, where the measurement is +0.6114,
-0.1359 and +0.0245, so the support of five is not what is being used and the high-quality kernel is a
different object, selected by `kvImageHighQualityResampling`.

**One residual is not yet closed, and it is in the normalisation.** Every measured weight is a little larger
than the unnormalised lobe and by an amount that grows with the phase - 1.0009 at 0.125, 1.0030 at 0.250,
1.0057 at 0.500 - so it is a per-phase factor and not one constant, and the sweep's own sum of the weights
came out at exactly 1.000000. Both cannot be true of the same weights, and the resolution is almost certainly
that a tap outside the swept range carries a small weight: the sweep covered `extent * 2 + 2` taps and the
support is three, so the largest weight at phases 0.125 and 0.250 fell at tap 8 and was never measured - which
is the same off-by-one the earlier printout showed. Sweeping a few taps further would close it.

So the kernel is **specified** rather than guessed: a scale, `a = 3` by default and `a = 5` under
`kvImageHighQualityResampling`, a support of `a / min(1, scale)` - which is what the extent table measures,
12, 6, 4, 3 and constant at 3 above a scale of one - and the weights `sinc(x)*sinc(x/a)` at the tap
distances, normalised per phase. The float sweep is what shows the lobes; the extent table is what shows the
support rule; and the third digit of the phase table is the residual.

So the family has what it needs to write the filter object and the twenty-four shears: the scale and `a` and
the support rule and the per-phase normalised weights, each with a measurement behind it.



## The filter is a caller-allocated buffer, and that is what unblocks the shears

I was about to record the shears as blocked on "the filter object belongs to the release and its layout is
unpublished", and the header says otherwise. `Geometry.h` on
`vImageNewResamplingFilterForFunctionUsingBuffer`:

> This function writes the kernel values into a preallocated kernel buffer that you provide. This function
> writes the kernel values into a preallocated kernel buffer that you provide. The kernel buffer should be at
> least the size of the kernel data, which is given by `vImageGetResamplingKernelSize`.

and on the other two:

> `vImageNewResamplingFilter` and `vImageDestroyResamplingFilter` are **merely convenience functions** to
> make the common case of the default resampling filter into a heap allocated buffer easier for you.

So a `ResamplingFilter` is **not an opaque object the port has to invent a peer for**. It is a buffer **the
caller allocates**, whose size `vImageGetResamplingFilterSize` reports, and which the release's own
constructor - `vImageNewResamplingFilterForFunctionUsingBuffer`, at **iOS 5.0**, so present in 6.1.3 - fills
with the kernel's values by evaluating a caller-supplied `y = f(x)`. The kernel function's own signature is
published: `void (*)(const float *xArray, float *yArray, unsigned long count, void *userData)`.

That changes the shears from blocked to measurable. A caller's filter is a buffer of kernel values the
release wrote, and what the port needs to read it is **the arrangement of those values in the buffer** -
which is a host measurement, not a reverse-engineering project: construct a filter of a known scale on the
host, dump the buffer, and the arrangement is the pattern in the bytes. `vImageGetResamplingFilterSize(scale,
flags)` gives the length to expect, so the measurement is self-checking: the bytes that vary with the scale
are the kernel, and the ones that do not are the header.

It also means the kernel the port evaluates and the kernel the release evaluated are the *same function* -
whatever `sinc(x)*sinc(x/3)` is doing, the release evaluated it and wrote the result down - so the port does
not have to reproduce the release's arithmetic to agree with it. It has to read the numbers the release
wrote. That is a much smaller and more robust thing to get right, and it is why the residual in the phase
table stops mattering: the port can take the weights from the filter rather than compute them.

So the shears' engine is: take the filter's buffer, read its scale and its per-phase weights, and resample
with them; and the one measurement left is the buffer's arrangement. The twenty-four functions the corpus
wants for the four shear spellings and the eleven pixel types, and the one `vImageGetResamplingFilterExtent`
that has to read the same buffer, all follow from it.

## The shear's mapping, read off a PlanarF grid - and the half pixel

A horizontal shear has **no cross-axis term**: every destination row reads the *same* source row, and the row
index only shifts the x offset. That is the correction, and it is right - what I had written multiplied the
slope into a row index, which is not a shear at all.

A source carrying `row * 1000 + column` in each value, so a destination pixel's answer names the source row
and column it read, over an 8x4 with a scale-1 filter and `kvImageBackgroundColorFill`:

| case | the destination row 0 reads |
| --- | --- |
| slope 0, translate 0 | `--  0,1  0,2  0,3  0,4  0,5  0,6  0,7` |
| slope 0, translate 1 | `--  --  0,1  0,2  0,3  0,4  0,5  0,6` |
| slope 0, translate -1 | `0,1  0,2  0,3  0,4  0,5  0,6  0,7  --` |

So **a positive translate pulls the source left**, `sx = dx - xTranslate`, the same direction the affine's
`tx` pulls left and the opposite of the reading a caller might expect from the name.

**The half pixel is NOT there, and the last commit's claim about it was an artefact of this probe.** With the
`+ 1` in the value - so that no source value is zero and a genuine read of source column 0 cannot be mistaken
for the backColor - a slope of 0 and a translate of 0 reads

    dy=0   0,0  0,1  0,2  0,3  0,4  0,5  0,6  0,7
    dy=1   1,0  1,1  1,2  1,3  1,4  1,5  1,6  1,7

with **no backColor anywhere**, so the mapped position of `dx = 0` is the source's first column and not half a
pixel to its left. The `--` this probe printed at that pixel before was the source value 0 being read and
scored as background. `sx = dx - xTranslate`, `sy = dy`, and the suggested form's `+ 1/2 ... - 1/2` is not what
the system does - which is worth having measured, because the form is a plausible thing to have implemented
and it would be wrong on every pixel of every shear.

**The slope term is not read off, and the reason is a flaw in this probe, not in the system.** The probe
writes a source value of `0` for row 0 column 0 and prints anything at or below 0.6 as `--`, so a genuine
read of source column 0 is indistinguishable from the backColor. Every row above is a case where the values
involved are large enough to be unambiguous, and the slope rows are full of 0s and near-0s and are therefore
**not trustworthy as they stand**. One rerun with the value `row * 1000 + column + 1`, so no source value is
zero, reads the slope term off: with slope 1 the destination column's source column is offset by a whole
column per row, and the sign and the half pixel follow from the same three cases the table above is read
with.

The vertical shear is the transpose of that, on the same evidence.

## The shears: written, and the differential is red on the edge

Thirty-six functions over four bands - 8 at 7.0, 4 at 8.0, 6 at 10.0, 18 at 15.0 - and
`tests/backports/host/shear` holds the engine against the host's own
`vImageHorizontalShear_PlanarF` and `vImageVerticalShear_PlanarF` over four filter scales, six translates and
both edging modes. PlanarF is the vehicle and not a delivered function: it is in 6.1.3 already and the corpus
does not carry it, so what is compared is the port's engine over a float channel against the system's.

**Red, and the failures are one case.** They are all the **first sample of a row where the kernel overhangs
the left edge**, and all of them differ by exactly the gap between the backColor and the source value - 2.25
on a channel whose range is −2 to +2 with a backColor of 0.25 - which is the signature of the port writing
the backColor where the system writes a source pixel.

An earlier version of the loop discarded the whole sample the moment any tap fell outside the source. That
is wrong, and the system says so: at an integer mapped position the out-of-range lobes of a Lanczos kernel
are *exactly zero*, so the destination's first column is the source's first column. The loop now skips an
out-of-range tap and keeps the inside ones, and takes the backColor only when **no** tap is inside. That is
the correct rule and it is what the header's "the edge pixels of the source are extended" describes for
`kvImageEdgeExtend`, where the tap is pulled back to the edge pixel instead of dropped.

The remaining failures are the same case in a different guise, and the loop as committed still gets it wrong
for at least the destination-wider-than-source and downscale cases. One defect, named: the interaction of
`first = base - extent` with a destination that is wider than the source, where the kernel runs off the
**right** edge and the sample is taken from taps that are all inside but sum to less than one - and the
system renormalises over the inside taps where this port does not. That is the measurement the next run
settles: a source narrower than the destination, and the weights of the surviving taps divided by their sum.

**The 36 registry entries are NOT in the delivery.** While the differential is red, `status: implemented`
would be the fake the brief forbids, so `ios7-15-shear.json` is removed: the functions are in the tree as the
engine the remaining work is one rewrite deep, and nothing claims them. They come back with their entries when
the differential is green.

**The tap walk is now the diagonal one** - `(x + k, dy + shearSlope * k)` - and the slope is no longer
refused. That is the rewrite the characterisation called for, and it is why the run's remaining failures
moved from whole-sample differences to fractional ones concentrated at the bottom rows, where the diagonal
runs off the picture and the two answers disagree about which taps to drop. The next thing to settle is that
edge: the system at a steep slope and a destination near the last row blends the *last* row repeatedly where
this port drops the taps that fall past it.

## The slope term is a DIAGONAL resample, and that is the whole of it

A source ramped on **both** axes - every value is `row * 1000 + column + 1` - so every whole-pixel answer
names the `(row, column)` it read. Over a 9x6 picture into 9x6, a scale-1 filter and
`kvImageBackgroundColorFill`:

- **every whole-pixel answer reads the source row that equals the destination row.** At a slope of 1, of 2, of
  0.5 and of -1, the row named is `dy` in every case where the answer is a whole pixel. So the
  "cross-axis term" is not in the mapping - your correction was right about that, and the cross-row values
  are the *kernel* reaching across rows, not the mapping moving.
- **the column the whole-pixel answers name is irregular in the row.** At a slope of 1 the offsets read 5, 3,
  3, 2, 1, 0 down the six rows; at a slope of 2 they are larger and the top rows are entirely backColor; at
  0.5 they are 1, 1, 1, 1, 1, 1 with a blend at the left. A constant step per row would be 1, 2, 3, 4, 5 and
  it is not that.
- **between the whole-pixel answers the values are blends of two rows** - an answer near 500 is half of a
  row-1 value and half of a row-0 value, one near 300 of a row-2 and a row-3. So the kernel reads along a
  **diagonal**: a tap one step along the shear is one column across *and* `shearSlope` rows down, so at a
  slope of 1 the taps of one destination pixel land in three different rows and the sample is a blend of all
  of them.

That is the characterisation, and it is a different engine from the one committed: a shear is a one-
dimensional resample **along the direction of the shear**, with the taps at
`(x + k, dy + shearSlope * k)` rather than along a row. The slope-0 case the port ships is that engine with
the slope zero, where the taps stay in the row - which is why it is exact there and why the whole-pixel answers
at a non-zero slope are irregular: the port's row-taps are not the system's diagonal taps.

So the three items are: the left edge and the renormalisation over the surviving taps, both one-dimensional and
both in the committed loop, and the slope, which needs the tap walk to become `(x + k, dy + slope * k)`. The
first two are arithmetic in what is committed; the third is the loop's tap geometry.

## The bottom edge: the system reads past the picture, and that is the blocker

Every source **row** carrying one constant, `row * 1000 + 1`, so an answer reads back as
`1000 * (the weighted mean row the taps landed on) + 1`, and with the weights summing to one the mean row
names exactly which rows the kernel read. A 9x6 picture, a scale-1 filter, `kvImageBackgroundColorFill`, at a
slope of 1, the mean source row at each destination column:

    dy=0   --  --  -- -0.000  -- -0.000  0.000 -0.000 -0.000
    dy=1   --  --  0.024  --  0.500  1.111  0.976  1.000  1.000
    dy=2   --  0.048  --  1.000  2.223  1.951  2.000  2.000  2.000
    dy=3   0.073  --  1.500  3.334  2.927  3.000  3.000  3.000  3.000
    dy=4   --  2.000  4.446  3.902  4.000  4.000  4.000  4.000  3.902
    dy=5   2.500  5.557  4.878  5.000  5.000  5.000  5.000  4.878  5.557

The last row is the answer. Its mean row is **5.557** at two columns and **4.878** at two more - and a mean row
*greater* than 5 cannot come from rows 0 to 5, whatever the weights are, because the largest value in the
source is 5001. `0.557` is `(1 - 0.443) * 6 + 0.443 * 5`, so a tap read **row 6**, which does not exist. The
same holds at a slope of 2, where `dy=5` reads a mean of 5.000 at every column but the top rows are entirely
backColor, and at a slope of -1 the mirror at the top.

So the system does **not** drop, clamp or back-colour a diagonal tap that leaves the picture along the shear: it
reads it. That answers the three-way question, and it is a blocker rather than a rule, because the tap's address
is outside the caller's `vImage_Buffer`. A port that reproduced the answers would have to read past the buffer
the caller handed it - which is a wild read dressed as a conversion, and the one thing this family has refused
four times now. The three candidates are therefore all wrong, and the fourth possibility - that the system
reads past because the caller's buffer happened to have more behind it - is not something a port may rely on.

**What follows.** The shears are right where the diagonal stays inside the picture, which is most of a shear and
all of every slope-0 case the port ships. At the edge they are not, and the honest answer there is to refuse the
call rather than to read past the caller's buffer - which is a narrower refusal than the one the last two
commits carried, because it is only the picture's last few rows or columns at a non-zero slope. The
`kvImageBackgroundColorFill` mode is where it shows, because that is the mode whose name promises the edge is
filled rather than read.

So: the 36 functions stay **out** of the registry, and what is left is one decision - refuse the edge, or
reproduce a wild read - and a coordinator's ruling on which. Everything upstream of it is measured and written.

## The guard page settles what the system is doing, and the documented edging does not fit

**The proof, first.** The picture's last row placed flush against a `PROT_NONE` guard page - two pages mapped,
the second protected, the six rows of a 9x6 picture ending exactly at the boundary - and the system's own
`vImageHorizontalShear_PlanarF` run at the edge, under `SIGSEGV`/`SIGBUS` handlers that catch a read:

    slope 0  no fault, the largest value written is 5001
    slope 1  no fault, the largest value written is 5558
    slope 2  no fault, the largest value written is 5001
    slope 3  no fault, the largest value written is 5558

**No fault at any slope**, so the system reads nothing outside the allocation: it is not an out-of-bounds
read, and my harness was not under-allocating. And it writes **5558** where the largest value in a six-row
source is 5001 - a value **no convex combination of the source can produce**, so the weights it uses at the
edge do not sum to one.

What does produce it is **clamping the out-of-picture tap to the edge row and not renormalising over the
survivors**, so the edge row is counted twice. And that is the header's own `kvImageEdgeExtend` - the ruling's
step 2, implemented.

**And it does not fit, which is the result worth having.** With the clamp applied at both edges, the
*diagonal* cases match the system's fingerprint and the *in-row* cases break: at a translate of 1 the first
column now differs by 3.83, and a translate of -1 by 3.83 again, where the system plainly drops the
out-of-range taps - at a whole-pixel phase their Lanczos lobes are exactly zero, so the destination's first
column **is** the source's first column, and the port's earlier measurement said so over an 8x4 grid. The run
goes to a worst difference of 3.8 on cases that were exact before the change.

So the two edges are **not the same rule**: along the row the system drops the out-of-range taps, and along
the shear direction it clamps them without renormalising. The header documents one of those behaviours and
names one flag for it, and the system does the other thing as well. That is the state:

- the shears are exact for slope 0, in the whole picture, and that is the path the port ships;
- the diagonal edge is characterised down to the fingerprint that distinguishes clamping from dropping, and
  the port implements dropping, which is what the in-row edge measures;
- the 36 registry entries stay **out**, because the diagonal edge is not yet matched.

What is left is to find which taps the system clamps and which it drops - the two rules cannot both be right
and one measurement separates them: a picture where the *last* row is a ramp and the *first* column is a
constant, so the row edge and the column edge have different values and a single destination pixel's answer
says which was treated how.

## Both edges CLAMP: the two-edge grid derives the rule

A source whose **interior** is a known ramp in both axes, whose **first column** carries `9000 + row*1000`
and whose **last row** carries `50000 + column` - both wildly unlike their neighbours, so a destination
pixel near one edge and far from the other says which rule was applied to it. Measured over slopes 0 to 3 and
translates of +0.5 and −0.5, and the answer is the same at every slope:

- **a left-edge destination pixel reads column 0's own value.** At a slope of 0 and a translate of 0.5, row 0
  column 0 answers **5491.0**, and the measured half-pixel weights predict `0.61141 * 9000 + 0.02446 * 101 =
  5501.5` - the edge element read at both the centre and the clamped neighbour. At a slope of 1 the same pixel
  answers **9000.0** exactly, column 0's value.
- **a bottom-edge destination pixel reads the last row's own value**, and the answer **overshoots the source
  maximum**: at a slope of 0, row 5 column 8 answers **55579.2** where that row is `50008`. No convex
  combination of a source topping out at 50008 produces it; the edge row read at both the centre and the
  clamped neighbour does.

**So both edges clamp, and neither drops.** It is one rule, not two: a tap outside the picture lands on the
edge element with its weight intact, and the weights are **not** renormalised over the survivors - which is
the header's own `kvImageEdgeExtend`, and the only rule consistent with the guard-page result that the system
reads nothing outside the caller's buffer.

**What is left, and it is one question.** A clamp-everywhere run breaks the **in-row** cases at a translate of
+1 and -1 by about 3.8, where the system plainly does something else: the *centre* tap is outside the picture
there, and a clamped centre is not the same as a clamped flank. The question the grid still has to answer is
whether a tap whose **own position** is outside the picture is clamped like any other, or dropped while only
the ones past it are clamped. One case separates them: a destination pixel whose centre is half a pixel left
of the source, where clamping the centre reads column 0 with the full centre weight and dropping it does not.

## The centre: DROPPED, and the position is not clamped either

A destination pixel whose centre sits half a pixel **left** of the source - a translate of -0.5 with a scale-1
filter, the same two-edge source, and both candidates compared against the measured value:

| case | measured | clamped centre | dropped centre |
| --- | --- | --- | --- |
| slope 0, translate −0.5, row 0 | 5553.2 | 9000.0 | 220.1 |
| slope 1, translate −0.5, row 0 | −1.0 (the backColor) | 9000.0 | 220.1 |
| slope 0, translate −1, row 0 | **101.0** | 9000.0 | 220.1 |

**Neither, and the third row says why.** At a translate of −1 the destination's first column answers
**101.0**, which is `value_at(0, 1)` — the source's *second* column. So the mapping is

    sx = dx - xTranslate

with **no clamping of the position**: `dx = 0` and a translate of −1 name the source's column 1, not column 0.
And a tap outside the picture is **dropped**, not clamped — at a translate of +0.5 the first column answers
5491.0, which is one weight of 0.61141 times column 0's 9000 with nothing added, where a clamped neighbour
would have added its 0.02446 of the same 9000 and given 5723.

So the rule along the row is the one this port already implements: `sx = dx - xTranslate`, out-of-picture taps
dropped, and `kvImageBackgroundColorFill` back-colouring a sample whose whole kernel is outside - which is
what a slope of 1 and a translate of −0.5 answers at row 0, the backColor.

**So the clamp-everywhere run was wrong on both edges, and the two-edge grid's "clamped" reading was
over-interpreted**: a left-edge destination pixel reading column 0's value is what *dropping* produces at a
whole-pixel phase too, because the out-of-range lobes are exactly zero there and the surviving centre tap is
column 0. The grid separated the two at a *half*-pixel phase - where the system gave 5491, one weight of
column 0 and nothing else - and that is the line that settles it.

**What the 5558 still is.** The bottom-edge overshoot is real and still unexplained by any rule here: at a
slope of 0, row 5 column 8 answers 55579.2 where that row is 50008, and the guard page says the value came
from inside the allocation. With the row's taps now known to be *dropped*, the remaining candidate is that the
diagonal walk at a slope of 1 re-reads the last row more than the tap count implies - the overshoot's
signature, a value above the source maximum, is a row counted twice. The one case that separates "the last
row's taps are read once" from "the last row is repeated to fill the walk" is a slope of 1 with a **tall**
source, where the walk never runs out: if the answer is the exact source value at a whole-pixel phase, the walk
is read once, and if it is anything else the last row is repeated.

## The tall source rules out "the walk is filled by repeating the last row" - and the two edges are two rules

A slope of 1 over sources **tall enough that the diagonal walk never runs out of rows inside the kernel** -
9x12 and 9x20, the same two-edge source, whole-pixel answers counted by matching them against a value the
source actually holds:

    9x12  slope 1  translate 0    3 whole-pixel answers, 2 above the source's maximum, 103 other
    9x12  slope 0  translate 0  108 whole-pixel answers, 0 above the source's maximum,   0 other
    9x20  slope 1  translate 0    6 whole-pixel answers, 2 above the source's maximum, 172 other
    9x20  slope 1  translate 0.5 36 whole-pixel answers, 0 above the source's maximum, 144 other
    9x6   slope 1  translate 0    2 whole-pixel answers, 2 above the source's maximum,  50 other

**A tall source still has the two overshooting answers**, so the walk is not being filled by repeating the
last row, and the cause is not running out of rows. The overshooting cells are all in the *last row*, whose
values are the 50000s: at 9x6 the row is `dy=5  ... 33560.3 53670.0 49122.1 50003.5 50004.5 50005.5 48783.4
55579.2`, and 55579.2 is 0.61141 of 50008 plus 0.5 of 50008 - **the last row read twice, with total weight
1.111**, which is a clamped tap whose weight was not renormalised away.

So the two edges really are two rules, and which is which is settled by the half-pixel cases rather than the
whole-pixel ones:

- **along the row**, where the diagonal does not move, an out-of-picture tap is **DROPPED** - a translate of
  +0.5's first column answers 5491.0, one weight of column 0 and nothing else, and a translate of -1's first
  column answers 101.0, which is the source's *second* column, so the position is `dx - xTranslate` with no
  clamping of its own.
- **along the shear**, where the taps step down a row each, a tap past the last row is **CLAMPED to it with
  its weight intact and no renormalisation** - the 5558 and 55579.2 fingerprints, which no convex combination
  of the source produces and which the guard page shows came from inside the caller's allocation.

**That is what the port has to implement, and it does not yet.** The committed engine drops at both edges, so
its bottom-edge cells differ from the system's by exactly the overshoot, and its in-row cells are already
right - which is the shape the coordinator described: differences only in the bottom-edge cells at a non-zero
slope, and a bug anywhere else.

The port's `RevenantShearRun` needs one change: when a tap's **row** is outside the picture, clamp it to the
edge row and keep its weight; when its **column** is outside, drop it as now. That is a two-line difference
in the tap loop and it is the whole of the remaining work on this family.

## The two-rule change is in, and the failures are NOT the bottom edge

`RevenantShearRun`'s tap loop now drops a tap whose **column** is outside and clamps a tap whose **row** is
outside, with its weight intact. The shear differential over 212 cases:

    212 checks, 101 failures, the widest sample difference 3.96584 of a 0..1 channel

and the failures are **in the in-row cases at a whole-pixel translate**, not at the bottom edge:

    translate 0   34 failures      translate -0.5   2
    translate 1   34 failures      translate 0.5    2
    translate -1  29 failures      translate 2.5    0

with the differences at **row 0 and row 1 of every case** and a magnitude of 2 to 3.8 on a channel whose
range is -2 to +2 - which is the whole channel, not a rounding. So the position and tap handling at a
non-zero translate is wrong, the same place it was before this change, and the bottom edge is now *cleaner*
rather than being the only thing left.

**Concretely, what the two disagree about.** At a translate of +1 the system answers the **backColor** for the
first two destination columns, while the port answers source pixels there: the port puts the mapped position
at `dx - xTranslate`, finds the taps for columns 1 and 2 inside the picture and uses them, and the system
treats a sample whose kernel reaches left of the picture as wholly outside. At a translate of +0.5, by
contrast, the system answered 5491.0 - one weight of column 0 and nothing else - so it does not wholly
back-colour there. Those two cannot both come from one rule, and the half-pixel case that separates them is
the same `dx - xTranslate` the port already has.

So the remaining difference is the **in-row** position rule at a whole-pixel translate, not the shear
direction and not the bottom edge, and it is a bug in the committed engine rather than a divergence to pin.

## The constant-source table: the in-row rule is the BACKCOLOR, not a drop

A source constant at 1.0, a backColor of -1, a scale-1 filter, slope 0, over a nine-wide picture - so the
answer reads the applied weight sum directly, `2w - 1`, and no reasoning about the kernel is needed:

| translate | dx=0 | dx=6 | dx=7 | dx=8 |
| --- | --- | --- | --- | --- |
| -2.0 | 1.000 | 1.000 | **-1.000** | **-1.000** |
| -1.5 | 0.951 | 0.951 | **-0.000** | **-1.223** |
| -1.0 | 1.000 | 1.000 | 1.000 | **-1.000** |
| -0.5 | **1.223** | 1.000 | 0.951 | 1.223 |
| 0.0 | 1.000 | 1.000 | 1.000 | 1.000 |

`-0.000` and `1.223` are **weights**, not dropped taps: a substituted backColor with a negative Lanczos
lobe and one with a positive overshoot. So an out-of-picture tap is **replaced by the backColor, keeping its
weight** - which is `kvImageBackgroundColorFill` read literally, and is not a drop at all. At a whole-pixel
phase the out-of-range lobes are exactly zero, so dropping and substituting are indistinguishable there, and
that is why a whole-pixel grid read as "dropped" and misled this twice.

Implemented, and the differential is still red:

    212 checks, 100 failures, the widest sample difference 5.8997e+35 of a 0..1 channel
    FAIL vShear 9x5 into 9x5 translate 0 scale 1 flags 0x4: row 1 sample 5 differs by 2

**And the remaining failure is the IDENTITY** - slope 0, a translate of 0, a scale of 1, where the
destination must be a byte-for-byte copy of the source and no resampling happens at all. A difference of 2 on
a channel whose range is -2 to +2 is the whole channel, so the engine is wrong where it has nothing to
resample. That is a bug in the committed tap loop and not a divergence to pin, and it is the next thing to
find. The 36 registry entries stay **out**.

## ASan on the identity: silent, and the identity is off by one ROW

An AddressSanitizer and UndefinedBehaviorSanitizer build of the **horizontal** identity case alone -
`RevenantShearRun(..., RevenantPlanarF, /*horizontal*/ YES, 0.0, 0.0, 0, 0, backColor, kvImageBackgroundColorFill)`
over a 9x5 `PlanarF` buffer, `clang -g -O0 -fsanitize=address,undefined -fno-omit-frame-pointer`
(`.agent-work/runs/asan/ident.m`) - is **silent on both**, and answers:

    err 0
      -2.0000  -0.0870   1.8261  -0.2609   1.6522  -0.4348   1.4783  -0.6087   1.3043
       0.4348  -1.6522   0.2609  -1.8261   0.0870  -2.0000  -0.0870   1.8261  -1.2609
      -1.1304   0.7826  -1.3043   0.6087  -1.4783   0.4348  -1.6522   0.2609  -1.8261
       1.3043  -0.7826   1.1304  -0.9565   0.9565  -1.1304   0.7826  -1.3043   0.6087
      -0.2609   1.6522  -0.4348   1.4783  -0.6087   1.3043  -0.7826   1.1304  -0.9565

which is the source **shifted down by one row** - destination row 0 is the source's row 1, and the last row
wraps - with every sample of a row exact. So there is no out-of-bounds access on this path at all, the
`1e19` differences the differential reports on the *horizontal* cases come from somewhere else in the run,
and the identity's own defect is a **one-row off-by-one in the row mapping**, visible here without any
instrument: `row = cross0 + cross + slope * k` reads one row further down than `out = dest->data +
cross * dest->rowBytes` writes.

The coordinator's ASan trace - `RevenantShear.h:225`, `row` clamped to `srcCross - 1` where `srcCross` is the
*width* for the vertical shear and so used as a row index - is the **vertical** one and remains real. The two
axes are separate defects and the horizontal one is a mapping, not a memory error.

## The axis sign, the edging flag, and the scale read off exact values

Two more defects, both verified on the coordinator's copy and both confirmed here:

- **The sign follows the axis.** `centre = (along0 + along + (horizontal ? -translate : translate)) / scale`.
  The horizontal shear's translate pulls the source left and the vertical's pushes it the other way, each
  read off a grid whose pixel values are their own coordinates (`probe-sign.m`).
- **`kvImageEdgeExtend` was computed and never read.** Every out-of-range tap took the backColor, so every
  edging-mode case was answered as `kvImageBackgroundColorFill`. With the flag the tap is pulled back to
  the edge and keeps its weight, which is the header's own "the edge pixels of the source are extended".

With both in: **212 checks, 75 failures**, and **every one of them at a scale other than 1** - all the
scale-1 cases pass, which is the first time that has been true.

**The scale, measured with exact values** (`probe-scale.m`: a one-row picture whose column `c` carries
`c + 1`, so the answer is a weighted mean of the source columns and the host's and the port's sit side by
side):

    scale 1     host 1.0000 2.0000 3.0000 ... 12.0000    port the same, exactly
    scale 2     host 0.5062 1.3635 1.8378 2.2001 2.7624 3.2302 3.7698 4.2302 ...
                port 1.0000 2.0000 3.0000 4.0000 5.0000 6.0000 7.0000 8.0000 ...

At a scale of 1 the two agree exactly. At a scale of 2 the **host resamples between the source columns** -
its consecutive differences are 0.857, 0.474, 0.362, 0.562, 0.468, 0.540, irregular, so the position does
not step uniformly - while **the port samples exact columns**, 1.0, 2.0, 3.0, which is what `x / scale`
gives. And the host's value at `x = 0` is **0.5062**, below the source's first value of 1.0, so its mapped
position for the first destination pixel is *before* the source's first column and part of its kernel is
being answered with the backColor of −1. That is the half-pixel the coordinator pointed at:
`(x + 0.5) / scale - 0.5`, which at `x = 0` and a scale of 2 is **−0.25**, and the position the two
candidates print for `x = 0` are `0.000` and `−0.250` respectively.

So the port's position is wrong by the half pixel, and the irregular differences say the mapped position is
not even a constant step of 1/scale once the kernel is taken into account. What the next run has to pin is
the *exact* position per destination pixel - solvable from this grid, since the source values are their own
indices and the answer is a weighted mean of the columns the kernel covers - and then the extent the filter
carries at a scale other than one, which the table in `RevenantResampling.h` fixes as
`ceil(lobes / min(1, scale))` on the strength of the *extent* measurement and has never been checked
against a resample.


## The half pixel and the stretched kernel: minification matches to the digit

The coordinator's two rules, applied and measured:

- **the pixel-centre position**, `centre = ((along0 + along + 0.5) ± translate) / scale - 0.5`;
- **the kernel stretches when minifying** - at a scale below one the weight at a tap is
  `sinc(x) * sinc(x / lobes)` at `x = (tap - centre) * scale`, over `ceil(lobes / scale)` taps, normalised;
  at or above one it is the plain kernel over the lobes.

At a **scale of 0.5 the port now answers `1.3717` where the host answers `1.3717`** - the same four
decimals, from a grid where the source's own indices are its values. The stretched kernel and the half
pixel are therefore both right, and the eight-bit-vs-half-float question does not arise.

    212 checks, 51 failures, the widest sample difference 3.38196
    12 at a scale of 0.25, 12 at 0.5, 24 at 2, and 3 slope cases
    AddressSanitizer 0 reports, UndefinedBehaviorSanitizer 0 reports

So the scale-1 cases and the scale-2 cases are closed, and what is left is **24 cases at a scale of 2 - pure
magnification, where the kernel does NOT stretch - plus 24 minification cases at 0.25 and 0.5 that the
scale-0.5 grid says are right, so those are failing on something the one-row grid cannot show: a picture
that is one row has no `cross` extent for the diagonal walk, and the 0.5 cases in the differential are
9x5.**

The magnification grid is the open measurement and it is small: at a scale of 2 the host answers `0.5062,
1.3635, 1.8378, 2.2001, 2.7624, 3.2302, 3.7698, 4.2302, 4.7698, 5.2302, 5.7698, 6.2302` where the port answers
`1.0000, 2.0000, 3.0000, ...` - the port is sampling exact columns and the host is not. At a scale of 2 the
extent from the table is 3, the same as at a scale of 1, so the kernel is the plain one; what is missing is
the *phase* the host uses for a magnified grid, and the host's first value of 0.5062 - below the source's
first value of 1.0 - says its position for `x = 0` is before the source's first column with part of the
kernel answered by the backColor of -1.

Solving it needs one more run of `probe-scale.m` with the source made **taller than one row** so the
diagonal walk has a `cross` extent, at a scale of 2, printing the exact values: that separates a magnified
*phase* from a magnified *position* in one grid, and it is the last measurement the family needs.

## The multi-row grid: the scale cases are exact, and the slope is not sheared at all

A 5x5 picture whose row `r` is the constant `r + 1` and whose column `c` carries `0.01c`, so a horizontal
answer separates which row was read from which column, with a backColor of -9 so the back-coloured
destinations are unmistakable. The host's five rows and the port's five rows, side by side
(`probe-multirow.m`):

    scale 0.5  host  0.280  2.001 -4.017 -9.822 -8.812   port  0.280  2.001 -4.017 -9.822 -8.812
              ... and the same for all four remaining rows
    scale 2    host -1.105  2.033  1.613  0.711  0.944   port -1.105  2.033  1.613  0.711  0.944
              ... and the same for all four remaining rows

**Exact, every value, at both scales and on a picture that has the cross extent the one-row grid lacked.**
So the scale handling is finished: the divisor is the filter's own scale, the position carries the half
pixel, the kernel stretches when minifying, and the two edging modes are each honoured.

**And the slope is not sheared at all in the port.** A scale of 1 and a slope of 1:

    host  -9.000 -9.000 -8.755 -10.114 -4.001     port  1.000 1.010 1.020 1.030 1.040
    host  -9.000 -8.731 -10.225 -3.501  3.230     port  2.000 2.010 2.020 2.030 2.040
    host  -8.707 -10.337 -3.001  4.341  2.722     port  3.000 3.010 3.020 3.030 3.040
    host -10.448 -2.501  5.453  3.697  3.706     port  4.000 4.010 4.020 4.030 4.040
    host  -2.001  6.564  4.673  4.681  6.600     port  5.000 5.010 5.020 5.030 5.040

The port's rows are the source's own rows, unmoved and unsheared - the exact values `r + 1 + 0.01c` - while
the host walks each row's own values across the picture and fills the rest with the backColor of -9. So the
**across term contributes nothing in the port**: `row = sourceCross + floor(slope * (at - centre) + 0.5)` is
coming out as `sourceCross` for every tap, which means `at` equals `centre` for every tap, which means the
tap positions and the centre are the same value - and the only way that happens with
`at = first + k` and `centre` a separate value is that the *weights* and the positions disagree about which
tap is which.

That is a localised defect in the across term, it is the last one the family has, and the 36 registry
entries stay **out** until the differential is green.


## The slope is a shift of the ALONG position, not a walk of the taps

The coordinator is right and the committed model was wrong: in a vImage horizontal shear **the row stays the
row** - a destination row reads its own source row - and what moves is the position *along* that row, by
`slope` times the destination row. The multi-row grid shows it directly: at a slope of 1 the port answered
the source's own rows, unmoved, while the host walked each row's values across the picture and filled the
rest with the backColor, which is a per-row diagonal shift and not a per-tap one.

So the model is now

    row           = sourceCross
    centre_along  = ((along0 + along + 0.5) ± translate ∓ slope * (cross0 + cross + 0.5)) / scale - 0.5

with the half pixel in the cross coordinate, because a row is sampled at its centre, and the vertical the
transpose. The compiler caught a real slip on the way in - a local `along` shadowing the loop's own, which
made the expression read itself and sent the run to 106 failures - and the name is fixed.

**The sign and the half pixel are not yet confirmed.** The run is at **212 checks, 39 failures** - 12 at a
scale of 0.25, 12 at 0.5, 12 at 2, and the 3 slope cases - which is the same count the per-tap model gave, so
one of the sign, the `+ 0.5` and the `∓` is wrong and the differential cannot say which.

The grid meant to settle it (`probe-slopemodel.m`, a source of five rows where row `r` carries `100 + r` and
column `c` carries `0.01c`) came out **too noisy to read**: the answers are blends of several columns and
the backColor of -9, and a blend like -23.0 or 6.0 does not name the column it came from. What it *does*
show cleanly is the per-row diagonal and its direction - at a slope of 1 the data sits further right on the
lower rows, and at a slope of -0.5 the other way - and that `srcOffsetToROI_Y` of 2 on a five-row picture
answers a uniform 0 on every cell, so the offset shifts which source row a destination row names and is
**not** clamped to the picture.

The fix for the measurement is the one the kernel sweep already used: a source that is a **delta per
column**, one column at a time, so every destination answer is that column's weight and nothing is a
blend. That grid gives the sign, the `+ 0.5` and the offset's reference in one run, and it is the last
measurement the family needs.


## The 36 non-slope failures, tabulated: every one is the VERTICAL shear, and only off a scale of one

The coordinator asked for the parameters of the 36 that are not slope cases, in one table. Sorted, with
`srcOffsetToROI_X` and `_Y` both 0 in every one of them and the destination the same 9x5 as the source:

    vShear 9x5 into 9x5 translate -0.5 scale 0.25 flags 0x4      vShear 9x5 into 9x5 translate -0.5 scale 0.25 flags 0x8
    vShear 9x5 into 9x5 translate -0.5 scale 0.5  flags 0x4      vShear 9x5 into 9x5 translate -0.5 scale 0.5  flags 0x8
    vShear 9x5 into 9x5 translate -0.5 scale 2    flags 0x4      vShear 9x5 into 9x5 translate -0.5 scale 2    flags 0x8
    vShear 9x5 into 9x5 translate 0    scale 0.25 flags 0x4      vShear 9x5 into 9x5 translate 0    scale 0.25 flags 0x8
    ... the same six translates at 0.5 and 2, and nothing else
    (12 at a scale of 0.25, 12 at 0.5, 12 at 2)

**Not one of them is an hShear.** And **none is at a scale of 1** - `vShear 9x5 into 9x5 translate 0
scale 1` passes, and so does every other scale-1 vertical case. So the table says:

- the horizontal shear is exact at **every** scale, both edging modes, every translate - which is what the
  one-row and multi-row grids measured;
- the vertical shear is exact at a **scale of 1** and wrong at 0.25, 0.5 and 2, at **every** translate and in
  **both** edging modes - 36 cases, and the translate and the edging mode are not what they share;
- what they share is the **axis and the scale together**, and the only thing that differs between the axes
  at a scale is which extent the along position divides: for the horizontal the along axis is the source's
  **width** and the picture is 9 wide, and for the vertical it is the source's **height** and the picture is
  5 tall - so at a scale of 2 the vertical's positions run -0.25 to 1.75 over a kernel of extent 3, while
  the horizontal's run -0.25 to 3.75 over the same kernel. The vertical's whole along range fits inside the
  first two source rows and the horizontal's does not, and the grids that came out exact were the
  horizontal ones.

So the vertical's scale is not dividing a position the port computes the same way, and the single question
left is **what the host does when the scaled along range is shorter than the kernel** - a 5-tall source at a
scale of 0.25 has its along positions at 0.125, 2.125, 4.125, 6.125, 8.125 with a kernel of extent 12, so
every tap but one is outside the picture on both sides and the answer is dominated by what the host
substitutes there. That is one delta-per-column sweep on a **five-row** picture at a scale of 0.25, the
vertical axis, and it is the last measurement this family needs.


## The extent is ruled out: the vertical is wrong on BOTH shapes, by 4 and 8

The coordinator's test - a vertical shear at a scale of 2 on a 5x12 source and on a 12x5 one, which shares
everything but the shape (`probe-extent.m`, host and port compared sample for sample):

    vShear  5x12 at a scale of 2:  60 of  60 samples differ, the widest by 8.24359
    vShear 12x5  at a scale of 2:  60 of  60 samples differ, the widest by 4.34259
    hShear  5x12 at a scale of 2:  46 of  60 samples differ, the widest by 1.90735e-06
    hShear 12x5  at a scale of 2:  39 of  60 samples differ, the widest by 4.76837e-07

**Not an extent swap.** The vertical is wrong on the 5x12 and on the 12x5 alike, and by a factor of ten
between them - a swap would be right on one of them. And the horizontal's "differences" are `1.9e-06` and
`4.8e-07`, which is **floating-point noise, not a mapping error**: the differential's own tolerance for a
PlanarF case is `4/23` = 0.174, so the horizontal is well inside it and the strict equality in this probe
is what is counting them.

So the axis asymmetry is real and it is not a swap: the horizontal divides the **along** position by the
filter's scale and lands on the host to the last bit at 0.25, 0.5 and 2, and the vertical does not. For a
vertical shear the along axis is the **row**, and a five-row picture at a scale of 2 has its five
destination rows reading source rows -0.25 to 1.75 - two of five rows, with the rest of every kernel
outside. That is the one case the 5x5 and 9x5 grids have not separated: they have both the along extent
small *and* the cross extent equal to the kernel's, so a stretch of the kernel and a stretch of the
position look the same.

What settles it is a vertical shear at a scale of 2 on a picture that is **tall** - twelve rows and five
columns - read as a delta per column, so the row each destination row lands on is unambiguous. If the host's
vertical positions run -0.25 to 5.75 the position is divided as the horizontal's is and the kernel is not
stretched along the row; if they run -0.25 to 11.75 the position is **not** divided and only the kernel
stretches, which is the header's "the support is scaled by 1/scale when downsampling" with the position left
alone. Those two grids are one run apart, and the twelve-row one is the measurement.


## WITHDRAWN: the transpose probe failed its own sanity check

The coordinator asked for a sanity check first, and it **fails**. At a slope of 0, a translate of 0 and a
scale of 1 both sides must be the identity, so `vShear(src)` and `transpose(hShear(transpose(src)))` must
both be `src`. Run exactly that case (`probe-transpose-id.m`):

    host 5x12  slope 0 translate 0 scale 1:  58 of 60 differ, the widest by  2
    host 12x5  slope 0 translate 0 scale 1:  55 of 60 differ, the widest by 11
    host 9x5   slope 0 translate 0 scale 1:  40 of 45 differ, the widest by 11

**So the composition in that probe is wrong** - a transposed buffer's `rowBytes`, or the `width` and `height`
of the transposed `vImage_Buffer`, or the offset arguments - and **every "differs by 3.5 to 12.9" in the
previous section is a probe artefact, not the host.** A difference of 11 on a picture whose values are
`100 + r` is what reading the wrong row looks like, and that is what the probe was doing. The conclusion
"the host's vertical is not the transpose of its own horizontal" is withdrawn, and the narrowing of the
cause to "the edge, a limit, or a sign" goes with it, because it rested on the same numbers.

What survives from that turn is only what was measured against a single function rather than a composition:
the horizontal is exact at every scale and both edging modes, and the vertical is exact at a scale of 1 and
wrong at 0.25, 0.5 and 2, in 36 of 212 cases - which is the table, and the table is from the differential
rather than from a probe.

## The host's vertical is NOT the transpose of its own horizontal

The decisive instrument, run on the host itself: transpose the source, run the host's **horizontal** shear on
it, transpose the answer back, and compare with the host's **vertical** shear on the original - same slope,
same translate, same scale, same edging mode, same backColor (`probe-transpose.m`).

    host 5x12  slope 0 translate 0 scale 2   flags 0x4:  60 of 60 differ, the widest by  3.54579
    host 12x5  slope 0 translate 0 scale 2   flags 0x4:  60 of 60 differ, the widest by 11.5986
    host 9x5   slope 0 translate 0 scale 2   flags 0x4:  45 of 45 differ, the widest by 12.0342
    host 9x5   slope 0 translate 0 scale 0.5 flags 0x4:  45 of 45 differ, the widest by 11.3884
    host 9x5   slope 1 translate 0 scale 1   flags 0x4:  39 of 45 differ, the widest by 12.8863

**Every cell, on every case, by 3.5 to 12.9.** So the two axes are not the same function with the axes
swapped, the transpose composition is not available as a shortcut, and the port's vertical needs its own
measurement rather than a swap of the horizontal's. That is worth having ruled out with one run: it is the
answer I would otherwise have spent the next several turns assuming.

**And the last case is the sharpest one: at a SLOPE of 1 and a scale of 1 - where the position division is
the identity and the kernel does not stretch - the two differ in 39 of 45 cells.** So the axes part company
even where no scaling is involved at all, which means the difference is **not** in the position and **not**
in the kernel: it is in the **edge**, or in which extent a limit is taken against, or in the sign of one of
the three terms. The horizontal is exact in that case and the vertical is not, and the two are the host's
own.

So the three candidates the transpose test leaves, and each is one run: read a delta per ROW of a five-row
picture with the vertical at a slope of 1 and a scale of 1, and the destination row's weight names the
source row it read - which separates a sign from a limit from an edge in one grid. That is where this family
stands, and it is a smaller question than the one this turn started with.

searched: **stb_image_resize** (MIT/Apache-2.0) for the Lanczos3 filter, and **nothing reused**.
`stbir__lanczos` is `sinc(x) * sinc(x / 3)` with the weights normalised per phase, which is what
`RevenantResampling.h` computes and what the host's own weights match to five decimal places — the phase-0.5
set `+0.02446, -0.13587, +0.61141, +0.61141, -0.13587, +0.02446` is that kernel's, and the extent rule
`ceil(lobes / min(1, scale))` is the support stb uses. It is not reusable here: stb_image_resize is integer
throughout, has **no alpha channel**, no planar or interleaved-chroma layouts, and **no edging mode at all** —
and the edging is the thing this family had to get right, since the host substitutes the backColor with the
weight intact and does not renormalise over the survivors, which is exactly the case stb does not have. It is
also a whole-image resampler with no shear, rotate or affine transform, so 87 of this family's functions
have no counterpart in it. There is no code from stb_image_resize in this package.

**This delivery's rows, counted on its own base `4d2e24e7`: 5.** They are the five quarter turns of
`ios7-15-rotate90.json` - `vImageRotate90_ARGB16U` and `vImageRotate90_ARGB16S` at 7.0, and
`vImageRotate90_ARGB16F`, `vImageRotate90_CbCr16F` and `vImageRotate90_Planar16F` at 15.0 - held to the
system over 656 checks. The **thirty-six shears are not delivered**: the horizontal is exact and the vertical
is not, an object with no registry entry is kept in every band from 4.3, and `status: implemented` on a
function its own differential rejects is not a thing this package ships. Their source is on the
`vimage-shear-wip` branch, where the vertical is 39 of 212 and its mapping is characterised down to one
half-pixel sign.

## The two axes are mirrors, and both position rules are measured (2026-10-03)

The instrument that settled this is the delta sweep: a source with exactly one row (vertical) or one column
(horizontal) carrying 1.0 and a backColor of 0, so a destination sample's value IS the weight the kernel gave
that row, and a search over `RevenantResampleWeights`' own output reads the mapped position off the kernel to
four decimals. The residual of that search is at rounding size in every case below, so the position is read
off the kernel rather than inferred from the destination's index.

    horizontal:  alongPosition = along0 + along + 0.5 - translate + slope * (cross - dstCross + 0.5)
                  centre        = alongPosition / scale - 0.5
    vertical:    alongPosition = along0 + along + 0.5 + translate + slope * (cross + 0.5)
                  centre        = dstAlong + (alongPosition - dstAlong) / scale - 0.5

**The vertical's scale is anchored to the DESTINATION's far edge and the horizontal's to its near edge.** At a
scale of two on a twelve-row source the vertical's destination row 0 maps to source row 5.7500 and the
horizontal's destination column 0 to source column -0.2500, and the offset is exactly
`dstAlong * (1 - 1/scale)` on one axis and zero on the other. The offset is the DESTINATION's extent and not
the source's: a twelve-row source into a twenty-row destination offsets by ten and not by six, measured over
source and destination extents of (6,6), (12,12), (20,20), (7,20), (12,20), (30,15), (6,3) and (3,6) at scales
of 0.25, 0.5, 1 and 2.

**The slope's cross coordinate is read from the opposite edge on each axis**, which is what makes the two axes
mirrors: the horizontal's amount of shear grows as the distance from the BOTTOM row and the vertical's as the
distance from the LEFT column. Measured over three destination cross extents with the source's held at nine
(7, 5 and 9, at slopes of 1 and 2, residuals at rounding size), and over seven cross coordinates at slopes of
1, 2 and -0.5.

## The kernel is the normalised Lanczos to 1e-6, and the weights are NOT renormalised at an edge

Every tap inside a forty-one-wide source at a scale of one, at phases of 0.125 through 1.0 in steps of an
eighth, compared with `sinc(x)*sinc(x/3)` normalised per phase: the widest **relative** difference over the
whole table is 1.2e-06, which is the float the release stores the weight in and not a different kernel. So the
"per-phase factor" an earlier pass of this page reported is the storage, and the earlier residual in the phase
table is closed.

At an edge the release keeps the weights and does NOT renormalise over the survivors: a source constant at 1.0
with a backColor of -1 answers `2w - 1`, and the answers -0.000 and 1.223 are weights and not gaps. The sum of
the surviving weights is therefore not one - at a phase of 0.5 and an extent of three it is 1.111413 - and that
is the release's own overshoot, which is why the last row of a sheared picture can exceed the source's maximum.

## The refusals, in the order the release makes them

Measured over all thirty-two flag bits for each of the thirty-six, over a NULL buffer, a NULL filter, the
region's two origins against the destination's two extents, and three destination extents on each axis:

    a NULL source or destination        kvImageNullPointerArgument   -21772
    a NULL filter                       kvImageInvalidParameter      -21773
    a region or destination that does not fit ACROSS the shear
                                         kvImageBufferSizeMismatch    -21774
    a flag bit the function does not take  kvImageUnknownFlagsBit      -21775

The order is measured, not assumed: a bad flag beside an across offset of one answers the offset, and a NULL
destination beside a bad flag answers the NULL. The cross extent is the only shape condition, and it is the
sum - `srcOffsetToROI_Y + dest->height > src->height` on the horizontal and the X pair on the vertical - while
the destination's extent ALONG the shear is free and so is the along offset, which a source nine wide accepts
at twelve.

**The flag word is not the same for all of them.** The three half-precision shapes - `ARGB16F`, `CbCr16F` and
`Planar16F` - take seven bits, `0x11bc` = `kvImageBackgroundColorFill | kvImageEdgeExtend | kvImageDoNotTile |
kvImageHighQualityResampling | kvImageGetTempBufferSize | kvImagePrintDiagnosticsToConsole |
kvImageUseFP16Accumulator`, and answer `kvImageUnknownFlagsBit` for the other twenty-five; **every other shape
takes all thirty-two**. An earlier measurement in this family said all thirty-two are accepted, and it was
right - of `vImageHorizontalShear_PlanarF`, which is in 6.1.3 already and is not one of the thirty-six.

## What is still open, and it is one number's worth of arithmetic

`tests/backports/host/shear` holds all thirty-six against the host's own thirty-six, case by case: both axes,
four filter scales, six translates, four slopes, both edging modes, six shapes and two along offsets, with
every byte of every destination row compared - including the padding past the destination's own width - and
with a third answer computed by the harness's own loops from the rules on this page.

**The horizontal is exact on every one of its cases, and the vertical's stored values differ from the
release's by one or two units of the stored type on a large fraction of the rest.** The kernel agrees to 1e-6
relative, the centres agree exactly, and the disagreement is neither the truncation nor the rounding of the sum
- the harness's own sum matches the host's stored value under truncation on 566164 samples, under rounding on
97794, and under neither on 161294 - nor the precision of the accumulator, since summing the same products in
a float makes it worse and not better.

So the cause is in the release's own arithmetic and has not been attributed, the thirty-six registry entries
stay **out**, and the four band files are not in the build: an object with no registry entry is kept in every
band from 4.3 and `check_registry` fails on the built symbols it has no row for. They are in
`.agent-work/pending-shears/` and `tests/backports/host/shear/run.sh` builds them from there, so the
measurement can be re-run, with two red controls: removing the NULL test ends the run on a signal, and
removing the vertical's far-edge anchor takes the failure count from 10157 to 12686.

**The next thing to try** was the release's weight table, and that is measured - the section below.

## The release's own filter, read out of its own buffer (2026-10-03, v-tail-a8)

Every measurement above went through a shear's own output. `vImageGetResamplingFilterSize` and
`vImageNewResamplingFilterForFunctionUsingBuffer` write the release's filter into a **caller's** buffer, so the
bytes are the release's own rather than something inferred, and three probes read them
(`.agent-work/probe/vexport.m`, `vdefault.m`, `vdump.m`).

**The buffer's layout.** An `int32` header - `scale` as a float at word 1, `numTaps` at word 2 (6 at a scale of
one and two, 12 at 0.5, 24 at 0.25; 10, 20 and 40 under `kvImageHighQualityResampling`), then 32, 16 and 64
(which is `numPhases`), the row size in bytes at word 4 - then `numPhases` rows of `numTaps` **unnormalised**
weights, the row stride rounded up to a multiple of four. With an identity probe kernel `f(x) = x` the release's
own sample positions come out exactly:

    scale  numTaps  numPhases  tap step   the argument of tap j of phase p
    1.0        6       64      1          step * (j - 2)  - p / 64
    2.0        6       64      1          step * (j - 2)  - p / 64
    0.5       12       32      0.5        step * (j - 5)  - p / 64
    0.25      24       16      0.25       step * (j - 11) - p / 64

and the same for Lanczos5 with `j - 4`, `j - 9`, `j - 19` and the same 64/32/16 phases. **`numPhases` is
`64 * min(1, scale)`,** which is header word 8 read straight out of the buffer, and **the phase is quantised to
`1 / (64 * min(1, scale))` of a pixel** - so the release's kernel is evaluated at a position on a grid of 64
phases per pixel at a scale of one and not at a continuous one.

**The table IS the port's kernel.** Fitting every stored row of every scale and both lobe counts against
`sinc(x) * sinc(x / lobes)` at those arguments gives a widest **absolute** residual of **2.89e-08** - the float a
weight is stored in - and after each row is divided by its own sum the widest **relative** difference from the
same kernel in double is **9.8e-08**. So `RevenantResampleWeights` computes what the release's filter holds.

**The "1.2e-06 relative" above could not have seen this.** It was measured by reading weights out through the
shear at phases in steps of an eighth, and an eighth is 16 of the release's 64 phases: the sweep landed on the
grid every time. `RevenantResampling.h` does not quantise the phase, and neither does `differential.m`, and the
differential's own sweep never leaves the grid either - its six translates and four slopes make every mapped
position a multiple of a **quarter** at a scale of one, of a half at two and 0.5, and a quarter at 0.25, which
are all multiples of `1/(64 * min(1, scale))` in every case. **Truncating the mapped position to the release's
grid changes the port's output on no case of the sweep at all**, which is measured, not argued.

**The release rounds; the port truncates.** `RevenantChannelPut` casts, which truncates toward zero. At a
translate of zero - where the kernel is the single tap at `L(0) = 1` and the sum is therefore an exact integer
- the host's own stored value is that integer, byte for byte, on **180 of 180** samples, and it is reproduced by
a round to nearest on 180 of 180 and by a truncation on 29 of 180. So the release rounds to nearest.

**The release's own default filter is a different table from the probe-built one, and it carries a third
substrate.** `vImageNewResamplingFilter(1.0f, kvImageNoFlags)` heap-allocates the object the shears use and
`vImageGetResamplingFilterSize` says how large it is, so its bytes can be read: the same 3192 bytes hold the same
int32 header and a table of 64 rows of 6 **normalised** weights - each row summing to 1.0 to 7e-08 where the
probe-built rows sum to between 0.994298514 and 1.0 - and past word 1300 a second table of **`int16` values** in
eight-wide rows whose two outermost entries are zero, whose phase-32 row is `[400, -2225, 10017, 10017, -2225,
400]` against the float table's `[0.0244565122, -0.135869563, 0.611413062, 0.611413062, -0.135869563,
0.0244565122]`, and whose entries are within 1.3 of a multiple of `1/16384` at every position. **Nothing else in
this file has read that int16 table, and it is where the next answer is.**

**What is still unattributed, with the numbers.** The failures are **not** vertical-only: parsing the run's own
log with the function name and the failure kind kept gives 4810 of the 9230 `FAIL` lines naming a Horizontal
function and 4420 a Vertical one, with every one of the four scales failing on both axes, and

    host - the port's exact double sum, over all 180 samples of one cell at translate 0.5, in tenths:
      at a translate of 0   : -0.0 to +0.1 only, 180 of 180 exact, the widest residual 0.0000
      at a translate of 0.5 : a smooth symmetric spread over -1.7 .. +1.7

so the release's arithmetic agrees with the port's to the last bit where the kernel is one tap and differs by
up to a unit and three quarters where six of them are, in **both** directions. Measured and excluded, each with
the count of the 180 samples a candidate reproduces by a round to nearest (the exact kernel itself explains 90,
and 180 of 180 at the whole-pixel control):

    float weights, float products, float accumulator, 4 accumulation orders,
    half-precision weights, a half accumulator, rounding or truncating each product
    before the sum, and a fixed-point grid on the weights over every power of two
    from 2^-8 to 2^-20 (the best, 2^-14, explains 116)      none

and the release's own table weights over the release's own window explain **95**, so the table the shears read
is not the difference either. A least-squares fit of a six-vector of fixed weights to the host's own stored
values recovers weights that differ from `sinc*sinc` by 1.5e-05 to 7.9e-05 and leaves a widest residual of
**0.679** against the 0.5 a round to nearest can explain, so a fixed weight vector does not close it either.

**So: the kernel is closed, the phase grid is closed, the rounding is closed, and the remaining unit and three
quarters is inside the release's accumulation of six products - and the substrate that has never been read is
the `int16` table inside the release's own filter object.**

## The int16 table decoded, and the arithmetic closed (2026-10-03, v-tail-a9)

The substrate a previous pass named and left unread is the release's own **Q14 weight table**, and it is
inside the object `vImageNewResamplingFilter(scale, flags)` allocates, past the float one.

**Its geometry, read out of the object rather than inferred.** Past a header and 64 rows of six `float`, a
second table of `int16` begins at **halfword 1080 (byte 2160)** of the 3192-byte default Lanczos3 filter at a
scale of one and two, **64 rows of eight** `int16` on a stride of 16 bytes. At a scale of 0.25 it is at
halfword 856 in sixteen rows of 24; at 0.5 the rows are twelve wide. **Every one of the 64 rows sums to exactly
16384**, so the scale is `2^14` and the row is normalised so its *integers* sum to the full scale - not to
within a rounding of it, on every row.

Row `p` is the kernel at the release's phase `p / 64`: entry `k` is the weight of tap `base - 2 + k` for
`base = floor(centre)`, and it equals normalised `sinc(x) * sinc(x / 3)` at `x = k - 2 - p/64` to within **1.24
of 16384**, i.e. 7.6e-05 in weight. Phase 0 is `[0, 0, 16384, 0, 0, 0]` because Lanczos3's lobes vanish at
every nonzero integer - `sinc(1) = 0` - and phase 32 is `[400, -2225, 10017, 10017, -2225, 400]`. **The
scale-1 and scale-2 tables are byte-identical**, which is what the phase grid `64 * min(1, scale)` predicts.

**The release sums those integers and rounds at the store, half UP.** Over **eighty cells of 180 samples** -
both axes, six translates, four slopes, both edging modes, `ARGB16S`, the release's own table and the host's own
output compared sample by sample (`.agent-work/probe/vsweep.m`) - the count of the host's stored values the
release's own row reproduces is

    the release's Q14 row, integer sum, round half up      14400 of 14400
    the same row, round half away from zero                14398 of 14400
    round-to-nearest Q14 weights, peak takes the remainder 11006 of 14400
    truncating Q14 weights                                  9922 of 14400
    the exact double kernel, round half up                 10777 of 14400

and the widest residual is 0.5, which is all a round to nearest leaves. The two misses in the first row are
saturation - a sum of 33186 against a signed 16-bit store's 32767 - which the port already clamps. **So the
integer weights are necessary and sufficient, and the store's tie goes toward plus infinity**, not away from
zero: a value of -1.5 rounds to -1, which a cast never could.

**The rule that turns the float weights into those integers is NOT identified**, and each of these is excluded
with a count of the 64 rows it fails: `trunc`, `round`, `floor`, `ceil`, round-half-away and round-half-even of
the normalised weight (57-62 rows wrong, worst 2); error-diffusion carry forward and backward on each of them
(59); the difference of consecutive rounded prefix sums (59-61); "quantise then put the deficit on one entry" by
any of ten priority keys (49-56); the largest-remainder apportionment (49); "quantise the *unnormalised* kernel
and rescale by the integer sum of the quantised row", over sixteen combinations of base, divisor and rounding
(56 at best); and "the peak entry takes the remainder", which cannot reach phase 32 at all because rounding
already sums to 16384 there and the row is not the rounded one. The row's entries are **not** a monotone
function of the exact weight - no single scale factor reproduces a row, which is what excludes every per-entry
rule - and the deviation from `trunc` reaches 1.6 of 16384, which is 150 times the float the release's own
float table stores the same weights in. So the release's integer path evaluates the kernel **less accurately
than its float path**, and that evaluation is the one thing left.

**What this changes in the port, and it is landed.** `RevenantChannelPut` cast, which truncates toward zero;
`tests/backports/host/shear/differential.m`'s own loops did the same. Both now round half up, and the packed
ten-bit field is masked *after* the round. `port and the host differ` goes **5743 -> 5260** over the sweep.
**The 109 samples a previous pass could not attribute are this and nothing else**: on `ARGB16S` the backColor is
`(int16_t)(-1.0)` = `0xFFFF` for channels 2 and 3, a sample whose whole kernel lies outside the source sums to
`-1` to within an ulp of double, and the truncating cast answers `0x0000` where the host answers `0xFFFF`.
Ninety-eight of the 109 are the host's `0xFF` against the port's `0x00` on the low byte of a channel, the other
eleven the same cast the other way, and rounding takes the count **109 -> 0**.

**The differential's blind spot is closed.** Its sweep's six translates and four slopes made every mapped
position a multiple of the release's grid, so it could not see the phase quantisation: planting the grid into
`RevenantResampleWeights` left both per-kind counts exactly where they were. A seventh translate of **1/128**
puts every mapped position off the grid at every scale, and the same plant now moves the harness's own loops
from 180 to 1328 cases. **The release does quantise the phase, and the differential can now see it.** The sweep
is 9900 checks and 10572 failures, both PLANT controls red, and `SAN=1` the same count.

**What is left, and it is one number's worth of arithmetic.** The port has to *produce* the Q14 row, and the
rule that produces the release's is not derived. It is not a rounding mode and it is not a scale factor, so it
is a fixed-point evaluation of `sinc` with about four significant decimal digits that the port cannot copy
without knowing it. The map for whoever takes it is one experiment: **read the Q14 row of a filter whose lobes
are not three**, which `vImageNewResamplingFilter(scale, kvImageHighQualityResampling)` gives (ten taps, forty
rows at a scale of one), and check whether the deviation from the normalised five-lobe kernel has the same
magnitude and the same sign pattern - a fixed-point `sinc` would, a normalising correction would not.

## The filter's constructors ARE on 6.1.3, and `RevenantResampling.h` is built on the opposite (2026-10-03)

Counted off `coordination/corpus/caches/*.tsv` on an exact tab-separated match, one row per framework that
carries the symbol:

| symbol | 6.0 | 7.0.1 |
| --- | --- | --- |
| `_vImageNewResamplingFilter` | 2 | 2 |
| `_vImageNewResamplingFilterForFunctionUsingBuffer` | 2 | 2 |
| `_vImageGetResamplingFilterSize` | 2 | 2 |
| `_vImageDestroyResamplingFilter` | 2 | 2 |
| `_vImageGetResamplingFilterExtent` | 0 | 2 |
| `_vImageHorizontalShear_ARGB16S` | 0 | 2 |
| `_vImageHorizontalShearD_ARGB16S` | 0 | 2 |

So **the sixteen-bit shears and `vImageGetResamplingFilterExtent` arrive at 7.0 and the filter's four
functions are there from 6.0**, which is the asymmetry that matters here - and it is the opposite of what
`RevenantResampling.h` records. That file's own comment reads: "the Accelerate band measured that the armv7
caches carry **none** of vImage's C API below 7.0.1, so whatever the header's `API_AVAILABLE(ios(5.0))` says,
there is no `vImageNewResamplingFilter` and no `vImageNewResamplingFilterForFunctionUsingBuffer` on 4.3 or
6.1.3 to fill a caller's buffer. So the port writes the filter itself, into a buffer the caller allocated from
`vImageGetResamplingFilterSize`, and **the layout is the port's own**." The second half of that is what the
design rests on, and the premise is false for 6.1.3. (The 4.3 claim is not settled either way: the corpus holds
no 4.3 index.)

**Two consequences. The first is the port's; the second is the coordinator's ruling of 2026-10-03, recorded here
because this page is the durable record and it is about to land.**

1. `RevenantResampleFilterOf` refuses every buffer whose tag is not the port's own and `RevenantShearReady` answers
   `kvImageInvalidParameter` for the NULL it returns. **A caller on a real device builds its filter with the
   system's `vImageNewResamplingFilter`, so the port's shears refuse every call that carries a genuine filter.**
   That is a defect on the 7.0+ band the thirty-six rows are for, and it is independent of the weight question.
   Nothing in the corpus contradicts it: the ledger carries no row for any of the four filter functions, only
   for `vImageGetResamplingFilterExtent()`.
2. **The coordinator's ruling: the filter's format is PRIVATE, so reading the Q14 row out of the caller's buffer
   is a crutch and is recorded as one.** An earlier version of this section argued the opposite - that
   `Geometry.h` documents the buffer ("This function writes the kernel values into a preallocated kernel buffer
   that you provide") so the read would be the constructor's own contract rather than a private structure. **That
   argument is withdrawn**: what the header documents is that the release fills a caller-provided buffer, not
   the buffer's internal layout, and the layout is not public. So the Q14 row is in the caller's buffer and the
   port would read it, and that read is a crutch: the measurement and the record belong to v-tail-a10 on the
   6.1.3 guest and to `coordination/crutches.md`, which stays open until a native fix is merged. The generator
   question is therefore **deferred, not answered** - see the section above for what is excluded and for the
   five-lobe measurement that would settle whether the release's integer path evaluates the kernel less
   accurately than its float path.

**The one oracle caveat that belongs with every measurement on this page.** Everything measured about the Q14
row, the integer sum, the half-up store and the 14400 of 14400 is **this Mac's macOS Accelerate**, not the
armv7 release the port targets; the device measurement is the one that decides, and a 6.1.3 guest is where to
take it. The layout measured here - the header, 64 rows of eight `int16` at halfword 1080 for the default
Lanczos3 filter, every row summing to 16384, the scale-1 and scale-2 tables byte-identical - is a macOS
reading and is not yet an armv7 one.

## The 6.1.3 filter's layout, read out of the release's own instructions (2026-10-04, v-tail-a11)

Every number in the section above came from **macOS Accelerate**, and macOS Accelerate is not 6.1.3's. The
6.1.3 armv7 cache was read with the in-tree disassembler (`tools/corpus/disasm.sh`, v-crutch4's, on main) at
the release's own addresses - `_vImageNewResamplingFilter` at 0x30418ef9, `_vImageNewResamplingFilterForFunctionUsingBuffer`
at 0x3041905d, `_vImageGetResamplingFilterSize` at 0x30419299, and the static header writer both of the first
two call at **0x304192c0**:

    REVENANT_ROOT=$PWD sh tools/corpus/disasm.sh ~/.revenant/dyld/6.1.3/dyld_shared_cache_armv7 \
        /Frameworks/vImage 3041905d 30419299 armv7

`_vImageNewResamplingFilter(scale, flags)` builds a descriptor on its own stack, allocates, and calls
`_vImageNewResamplingFilterForFunctionUsingBuffer(buffer, scale, NULL, NULL, 0, flags)`, which calls the
writer with `r0 = buffer`, `d0 = (double)scale` and `d1 = (double)(1.0/scale)`. The writer is the whole of the
header:

| object byte | word | the instruction that stores it | what it is |
| --- | --- | --- | --- |
| 0..7 | 0,1 | `vstr d16, [r0]` with `d16 = vdiv.f64(1.0, d0)` | **the double `1.0/scale`** |
| 8 | 2 | `vstr s0, [r0, #8]`, `s0 = (int)(2*taps + 0.5)` | `numTaps` |
| 12 | 3 | `str r12, [r0, #12]`, `r12 = (15 + 4*numTaps) & ~15` | the float row stride, bytes |
| 16 | 4 | `str r3, [r0, #16]`, `r3 = (((2 or 3) + 2*numTaps) + 12) & ~15` | the int16 row stride, bytes |
| 20 | 5 | `str lr, [r0, #20]`, `lr = 1 << clamp(133 - ubfx(float(1/scale), 23, 8), 0, 6)` | the phase count |
| 24 | 6 | `str r1, [r0, #24]`, the same clamped value | the phase exponent |
| 28 | 7 | `add r1, r12; str r1, [r0, #28]` with `r12` = word 8 | the Q14 table's last byte |
| 32 | 8 | `mla r12, floatStride, numPhases+1, r2` with `r2 = (buffer + 55) & ~15` | the float table's end, and so the **Q14 table's first byte** |
| 36 | 9 | `str r2, [r0, #36]` | `(buffer + 55) & ~15` |

`taps` is `|lobes/scale|` when `|scale| < 1` and `lobes` otherwise, and `lobes` is **3.0** or **5.0** read out of
the release's own literal pool - the doubles at 0x304193ca and 0x304193c2, selected by `tst r2, #32`, which is
`kvImageHighQualityResampling`. `_vImageGetResamplingFilterSize` is that same writer on a stack buffer followed
by `ldr r0, [sp, #28]; adds r0, #16`, so **the size is word 7 + 16**.

**Three things follow that the macOS measurements above do not say.**

1. **The scale is in the object, exactly, as a `double`.** v-tail-a10 could not find it in macOS's layout and
   concluded that the caller's scale above one was unrecoverable from the filter; on 6.1.3 it is
   `1.0 / *(double *)object`. That is the one field the port needs to read, because the lobes come from the
   shear's own flags and the rest of the geometry comes from `numTaps` and the two strides.
2. **The phase count is a power of two, not `64 * min(1, scale)`.** `1 << clamp(133 - exponent(float(1/scale)), 0, 6)`
   answers 64 at a scale of **0.75**, where `64 * min(1, 0.75)` is 48. v-tail-a10's own table already measured
   64 rows at 0.75 and its formula did not; the instruction settles it, and the formula is wrong off a power
   of two.
3. **The int16 row width is `((3 + 2*numTaps) + 12) & ~15` under `kvImageHighQualityResampling` and `((2 + 2*numTaps) + 12) & ~15`
   otherwise**, which at a scale of 0.5 with five lobes (twenty taps) is **40 bytes, twenty int16** - where macOS
   stores 48. The row width is what the tap window hangs on, so it is a per-release number and macOS's is not
   6.1.3's.

The **Q14 table begins at word 8's value** - `_vImageNewResamplingFilterForFunctionUsingBuffer` reads
`ldr r6, [buffer, #32]` into the row pointer and advances it by word 4 on each phase - and runs `numPhases`
rows of `int16Stride / 2` int16. Its last byte is word 7.

## Why the row cannot be generated and must be read: the release's own `sinf`

The row is quantised out of a table the release's own **default kernel function** builds, and that function is
`sinf` and `cosf` in **single precision**. At 0x30418d48 - the three-lobe one, which `vmov.f32 d11, #3.000000e+00`
names - the loop is

    vldr  s0, [r6]            ; the tap argument
    vmul  d1, d0, d10         ; ... times pi
    vmul  d0, d16, d0
    blx   0x30436e68          ; sinf
    blx   0x30436e6a          ; cosf
    vmul  d0, d13, d16
    vdiv  s2, s0, s24         ; normalise by the row's sum

and the quantiser at 0x30419214 is `vcvt.s32.f32` of the weight times a constant - **truncation, not
rounding**. That is why the exclusion list in the section above had `trunc` on it and why none of those rules
was it: `trunc` of the *exact double* kernel is not `trunc` of *this* row, because this row is a truncation of
a `sinf` the port does not have. **So the map a previous pass left for whoever took this next is answered from
the release's own instructions:** the row is not a fixed-point evaluation of a formula to be searched for, it
is the bits of one libm's single-precision `sinf`. There is no rule.

The port therefore reads the row out of the caller's filter - a private layout, a `crutches.md` entry carrying
the measurement above - and `RevenantResampleFilterOf` refuses anything whose header does not match it:
`numTaps` positive, the row width a whole number of int16, the phase count a power of two of at most 64, and
every row of the Q14 table summing to exactly 16384.

## The layout on the device, nine shapes: measured on iPhone3,1 6.1.3 10B329 (2026-10-04, v-tail-a11)

The section above is a reading of 6.1.3's own instructions; this is the same nine shapes read out of real
objects on an iPhone3,1 6.1.3 10B329 guest, through `vImageNewResamplingFilter(scale, flags)`, with the probe's
built and installed binaries compared by LC_UUID first. Three guesses were written down before the run, in
`.agent-work/PREDICTION-vimguest.md`, and this is which of them held.

    scale  lobes   size  size-w7  numTaps fStr iStr phases log2exp   1.0/double at byte 0   Q14 at   rows
      1      3    3168        16        6   32   16     64       6                 1          2128   1024
      2      3    3168        16        6   32   16     64       6                 2          2128   1024
   0.75      3    3168        16        8   32   16     64       6               0.75          2128   1024
     0.5      3    2672        16       12   48   32     32       5                 0.5          1632   1024
    0.25      3    2464        16       24   96   48     16       4                0.25          1680    768
      1      5    5232        16       10   48   32     64       6                 1          3168   2048
      2      5    5232        16       10   48   32     64       6                 2          3168   2048
   0.75      5    6272        16       13   64   32     64       6               0.75          4208   2048
     0.5      5    4240        16       20   80   48     32       5                 0.5          2688   1536

**Nine of nine on the scale.** `1.0 / *(double *)object` is **1, 2, 0.75, 0.5 and 0.25 exactly**, at every lobe
count - the field v-tail-a10 could not find is found, and it is found on the release that ships.

**Nine of nine on the phase count**, and it is **64 at a scale of 0.75** on the device as well as on the host.
The rule is the instruction's: `1 << clamp(133 - exponent(float(1/scale)), 0, 6)`, a power of two.

**Nine of nine on the two strides, `numTaps` and `log2exp`**, each equal to the formula the writer's own
instructions give. Two of the numbers in the prediction table were my own arithmetic slips and the device
refuted them: `numTaps` at a scale of 0.75 is **8** (three lobes) and **13** (five), not 6 and 10, because
`|lobes/scale|` is four and 6.67 there; and the int16 stride at a scale of 0.5 with five lobes is **48** bytes,
not 40 - `((3 + 2*20) + 12) & ~15` is 48.

**Two things the device says that no instruction reading predicted.**

- **Word 7 is an OFFSET from the object, not a pointer.** The first probe run compared it against a pointer
  and refused all nine shapes, and that refusal is the measurement: `subs r0, r0, r3; add r0, r1` leaves the
  distance from the object's own base. It is `phases * int16RowStride`, exactly, at all nine shapes, and the
  Q14 table begins at **word 8's value** and ends one byte past word 7's offset. Word 9 is `base + 48`.
- **`vImageGetResamplingFilterSize` is not a function of the header's numbers.** Two runs of the same probe
  answered **3168** and **3160** for the same shape, because the size is `word7 + 16` measured on the
  *caller's stack* descriptor and `((sp + 55) & ~15) - sp` is 16 or 8 by that frame's alignment. So the port
  must not use the size to bound the table; the table's own offset is word 7.

**And the row sum is NOT 16384 on 6.1.3.** Nine of nine shapes have rows that do not sum to 16384 - 49 of 64 at
a scale of one, 30 of 32 at 0.5, **all sixteen** at 0.25 - while the same shapes on macOS sum to 16384 on every
row. The row the device answers at phase 32 is `[400, -2226, 10017, 10017, -2226, 400, 0, 0]`, which sums to
**16382**; macOS answers `[400, -2225, 10017, 10017, -2225, 400]` for the same phase and the same kernel, and
that sums to 16384. **So the "every row sums to exactly 16384" invariant v-tail-a9 measured, and this page has
repeated ever since, is a macOS property and not a release property**: 6.1.3 quantises by truncation with no
correction pass, which is what `vcvt.s32.f32` on its own does, and macOS later added the pass that makes the
integers come back to the full scale. A refusal rule built on the row sum would refuse the 6.1.3 filter this
package is for.

`K0 = argmax(row 0) = (numTaps - 2) / 2` holds on all nine shapes on the device as well: 2, 2, 3, 5, 11, 4, 4, 5,
9. The row widths are the int16 stride halved: 8, 8, 8, 16, 24, 16, 16, 16, 24.

### What the shear scored on the device, and what that says

The same probe ran the release's own `vImageHorizontalShear_ARGB8888` against the model of the section above -
280 samples per shape, seven translates by forty columns - reading its scale and its Q14 row out of the object:

    scale   3 lobes    5 lobes
       1      223/280   199/280
       2        1/280    15/280
    0.75       51/280    40/280
     0.5      122/280   112/280
    0.25      191/280      -

**So the arithmetic is NOT closed on the release that ships**, and the residual is not a rounding: at a scale of
2 the model reproduces **one sample of 280**. The scale is right - it is the release's own number read from its
own object - and the Q14 row is the release's own, so what is wrong is the **mapping** from a destination
coordinate to a row and a base tap. The host measured the same model at 262-273 of 280 on macOS, where the
filter's rows happen to sum to the full scale; on 6.1.3 they do not, and the shortfall is 40-280 samples.
That is the next measurement and it is one delta sweep: a source with a single column carrying 255 makes every
destination answer one row entry divided by the full scale, which names the row and the base tap the release
used without any reasoning about the kernel.

## The delta sweep on the device: what the mapping is, and the one shape that is not a row (2026-10-04, v-tail-a11)

**SUPERSEDED BY THE SECTION BELOW, AND TWO OF ITS READINGS ARE WRONG. Kept because the run is real.** Its
matrix was transcribed from a log line the terminal wrapped: the probe prints each column's *header* and its
*value* on the same line for `c = 0` and eight values per line after that, so reading the wrapped stream as
eight values per line shifted every row by one and produced a "+1 shift" and a `2c + 2` peak that are not in
the release's bytes. The predictions it wrote down, and the scale-2 conclusion it drew from the shape, are
answered and refuted in the next section; the two claims of it that **hold** are the identity at a scale of
one and the rule that the probe's shape, not the arithmetic, was the thing to rule out first.

A source with **one column carrying 255 and every other column zero** makes every destination answer one row
entry divided by the full scale, so the release's own output names the weight it used without any reasoning
about the kernel. Alpha is 255 in every pixel, which matters: the same sweep with alpha 0 gives different
answers, so ARGB8888's alpha is on the path and a sweep that leaves it at zero measures something else.

**A scale of one is a perfect identity, with no cross-talk at all** - destination `x` answers 255 for source
column `x` and 0 for every other column, at `x = 0 .. 6`:

        c\x     0    1    2    3    4    5    6    7
          0     0  255    0    0    0    0    0    0
          1     0    0  255    0    0    0    0    0
          2     0    0    0  255    0    0    0    0
          3     0    0    0    0  255    0    0    0
          4     0    0    0    0    0  255    0    0
          5     0    0    0    0    0    0  255    0
          6     0    0    0    0    0    0    0  255

**A scale of two is not a convolution of its own row at consecutive columns.** The full response matrix, the
release's own bytes, a translate of 0 and a slope of 0:

        c\x     0    1    2    3    4    5    6    7
          0     0  156  255  156    0    0    0    6
          1     0    0    0  156  255  156    0    0
          2     0    6    0    0    0  156  255  156
          3     0    0    0    6    0    0    0  156
          4     0    0    0    0    0    6    0    0
          5     0    0    0    0    0    0    0    6

Three things are readable off it without any model:

- **Source column `c` lands at destination `2c + 2`** - the 255 is at `(0,2)`, `(1,4)`, `(2,6)` - so the
  magnification is real and one source pixel becomes two.
- **The weights are the release's own.** `156/255 = 0.6118` and `6/255 = 0.0235` against the row's
  `10017/16384 = 0.6113` and `400/16384 = 0.0244`, so they are `L(0.5)` and `L(1.5)` off phase 32, and the 255
  is phase 0.
- **A destination's answers over the source do not sum to 255.** At `x = 3` they come to `156 + 255 + 156 + 6 =
  573`, two and a quarter times the input. A convolution whose taps all land inside the picture sums to the
  input, so **the release is not applying one row at one base tap**, and a search over all 64 phases and 36
  base taps found no `(phase, base)` that reproduces even one of these columns.

**So the mapping is open at a scale of two, and this is where the family stands.** The first thing to rule out
is the probe, not the release: the sweep used a source and a destination that are both forty pixels wide for a
**magnification**, and a magnification whose destination is the source's own size asks the release to compress,
which is a different call. Re-run the sweep with the destination `2 * srcWidth + 4` wide before anything is
concluded about the arithmetic - but note that the 280-sample model scoring **1 of 280** at a scale of two is
from a sweep with that same shape, so the 1 and the matrix may share one cause.

**What is closed by this run**, and it is what this band was sent for:

- the header layout, nine of nine shapes, byte for byte, on the device as well as in the disassembly;
- **the scale, `1.0 / *(double *)object`, exact at every shape including 0.75 and above one**;
- the phase count, nine of nine, a power of two, 64 at 0.75;
- `K0 = argmax(row 0) = (numTaps - 2) / 2`, nine of nine;
- the row sums, which are **not** the full scale on 6.1.3: the widest `|row sum - 16384|` over every row of
  every shape is **3, 3, 4, 4, 5, 3, 3, 3, 4** for scales 1, 2, 0.75, 0.5, 0.25 at three lobes and 1, 2, 0.75,
  0.5 at five. That is the bound a refusal test on the rows may use, and it is the measurement that retires
  the "every row sums to 16384" invariant as a release property;
- that the **scale-1 and scale-2 Q14 tables are byte-identical** on the device (phase 32 is
  `[400, -2226, 10017, 10017, -2226, 400, 0, 0]` at both), which is what the phase rule's being a power of two
  predicts and what no host measurement had shown.

**The matrix printed in that section is not the release's bytes and neither is the reading of it.** It reads
"source column `c` lands at destination `2c + 2`" and "a destination's answers over the source sum to 573"; both
come from a printout that is one column out of phase, and the next section has the same sweep with the
destination sized for the scale, where every answer is indexed as it is read and the sum over the destination
of a delta is 255 at a scale of one.

## The header on every release the shears run on, and the one place it changes (2026-10-04, v-tail-a12)

The section above read one release's writer, 6.1.3 armv7. **The port's rows run on armv7 6.x and on every
arm64 release below each row's introduction, so a layout measured on one of them is not a layout.** Every
writer below was read with the in-tree disassembler at the release's own address, found with the repository's
own export-trie reader (`tools/corpus/cache-value.lua`'s export walk (`modules/apple/dyld.lua`'s `image_symbols`), which answers `_vImageNewResamplingFilter` =
`0x30418ef9`, `_vImageGetResamplingFilterSize` = `0x30419299` and
`_vImageHorizontalShear_ARGB8888` = `0x303d2865` on the 6.1.3 armv7 cache, which are the addresses the section
above used - so the reader and the disassembler agree before either is trusted on a release neither has read):

    REVENANT_ROOT=$PWD sh tools/corpus/disasm.sh ~/.revenant/dyld/7.0/dyld_shared_cache_armv7 \
        /Frameworks/vImage 2c4e4c19 2c4e4d10 armv7      # the 7.0 armv7 writer, found from _vImageGetResamplingFilterSize
    REVENANT_ROOT=$PWD sh tools/corpus/disasm.sh ~/.revenant/dyld/7.0/dyld_shared_cache_arm64 \
        /Frameworks/vImage 1804add2c 1804ade10 arm64e    # the 7.0 arm64 writer
    REVENANT_ROOT=$PWD sh tools/corpus/disasm.sh ~/.revenant/dyld/12.0/dyld_shared_cache_arm64 \
        /Frameworks/vImage 182712118 1827122c0 arm64e   # 12.0's writer, inlined into _vImageGetResamplingFilterSize

**The fields are the same on every release read, and every one of them is computed the same way:**

| what | the instruction, on every release read |
| --- | --- |
| the double `1.0/scale`, at the first slot | `vdiv.f64 d16, d20(1.0), d0` then `vstr d16, [r0]`; `fdiv d0, d3(1.0), d0` then `str d0, [x0]` |
| `numTaps = (int)(2*min(lobes/scale, lobes) + 0.5)` | `vadd d18,d18,d18; vadd d18,d18,0.5; vcvt.s32.f64`; `fadd d0,d0,d0; fadd d0,d0,0.5; fcvtzs` |
| `lobes` = 3.0 or 5.0 | `tst r2, #32` / `tst w2, #0x20` - `kvImageHighQualityResampling` - selecting one of two literal-pool doubles |
| the float row stride `(15 + 4*numTaps) & ~15` | `add r2,15,r1,lsl #2; bic r12,r2,#15`; `lsl x11,x10,#2; add #15; and #~15` |
| the int16 row stride `(((2 + 2*numTaps) & ~3) + 15) & ~15` | `mov r2,#2; add r9,r2,r1,lsl #1; bic r3,r9,#3; adds #15; bic #15`; arm64 the same in `x12` |
| the phase exponent `clamp(133 - exponent(float(1/scale)), 0, 6)` | `ubfx r1,r3,#23,#8; rsb r1,r1,#133` then the two clamps; arm64 `lsr w8,w8,#23; sub w8,133,w8,uxtb` then `csel` twice |
| the phase count `1 << exponent` | `lsl.w lr, 1, r1`; arm64 `lsl w9,w10,w9` |
| the Q14 table's end, as an **offset from the object** | `sub r0, r12, r0` then `+ int16Stride<<exponent`; arm64 `sub x8,x10,x0` then `madd` |
| the size | the offset `+ 16`, on every release |

**Where it changes is the WIDTH of a field, and that follows the architecture and nothing else.** Every field
is a 32-bit slot on armv7 and a 64-bit slot on arm64:

**There are exactly TWO shapes, and which one a release has is decided by its architecture and nothing
else. No arm64 writer read differs from another:**

| releases read | arch | the slots, by byte offset from the object |
| --- | --- | --- |
| 6.1.3, 7.0, 8.0, 9.3.6, 10.3.4 | armv7/armv7s | `0` scale (double), `8` numTaps, `12` floatStride, `16` int16Stride, `20` phases, `24` exponent, `28` **offset**, `32` **Q14's first byte**, `36` `(object+55)&~15` |
| 7.0, 7.0.1, 10.0.1, 11.0, 12.0 | arm64 | `0` scale (double), `8` numTaps, `16` floatStride, `24` int16Stride, `32` phases, `40` exponent, `48` **offset**, `56` **Q14's first byte**, `64` `(object+87)&~15` |

The two are the same nine fields in the same order. **On armv7 each is a 32-bit slot at byte `4k`; on arm64
each is a 64-bit slot at byte `8k`.** The last three arm64 stores are worth quoting because they are the
ones a reader gets wrong, and they are written in a different ORDER on 7.0 than on 12.0 while meaning the
same thing:

    7.0 arm64, 0x1804adde0   madd x10, x10, x12, x13    ; the float table's end = floatStride*(phases+1) + base
    0x1804adde4               stp  x10, x13, [x0, #56]  ; byte 56 = that end, byte 64 = (object+87)&~15
    0x1804adde8               sub  x8, x10, x0          ; the offset = the end - object
    0x1804addec               madd x8, x9, x11, x8      ;             + int16Stride*phases
    0x1804adef0               str  x8, [x0, #48]        ; byte 48 = the offset, written LAST

    12.0 arm64, 0x182712218  str  x10, [sp, #72]       ; byte 64 = the base, written BEFORE the end
    0x18271221c               madd x10, x11, x13, x10   ; the float table's end
    0x182712220               sub  x8, x10, x8
    0x182712224               madd x8, x12, x9, x8      ; the offset
    0x182712228               stp  x8, x10, [sp, #56]  ; byte 48 = the offset, byte 56 = that end

So **the Q14 table's first byte is in the object on every release read** - byte 32 on armv7, byte 56 on arm64
- and the offset is stored as an offset on both shapes. **Nothing has to be computed from another field, and
the port reads byte 56 on arm64 because that is where the field is on all five arm64 releases, not because
7.0 overwrites anything.** (An earlier draft of this section said 7.0 and 7.0.1 overwrote byte 48 and that the
table's first byte had to be computed. That was a misread of the `stp` base - `#56` is bytes 56 and 64, not 48
and 56 - and it is corrected here rather than left on the page.)

**Three things follow, and each one is a refusal the port has to make.**

1. **A "word N" on this page is an armv7 offset.** Byte 8 is `numTaps` on both shapes, but byte 20 is the
   phase count on armv7 and byte 32 is on arm64, while byte 32 on armv7 is the Q14 table's first byte and on
   arm64 it is the phase count. **A port that reads "word 8" and "word 20" gets `numTaps` right on every
   release, gets the phase count on arm64 only by accident, and gets every field after it wrong.** The port
   therefore keys the layout on what the release is - armv7/armv7s or arm64 - and accepts exactly those two
   measured shapes, refusing anything else.
2. **The offset is the only bound the port may use, and it is an offset on both shapes.** Neither writer
   stores a pointer to the table's end; both store `floatTableEnd - object + int16Stride*phases`. A refusal
   that compares that field against a pointer refuses the release's own filter, which is exactly what the
   first version of this probe did - and that refusal was the measurement that word 7 is an offset.
3. **The coverage is bounded by the held set and is not extrapolated.** Every held release with an armv7 slice
   carries the armv7 shape, and every one measured agrees - 6.1.3, 7.0, 8.0, 9.3.6 and 10.3.4, which is both
   ends of the held armv7 ladder (6.1.3, 7.0, 7.0.6, 7.1, 7.1.1, 7.1.2, 8.0, 8.0.2, 8.1, 8.1.1, 8.1.2, 8.1.3,
   8.2, 8.3, 8.4, 8.4.1, 9.0, 9.0.2, 9.1, 9.2, 9.2.1, 9.3, 9.3.5, 9.3.6, 10.0.1, 10.0.2, 10.1, 10.1.1,
   10.2, 10.2.1, 10.3, 10.3.1, 10.3.2, 10.3.3, 10.3.4). **Every held arm64 release below 15.0 carries the
   arm64 shape and all five were read** - 7.0, 7.0.1, 10.0.1, 11.0, 12.0. **The held arm64 slices are those
   five plus 16.0 and 18.0, and there is none between 7.0.1 and 10.0.1**; the two ends of that gap read the
   same, so the gap is stated and not filled. 16.0 and 18.0 are above every row's introduction and are not
   read, and the 16.0 cache is split into 44 subcaches that were not read for these rows, so nothing
   about it is claimed here.

**One arithmetic difference, and it changes nothing.** 6.1.3's armv7 writer adds a `+1` to the int16 row
stride under `kvImageHighQualityResampling` and 7.0 and later do not. For every tap count these two spellings
round to the same multiple of 16 - `numTaps` 6, 8, 10, 12, 13, 20, 24 give 16, 16, 32, 32, 32, 48, 48 either
way - so the branch is redundant on every shape measured and is recorded here rather than implemented.

## The mapping, closed: `centre = (x - translate) / scale` (2026-10-04, v-tail-a12)

The sweep above was re-run on iPhone3,1 6.1.3 10B329 with **the destination sized for the scale** -
`dstW = ceil(scale*24) + 8` over a 24-pixel source - because a magnification whose destination is the
source's own width asks the release to compress, and that is a different call. The predictions are in
`.agent-work/PREDICTION-vimguest-a12.md`, written before the run, and this is which of them held. Every answer
below is printed as `x:value` with its own index, so nothing is read off a formula.

**P1 was wrong in its sign and right in its shape: a scale of one is an exact identity, `source c -> dest c`,
24 of 24, and the delta's total over the whole destination is 255.** The `+1` of the section above is not in
the release's bytes; it was the wrapped log line. **P2 held: with the destination sized for the scale a delta's
answer is two destination pixels wide and its total is near 255** - 573 only in the shape that asks for a
compression. **P3 could not be separated**: at every shape measured, dividing by the row's own sum and by
16384 give byte-identical answers, because the rows are within 3 to 5 of 16384. **P4 held**: an exhaustive
search over every `(phase, base)` finds a pair for every destination column at every scale. **P5 did not hold
at 0.75**, and the residual is named below. **P6 was wrong**: a 0.75 minification is not an integer box - the
same row is on that path as everywhere else.

### The rule, and how it was decided

Every Q14 row the release handed out is in the run's section D and every one-column delta's whole destination
answer is in its section C, so the pair each destination column takes is found **by exhaustion over all 64 rows
and every base tap**, not by fitting. The pair is then compared against the formula:

    centre = (x - translate) / scale
    base   = floor(centre)
    q      = floor(frac(centre) * phases + 0.5)
    carry  = q / phases                      (integer)
    phase  = q - carry * phases
    base  += carry
    K0     = argmax(row 0)                  (already measured, nine of nine)
    out    = clamp(round_half_up( sum over k of row[phase][k] * in[base + k - K0], divided by 16384 ))

**There is no half pixel.** `centre` is `x/scale` and not `(x + 0.5)/scale - 0.5`, and that single fact is the
whole of what the section above could not close: it is why a scale of one is an identity rather than a
half-pixel blur, and why a scale of two puts source `c` at destination `2c` and not at `2c + 2`.

**The score, against the release's own stored bytes, and nothing else:**

| what | scale 1 | scale 2 | scale 0.75 | scale 0.5 |
| --- | --- | --- | --- | --- |
| every one-column delta, every destination column | **768 of 768** | **1344 of 1344** | **596 of 624** | **480 of 480** |
| the same rule on the destination-the-size-of-the-source shape | 576 of 576 | 576 of 576 | 548 of 576 | 576 of 576 |
| a ramp at translate 0 | 32 of 32 | 56 of 56 | 24 of 26 | 20 of 20 |
| a ramp at translate 0.5 | **32 of 32** | **56 of 56** | 25 of 26 | 20 of 20 |
| a ramp at translate 0.25 | **32 of 32** | **56 of 56** | 25 of 26 | 20 of 20 |
| a ramp at translate 0.125 | **32 of 32** | **56 of 56** | 19 of 26 | 20 of 20 |

The bold rows are the translate, and they are the only place the six candidate spellings separate: at a
translate of 0.5 and 0.25 `centre = (x - t)/scale` is 32 of 32 and 56 of 56 while `centre = x/scale - t` is 7 of
32 and 7 of 56, `centre = (x + 0.5 - t)/scale - 0.5` is 7 and 7, and `centre = (x + t)/scale` is 5 and 5. **The
translate is inside the parenthesis with `x` and the whole is divided by the scale**, and that is what the
release's bytes say.

### What is left, named

- **A scale of 0.75 misses 28 of 624 and a ramp at a translate of 0.125 misses 7 of 26.** Every one of the
  twenty-eight is at a destination whose `centre` is a third of a pixel - `x/0.75` is `4x/3` - and every one is
  off by 1 to 3: `x=2 c=2` release 119 model 116, `x=2 c=3` release 169 model 171, `x=3 c=3` release 55 model
  52, `x=2 c=4` release 0 model 1. **So the residual is a rounding of the fractional position at a scale whose
  reciprocal is not a binary fraction, and it is not the arithmetic**: at the scales whose `1/scale` is a
  binary fraction the same code is exact, 1344 of 1344 and 480 of 480. It is not fixed here and not hidden;
  the next measurement is one more sweep at a scale of 0.75 with the destination one column longer on each
  side, which separates whether the release rounds the phase of `4x/3` twice.
- **The divisor is not separated.** Dividing by the row's own sum and by 16384 give the same byte at every
  answer in this run. The release's own worker does sum the row it is about to use (a `ldrsh` loop over
  `numTaps` int16 at 0x3040f488 in the 6.1.3 armv7 cache), so the port divides by the sum it read, and this
  page does not claim the two differ.
- **`kvImageBackgroundColorFill` and the far tap.** At a scale of two with a destination wider than the
  source needs, the release convolves past the end of the source and answers 6 where the tap window still
  reaches source column 23 - `x = 51` answers 6, and the rule above reproduces that 6. It does **not** clamp
  the destination to what the source can fill. The port does the same; nothing here claims an edge rule it did
  not measure.

### Three readings of the 6.1.3 disassembly that this run confirms, and one it corrects

Read with `tools/corpus/disasm.sh` on the 6.1.3 armv7 cache, no emulator:

- **`vImage_Buffer` is `{data, height, width, rowBytes}`** on this release, byte offsets 0/4/8/12, which is the
  SDK's own order (`Accelerate/vImage/vImage_Types.h:143`). The worker reads `[src+8]` as the width and
  `[src+12]` as the row bytes. **The section above's worry about a reversed field order does not apply**, and
  v-tail-a10's caveat about it is retired.
- **The shear takes the SDK's modern nine arguments**, `(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y,
  xTranslate, shearSlope, filter, backColor, flags)`: the wrapper stores the filter at `[sp+16]` and the worker
  dereferences it as `*(double *)filter` for the scale and reads its words 2, 4, 6 and 8. **There is no
  `divisor` argument** - the only six-argument-era spelling on this release is
  `vImageGetResamplingFilterSize(scale, func, divisor, flags)`, which the probe still calls through `dlsym`.
- **The scale enters as `min(1.0/scale, 1.0)`** and `floor` of that is kept beside it as a separate integer, so
  a minification is not the same code as a magnification. **The prediction P6 drew from this - an integer box -
  is refuted by the device**: a 0.75 minification convolves with the release's own Lanczos row like every other
  scale, and 596 of 624 is a rounding residual rather than a different filter.
- **CORRECTED: the worker computes `d13 = 1 + (row - destHeight)*recip*slope - ... ` and then
  `centre = d13 + x*recip`, which reads as a `+1`.** It does not: at a scale of one the release is an exact
  identity, 768 of 768. The constant that reads as 1.0 is consumed before the addition, and the release's
  stored bytes are what settles it.

## The half pixel IS there, and a12's rule is the scale-of-one case of it (2026-10-04, v-tail-a13)

The section above measured `centre = (x - translate)/scale` and concluded there is no half pixel. **That is
true at a scale of one and false at every other scale**, and the engine written from it was wrong at three of
the four scales the shears run at. This section is the measurement that says so, taken on the host's own bytes.

    horizontal:  position = along0 + along + 0.5 - translate + slope*(cross - dstCross + 0.5)
                 centre   = position * reciprocal - 0.5
    vertical:    position = along0 + along + 0.5 + translate + slope*(cross + 0.5)
                 centre   = dstAlong + (position - dstAlong) * reciprocal - 0.5

`mapsearch.m` decides it by exhaustion: a one-column (or, on the vertical, one-row) delta of 65535 on channel 0
with alpha 65535 everywhere, the host's own whole destination for every delta, and then every candidate
spelling scored on **every byte** of all of them. The candidate space is the along offset over a ladder of
eighths, the translate's sign, the slope's cross offset over a ladder of quarters, the half pixel on and off,
the far anchor on and off, and `multiply by the stored reciprocal` against `divide by 1/reciprocal`. The
instrument and its log: `.agent-work/hostlayout/mapsearch.m`, `mapsearch.log`.

**Every one of the sixteen (translate, slope) shapes has a perfect candidate at scales 1, 2, 0.5 and 0.25, on
both axes** - 16 shapes x 225 bytes x 4 scales x 2 axes, 0 shapes with no candidate. What the surviving
spellings say:

- **The half pixel is in the scale's bracket, `+0.5` on the position and `-0.5` on the centre.** The proof is
  the along offset each scale needs: **0 at a scale of one, -0.5 at two, +0.25 at a half, +0.375 at a
  quarter**, and `(along + 0.5)*recip - 0.5` asks for exactly those. A half pixel removed from the general rule
  is invisible at a scale of one, which is the only scale a12 swept, and wrong at the other three.
- **The translate SUBTRACTS on the horizontal and ADDS on the vertical**, at every scale, inside the bracket.
- **The slope's cross coordinate keeps its own half pixel**: `cross - dstCross + 0.5` counted from the bottom
  row, `cross + 0.5` counted from the left column. The two axes are mirrors, which is why the horizontal's is
  negated.
- **The horizontal's scale is anchored at the near edge and the vertical's at the DESTINATION'S FAR edge.**
  The vertical's constant is `dstAlong*(1 - 1/scale)` - five pixels at a scale of two on a five-row
  destination - which is why an `along` ladder one pixel wide can never express it and why the first two
  versions of this search found nothing on the vertical off a scale of one.
- **`multiply by the stored reciprocal`, not `divide by 1/reciprocal`.** The two are identical at 1, 2, 0.5
  and 0.25, where the reciprocal is exact; **at 0.75 only the multiply survives.** It is also what the
  release's own worker does with the `1.0/scale` it keeps beside `floor` of it.
- **0.75 closes on the horizontal and NOT on the vertical.** Sixteen of sixteen shapes on the horizontal, at
  every translate and slope swept; **zero of sixteen on the vertical**. That is the one (scale, axis) pair of
  the ten this measurement leaves open, and it is where the 28-of-624 residual has to live.

  **A correction to the correction, and it may be the residual's cause.** The claim above first said "no
  candidate on either axis", which the log does not support: `mapsearch.log`'s 0.75 block holds 1728 `ALL`
  lines in its horizontal half and its 16 `NO CANDIDATE` lines in its vertical half, and a first pass counted
  both halves together. So the 28-of-624 is **not** reproduced on the host's horizontal - and the one thing
  that differs between the two measurements is the DIVISOR. This search divides by **the row's own sum**; a12's
  `mapping.py` divides by **16384**, and on the guest the two are not always the same because 6.1.3's rows are
  within 5 of 16384 and at a scale of 0.25 all sixteen rows are not equal to it. a12's own table shows the two
  spellings scoring identically in every row of section B - but section B's model used the mapping this section
  has just replaced, so it scored 0 to 21 of 168 either way and **the divisor was never separated on a model
  that was right**. That makes "the row's own sum instead of 16384" the first thing to test against the 28, and
  it is what the port now does. **It is a hypothesis, not a finding**: it is one re-run of a12's own
  `mapping.py` with one constant changed, and until that run exists the residual stays named rather than
  closed.

## The arm64 header, verified on the bytes, and the host's own filter is the same shape (2026-10-04, v-tail-a13)

`d4ed12b1c` took back the arm64 "overwrite". It is re-read here from the bytes rather than taken on trust, on
the release where the earlier reading went wrong:

    REVENANT_ROOT=$PWD sh tools/corpus/disasm.sh ~/.revenant/dyld/7.0/dyld_shared_cache_arm64 \
        /Frameworks/vImage 1804addc0 1804ade00 arm64e
    0x1804addc0   stp  x10, x9,  [x0, #16]    bytes 16 and 24: floatStride, int16Stride
    0x1804addcc   stp  x11, x8,  [x0, #32]    bytes 32 and 40: phases, exponent
    0x1804adde0   madd x10, x10, x12, x13      the float table's end
    0x1804adde4   stp  x10, x13, [x0, #56]    bytes 56 and 64: the Q14 table's first byte, then the base
    0x1804adde8   sub  x8, x10, x0
    0x1804addec   madd x8, x9, x11, x8        the offset
    0x1804adf0   str  x8,  [x0, #48]          byte 48: the offset, written last

**`stp x10, x13, [x0, #56]` is bytes 56 and 64, not 48 and 56.** The Q14 table's first byte is in the object on
every release read, and nothing is computed from another field.

**And the host's own filter has the SAME shape**, which is what lets the host differential exercise the port at
all: `vImageNewResamplingFilter` on this Mac answers nine 64-bit slots at bytes 0, 8, 16, 24, 32, 40, 48, 56,
64 with the same meaning, over ten shapes (`fields.m`, `checkheader.py`):

    asked  reciprocal  lobes  numTaps fStride iStride phases offset  q14     base
      1        1          3        6      32      16      64   3184   +2160    +80
      1        1          5       10      48      32      64   5248   +3200    +80
      2        0.5        3        6      32      16      64   3184   +2160    +80
      2        0.5        5       10      48      32      64   5248   +3200    +80
    0.5        2          3       12      48      32      32   2688   +1664    +80
    0.5        2          5       20      80      48      32   4256   +2720    +80
    0.75     1.3333       3        8      32      16      64   3184   +2160    +80
    0.75     1.3333       5       13      64      32      64   6288   +4240    +80
    0.25       4          3       24      96      48      16   2480   +1712    +80
    0.25       4          5       40     160      80      16   4080   +2800    +80

`base` is `object + 80 = (object + 87) & ~15` on all ten, the arm64 value the ten iOS writers agree on.

## The identity the refusal may check, on nineteen shapes and two architectures (2026-10-04, v-tail-a13)

The offset is an OFFSET, and the arithmetic that ties the table's pointer to the object is

    offset == (table - object) + phases * int16Stride

**It holds on all nine shapes the 6.1.3 guest dumped and all ten shapes this Mac's own Accelerate handed out** -
nineteen of nineteen, two architectures, `checkheader.py`, with `numTaps >= 1`, `int16Stride >= 2` and even,
`phases` a power of two of at most 64, and the table inside `[object, object + offset)` all holding on every one.

**`offset == phases * int16Stride` is FALSE on all nineteen**, because the offset also carries the float
table's size. A refusal written that way refuses every filter the port exists to read - which is the same class
of mistake as the one v-tail-a11's first probe made when it compared the offset against a pointer, and the check
the brief spells as `phases * int16Stride == offset` has to be the identity above.

## Two properties of the release's own Q14 row the engine relies on (2026-10-04, v-tail-a13)

Over every phase of every shape the 6.1.3 guest dumped (`checkrows.py`, section D of the run log):

- **The tail past `numTaps` is zero in every row of every shape**, so summing the `int16Stride/2` the port reads
  is summing the release's own `numTaps` weights. That is what lets the divisor be "the row the port read".
- **The peak is NOT at one index.** It sits at `K0` for the first half of the phases and at `K0 + 1` for the
  second, and is **TIED at the half phase** - on all nine shapes, without exception. That is how a table with
  one index per phase carries a fractional position at all, and it is why `K0` is read from row 0 alone and
  used for every phase. A reader who measured `argmax` over every row and expected one index would conclude the
  engine's `K0` was wrong; on the 0.75 five-lobe shape even **row 0** is tied
  (`73 -431 833 -627 -1224 9564 9564 -1224 ...`), and the lowest of the two is `K0 = (numTaps-2)/2 = 5`.

## The 6.1.3 guest, the port's engine, and the header the reader got wrong (2026-10-04, v-tail-a15)

**The armv7 header's fields do NOT start at word one, and every field from `numTaps` on was being read one
four-byte word early.** The reader took field `k` at byte `k * slot` with a four-byte slot on armv7. The first
field is the DOUBLE `1.0/scale` and it is two slots wide, so field 1 landed at byte 4 - inside the
reciprocal - and the release puts `numTaps` at byte **8**, which is slot **2**. `RevenantResampling.h` now
takes field `k` at `8 + slot*(k-1)`, which on arm64 is the address `8*k` it always was.

This is invisible on a Mac, where every filter is an arm64 one, and it is why 11916 host checks and a
nineteen-shape header check never saw it. **The 6.1.3 guest saw it in one run**: the probe
(`tests/backports/device/shearprobe/`) handed `RevenantResampleFilterOf` the object `vImageNewResamplingFilter`
had just allocated and the reader refused, printing `word 1 taps 1072693248` - which is `0x3FF00000`, the low
word of the double `1.0` - and `word 7 table 0xc50`, which is byte 28, the offset. The release's own forty
bytes:

    00 00 00 00 00 00 f0 3f   byte 0   the double 1.0
    06 00 00 00               byte 8   numTaps 6
    20 00 00 00               byte 12  floatStride 32
    10 00 00 00               byte 16  int16Stride 16
    40 00 00 00               byte 20  phases 64
    06 00 00 00               byte 24  the exponent 6
    50 0c 00 00               byte 28  the offset 3152
    50 44 90 10               byte 32  the Q14 table
    30 3c 90 10               byte 36  the float table's base

With the right addresses **every identity this file already checked holds on those bytes**: the offset is
`3152 == 2128 + 64*16` and the table is `2080 == 32*65` past the base. The identities were never wrong; the
addresses they were read from were. **`offset == (table - object) + phases*int16Stride` is right on the armv7
releases as well as on arm64**, and the section above's "the offset is an OFFSET on both shapes" stands.

### What the guest says about the mapping, and it is not the host's

The probe puts the port's engine and the release's own `ARGB8888` shear over one filter the RELEASE made, at
five scales, both axes and seven translates, and names each destination sample's `(phase, base)` pair out of
each engine's OWN bytes: a source whose channel 0 carries its full value at one position along the shear and
zero at every other, with a zero backColor, makes every other tap contribute nothing, so one shear call answers
`store(row[p][j] * max / divisor)` and nothing else. Seventy cases, no case ended on a signal, and:

| | 6.1.3, this page's arithmetic |
| --- | --- |
| a scale of **one**, both axes, translate 0 | **agree, 24 of 24** - the identity v-tail-a11 measured, re-established through the identification |
| **every other scale, both axes, every translate** | **the release and the port name different pairs** |
| an arrangement of the mapping that explains every sample the release names | **none, at scales 2, 0.5, 0.75 and 0.25 on either axis.** At a scale of one `trunc` explains 7 of 7 cases on both axes; at a scale of two, one case in seven on the horizontal |
| the divisor | **it matters here.** The two divisors name different pairs on 12 of 19 uniquely named samples at a 0.75 vertical and on 13 at a 0.75 horizontal, where on this Mac they never differ |

At a scale of 0.75 on the vertical the release's phase runs **eleven sixty-fourths below** the port's and its
mapped centre advances at an average of exactly `4/3` a sample with a `+-1/192` wobble - two steps of
`1.328125` and one of `1.34375` in every three - which is why it names 21, 42, 63, 21, 42, 63 where the port
names 32, 53, 10, 32, 53, 10. **So 6.1.3's mapping is not in the family of twenty-four arrangements this
page's host measurements search, on either axis, off a scale of one.** That is the finding and it is a
negative one; the next measurement has to widen the family, not re-search the one already searched.

### And the 0.75 vertical boundary on the HOST, which is a different thing and is still open

The probe answers macOS first, and the answer narrows the boundary without closing it. Over a 24-by-9 source
into a nine-wide destination:

  * **it is the vertical alone and only at 0.75**, as before - 19 of the 19 uniquely named samples agree at
    scales 1, 2, 0.5 and 0.25 and at 0.75 on the horizontal;
  * **the tie direction is confirmed**: `ceil(frac*phases) - 1` explains all eight 0.75 vertical cases and
    **breaks a scale of 0.5**, where `frac*phases` is exactly 16 and the release names row 16. It is not the
    rule;
  * **the single-precision far-edge anchor explains all eight 0.75 vertical cases and all four exact scales
    over this destination, and is refuted by the differential**, whose destination is five along where this
    one is twenty-six: with it in, the integer family goes from 524 to **574** vertical 0.75 cases;
  * **at destination rows 18, 21 and 24 the mapped centre is EXACTLY 15.5, 19.5 and 23.5 in every arrangement
    and in both precisions**, `frac*phases` is exactly 32, and the host's own bytes name row **31**. No rule
    that is a function of `frac*phases` alone produces that and is right at a scale of 0.5 at the same time,
    **so the term still missing is in the ARRANGEMENT of the position and not in the phase.**

## The release's own position arithmetic, read instruction by instruction (2026-10-04, v-tail-a16)

**The 6.1.3 armv7 mapping is a Q32 FIXED-POINT ACCUMULATOR, and the previous four bands' search of
"arrangements" could never have found it, because no arrangement is a function of x at all.** Read with
`tools/corpus/disasm.sh` and `tools/corpus/cache-value.lua`'s own export walk, no emulator:

    _vImageHorizontalShear_ARGB8888   0x303d2865   -> worker 0x3040f220
    _vImageVerticalShear_ARGB8888     0x303d2b51   -> worker 0x30413ce8

`0x3040f220` is THUMB (`bl` from a Thumb wrapper; bit 0 of the target is the release's own marker), and
disassembling it in ARM mode gives plausible nonsense - the trap `tools/corpus/disasm.sh`'s own header
warns about, paid once here and named here so a reader does not pay it again.

### 1. The position is a 64-bit Q32 accumulator, advanced by an integer add

The vertical worker's prologue, in the release's own order (`0x30413d3c` .. `0x30413e44`):

    0x30413d3c  vldr     d11, [pc, #0x258]     ; 0x30413f98 = 4294967296.0, i.e. 2^32, read as a double
    0x30413d40  vldr     d8, [sl]              ; d8 = *(double *)filter, the release's own stored 1/scale
    0x30413d44  vldr     d10, [pc, #0x258]     ; 0x30413fa0 = 2^63
    0x30413d48  vmul.f64 d13, d8, d11          ; d13 = recip * 2^32
    0x30413d5c  vmovgt.f64 d13, d10            ; saturated at 2^63
    0x30413d64  blx     0x30436bd8             ; __aeabi_d2lz: a 64-bit integer in r0:r1
    0x30413d70  vcmpe.f64 d13, d12             ; 0x30413fa8 = -2^63, the same saturation from below

**`blx 0x30436bd8` is the compiler-rt soft-float stub for `__aeabi_d2lz`**, and the AEABI interface passes a
double in r0:r1 - which is why the code hands it the double's own bits with `vmov r0, r1, d13` and reads a
64-bit answer back. `0x30436bd8` is a 12-byte `__picsymbolstub4` inside the vImage image, at image offset
0xcabd8.

So the step is `S = (int64)(min(recip * 2^32, 2^63))`, and it is an INTEGER from then on. At a scale of 0.75
`recip` is the double 1.3333333333333333, so `S = 5726623061 = 0x155555555`.

The start, same worker (`0x30413df8` .. `0x30413e44`), with the two integers the prologue puts into `s0` with
`VDUP.32`:

    0x30413df8  vmov.f64 d17, #1.0
    0x30413e0a  vsub.f64  d18, d17, d8          ; d18 = 1 - recip
    0x30413e0e  vcvt.f64.s32 d21, s0            ; d21 = (double) s0   <- VDUP.32 at 0x30413e04
    0x30413e12  vmul.f64  d19, d8, d9           ; d19 = recip * xTranslate
    0x30413e16  vmul.f64  d18, d21, d18         ; d18 = C * (1 - recip)
    0x30413e1a  vmov.f64  d20, #-0.5
    0x30413e1e  vmul.f64  d16, d16, d20         ; d16 = -0.5 * T      <- VDUP.32 at 0x30413d9c
    0x30413e22  vadd.f64  d18, d18, d19
    0x30413e26  vadd.f64  d16, d18, d16
    0x30413e2a  vadd.f64  d16, d16, d17         ; + 1.0
    0x30413e2e  vmul.f64  d9, d16, d11          ; * 2^32
    0x30413e3c  vmovgt.f64 d9, d10
    0x30413e44  blx     0x30436bd8              ; A0 = (int64)(centre_start * 2^32)

    centre_start = 1 + recip*xTranslate + C*(1 - recip) - 0.5*T

`T` is the filter's own `numTaps` (`ldr r1, [sl, #8]` at `0x30413d84`, the armv7 header's byte 8).
**`C` is the DESTINATION'S EXTENT ALONG THE SHEAR** - `dest->height` on the vertical, `dest->width` on the
horizontal - because the wrapper passes the along count in the slot the worker reads at `0x30413e04` (the
vertical wrapper's `ldr.w r8, [r5, #8]` at `0x303d2c6e` is the destination's `height`).

### 2. The per-sample loop is an accumulator, and phase and base come out of it

The vertical worker's sample loop, `0x30414306` .. `0x3041435a`, which is the whole of the mapping:

    0x3041430c  ldr      r6, [sp, #0x68]        ; the accumulator's LOW word
    0x30414314  adds     r6, r6, r0            ; A_lo += S_lo      (r0 = S_lo, from [sp+0x74])
    0x3041431c  adcs     r1, r0                ; A_hi += S_hi + carry
    0x30414326  add.w    ip, r1, r0            ; base = A_hi + srcOffsetToROI_along
    0x30414338  ldr      r5, [sp, #0x64]       ; (numTaps + 1) & ~1, the row's own width
    0x30414344  ldr      r2, [sp, #0x34]       ; 32 - exponent
    0x30414356  lsr.w    r2, r6, r2            ; the top `exponent` bits of the 32-bit fraction
    0x3041435a  and      sl, r2, r3            ; & (phases - 1):  THE PHASE
    0x304143c4  mla      r3, sl, r5, r3        ; row = table + phase * int16Stride

**So:**

* `base` is the accumulator's own integer part, `A >> 32`, plus the caller's offset - the source index of the
  row's **FIRST** tap. The port's `base` is the source index of the row's **CENTRE** tap, so the two differ by
  `K0 = (numTaps - 2) / 2`, which is the whole of the "they disagree about the base" reading at a scale of
  one and nothing else.
* `phase = (A & 0xffffffff) >> (32 - exponent) & (phases - 1)`, i.e. **the top `log2(phases)` bits of the 32-bit
  fraction - a TRUNCATION of `frac(centre)*phases`, with no rounding and no carry.** `exponent` is the
  filter's own field (byte 24 armv7 / byte 40 arm64) and equals `log2(phases)` on every shape measured: the
  guest's 6.1.3 filter has `exponent 6` and `phases 64`.
* the horizontal is the same accumulator with the `C` term ABSENT and a per-row slope term instead
  (`0x3040f668` .. `0x3040f690`: `1 + (destRow - srcHeight)*recip*shearSlope - recip*xTranslate - 0.5*Y`),
  which is v-tail-a13's measured mirror - the horizontal anchors at the NEAR edge, the vertical at the
  destination's FAR edge.

### 3. The divisor is the WHOLE row's sum, and the store is round-half-up over 16384

`0x3041437c` sums the row's out-of-picture HEAD (`ldrsh` from the row's own base, `-base` entries),
`0x304143a0` sums its TAIL (from the in-picture window's end to `(numTaps+1)&~1`), and the in-picture loop
`mla`s the weights in. **The three together are the sum of every entry of the row**, so the divisor is the
row's own sum and not 16384 - which is what the port already does, and what the guest run settles (the two
name different pairs on 12 of 19 samples at a 0.75 vertical).

The store is `(sum + 8192) >> 14`, clamped to the channel: `add.w r3, r0, #8192` then `asr r0, r0, #14`
(`0x3040f54e` and the vertical's own store), with `+8192 == 16384/2` - round HALF UP, as the port has it.

### 4. THE PREDICTION at a scale of 0.75 on the vertical, made from that reading alone

`srcAlong 24`, `srcCross 9`, `dstAlong = ceil(0.75*24) + 8 = 26`, translate 0, slope 0, `phases 64`,
`exponent 6`. `centre_start = 1 + 0 + 26*(1 - 4/3) - 0.5*numTaps`, and `T` shifts the start by whole
pixels, so the phase sequence does not depend on it:

    along          0   1   2   3   4   5   6   7   8   9  10  11
    phase         21  42  63  21  42  63  21  42  63  21  42  63
    step in 1/64  21  21  22  21  21  22  21  21  22  21  21  22

**The twenty-one/twenty-one/twenty-two wobble is `4/3` truncated to Q32 and nothing else**: `S mod 2^32` is
`1431655765 = 0x55555555`, whose fraction is `0.3333333333` rather than `1/3`, and reading the top six bits
of that running fraction is an accumulator with a three-step cycle. Reconstructed as `base + phase/64` - which
is how v-tail-a15 read the pairs off the guest - the centre advances by `85/64, 85/64, 86/64`, i.e. an average
of exactly `4/3` with the `+-1/192` wobble a15 reported.

**The one binary in this reading that decides the third sample is whether the Q32 conversion FLOORS or
truncates toward zero.** Truncating puts `along 2` exactly on an integer and answers phase 0; flooring puts
it a hundred-millionth below and answers 63. **v-tail-a15's run says 63** (`21, 42, 63, 21, 42, 63`), so the
release's conversion FLOORS, and the port must floor too.

### 5. What this retires, and what it does not

* **It retires the twenty-four arrangements and the whole `+0.5 / -0.5` half-pixel question for the armv7
  releases.** There is no half pixel in the release's position at all: the start is
  `1 + recip*translate + C*(1 - recip) - numTaps/2`, with the `1.0` and the `-0.5*numTaps` doing what a half
  pixel does elsewhere. The `-0.5` in the port's `centre` and the `+0.5` in its `position` are a macOS
  arrangement.
* **It explains a15's "eleven sixty-fourths below the port".** The release's start fraction is `1/3` less a
  hundred-millionth and the port's is `1/2`; `32 - 21 = 11`. The offset is a CONSTANT because both sides step
  by the same `4/3` - which is why four bands of fitting never found it.
* **It does NOT close the family.** The engine, the 36 rows, the band files and the registry are untouched by
  this section: the change to `RevenantResampling.h` and `RevenantShear.h` that this reading implies is the next
  unit of work, and it is measured against the guest rather than here.

## The two open terms closed: `Y` is `numTaps`, and the Q32 conversion TRUNCATES (2026-10-04, v-tail-a17)

**The section above leaves two terms unresolved and both are now read out of the release's own instructions.
The second one REFUTES the reading above: the release does not floor, it truncates toward zero.**

### 1. The horizontal's `-0.5*Y` is `-0.5*numTaps`, and the register that holds it is `s2`

`0x3040f37a` is `vcvt.f64.s32 d16, s2` (encoding `[0xf8,0xee,0xc1,0x0b]`; the same encoding with `0xc0` instead
of `0xc1` is `vcvt.f64.s32 d16, s0`, which is what the vertical worker spells at `0x30413da8`, so the source
register is read off the bytes and not off the mnemonic). **`s2` is written 22 instructions earlier, by a
register-pair move that prints as a `d` register and not as an `s` one:**

    0x3040f2c6  ldr.w  r11, [r6, #8]      ; r11 = the filter's numTaps (the armv7 header's byte 8)
    0x3040f31a  vmov   d1, r11, r11      ; d1 = {s2, s3} = numTaps in BOTH halves
    0x3040f37a  vcvt.f64.s32 d16, s2     ; d16 = (double) numTaps
    0x3040f3ba  vmul.f64 d16, d16, d19   ; d19 = 0.5
    0x3040f3dc  vstr   d16, [sp, #16]
    0x3040f688  vsub.f64 d16, d16, d17   ; ... minus 0.5 * numTaps

So `Y = numTaps`, the filter's own field, and the horizontal's term is the vertical's term. **The reading above
was wrong about where the value comes from**: it is not "the high word of the double `vmov d16, r0, r1`
builds" - `vmov d16, r0, r1` writes `s16`/`s17`, not `s2`, and the only two writes to `s2` in the whole
7 KB worker are this `vmov d1, r11, r11` and two `vmov.f32 s2, s1` at `0x3040fb9e` and `0x30410bca`, which
are a different code path and come later. A reader grepping for `s2` in the disassembly finds only the read and
concludes the register is never set; it is set by the pair move, whose destination is printed as `d1`.

The horizontal's whole per-row start, in the release's order (`0x3040f644`..`0x3040f690`):

    d16 = (double)(destRow + 1 - dest->height) * (|recip| * shearSlope)
    d16 = d16 - (|recip| * xTranslate)
    d16 = d16 - 0.5 * numTaps
    d13 = d16 + 1.0

`|recip|` is `vorr d8, d9, d9` at `0x3040f27e` (a move that clears the sign bit) and `recip > 0` is one of the
reader's refusals, so `|recip|` and `recip` are the same number on every filter this can be. **`dest->height`
is the destination's ACROSS extent**, not a source extent: `vImage_Buffer` is
`{ void *data; vImagePixelCount height; vImagePixelCount width; size_t rowBytes }` (vImage.h:94), the wrapper
`0x303d2865` hands the worker the caller's own `&dest` unchanged (`mov r1, r11` at `0x303d29c0`, with
`r11 = r1` the wrapper's second argument), and the worker reads it at `0x3040f65e` (`ldr r4, [r0, #8]`, the
field the same wrapper uses as the destination's width) and `0x3040f664` (`ldr r0, [r0, #4]`, its height).
The vertical's `C` is the same layout read the other way round: `dest->height` is the destination's extent
ALONG a vertical shear.

### 2. The Q32 conversion truncates toward zero, and there is no adjustment on either side of it

**This section takes back the last paragraph of section 4 above** ("the one binary in this reading that decides
the third sample is whether the Q32 conversion floors or truncates toward zero ... so the release's conversion
FLOORS, and the port must floor too"). It does not floor, and the sample the paragraph names is one no
measurement can see; the arithmetic is settled in section 3 below and by the instructions here.

The stub is `0x30436bd8`, and it is followed to its target rather than named:

    0x30436bd8  ldr r12, [pc, #4] ; add r12, pc, r12 ; ldr pc, [r12]   ; a __picsymbolstub4, ARM mode
    the word at 0x30436be4 is 0x090014c8, so r12 = 0x394380ac, and the word there is 0x39263199
    0x39263199 is inside /usr/lib/system/libcompiler_rt.dylib's __text (0x39262640 .. 0x3926492b)

and that function's own code is the answer, read from its first instruction (`0x39263199 +0x87` in the
function-starts table):

    0x39263199  ubfx  r3, r1, #20, #11   ; the biased exponent out of the high word
    0x3926319c  subw  r2, r3, #1023      ; the unbiased one
    0x392631a0  cmp   r2, #0
    0x392631a2  ittt  lt
    0x392631a4  movlt r0, #0             ; |x| < 1  ->  0
    0x392631a6  movlt r1, #0
    0x392631a8  bxlt  lr
    0x392631ae  asr.w r9, r1, #31        ; the sign
    0x392631b2  bfi   r1, r12, #20, #12  ; the implicit bit
    ... the significand is shifted RIGHT into place, and the sign is applied with
        eor/eor/subs/sbc (0x3926320e..0x3926321a) -- a two's-complement NEGATE, not a decrement

**A right shift of the significand and a conditional negate is `trunc`**: `|x| >= 1` keeps the integer part and
drops the fraction, and the sign is put back afterwards, which is truncation toward zero. A floor would have
to add `2^52` to the significand before the shift (the classic soft-float floor) or decrement afterwards, and
**there is neither**: no `add`/`adds`/`fadd` on the double's bits, and no test-and-subtract on the result.
The armv7 worker does not adjust either. The value goes in and comes straight out:

    0x30413e2e  vmul.f64 d9, d16, d11     ; the start * 2^32
    0x30413e32  vcmpe.f64 d9, d10        ; 2^63
    0x30413e3c  vmovgt.f64 d9, d10      ; saturate from above
    0x30413e40  vmov r0, r1, d9          ; the double's own bits, the AEABI soft-float interface
    0x30413e44  blx 0x30436bd8           ; the int64 comes back in r0:r1
    0x30413e48  vcmpe.f64 d9, d12        ; -2^63
    0x30413e54  it mi
    0x30413e56  movmi r0, #0            ; saturate from below
    0x30413e5a  movmi r1, #2147483648
    0x30413e62  mov r4, r0              ; and r4 IS the accumulator's low word
    0x30413e6e  str r1, [sp, #132]       ; and [sp,#132] IS the accumulator's high word

**The 7.0 arm64 worker says the same thing in one instruction of its own**, with no helper and nothing to
resolve: `fcvtzs x8, d0` at `0x1804a59c0` on the start (`0x1804a59ac` multiplies by `2^32`, read from the
literal pool at `0x1805a2208`, and the two saturation compares bracket it) and `fcvtzs x11, d5` at
`0x1804a58f0` on the step. `FCVTZS` is defined by the architecture as rounding toward zero. Its start is the
same expression in the same terms: `fmul d0, d1, d0` (recip * translate), `fadd d0, d0, d7` (+
`destExtent * (1 - recip)` from `fsub d16, d6, d1`), `fmul d5, d5, d7` with `fmov d7, #-0.5` (-
`0.5*numTaps`), `fadd d0, d0, d6` with `d6 = 1.0`, `fmul d0, d0, d2` (* `2^32`), `fcvtzs`, and
`add x8, x3, x27, asr #32` for the base - the caller's along offset plus the accumulator's integer part, with
no `K0`, exactly as the section above read on armv7.

### 3. The measurement that appeared to settle the floor cannot, and where it went wrong

The section above reasons that a15's run "answers 63" at `along 2` of a 0.75 vertical, and concludes the
release floors. **It does not, and the run cannot see the sample the two spellings differ on.** From a15's
own guest log (`v-tail-a15`'s `tests/backports/device/shearprobe/run/run.log`, the 0.75 vertical, translate 0):

    along 0 boundary 0 fracPhases 32.000000000000227 BLANK release=ambig153(0:-5,0:-4,0:27,1:-5,1:-4,1:27)
    along 1 ... BLANK ...
    along 2 ... BLANK ...                    <-- the one sample trunc and floor disagree on
    along 3 ... BLANK ...
    along 4 ... AMBIG ...
    along 6 boundary 0 fracPhases 32.000000000000114 DIFFER release=21:-1 port=32:-1
    along 8 boundary 0 fracPhases 10.666666666666742 DIFFER release=63:1 port=10:2

**`along 2` is one of the four BLANK samples of that case** - the row is out of the picture there, so no pair
can be recovered from the release's bytes at all. And the sequence `21, 42, 63` has period three, so it is
the same whichever sample it starts at: the named samples begin at `along 6`, and by then the two spellings
have long since agreed. The 19 named pairs of that case are identical under both.

Scored over **every** uniquely named pair in a15's whole run - 70 cases, five scales, both axes, seven
translates including the off-grid 1/128, 1210 pairs in all - the reading above, with the conversion
truncating, reproduces the release on **1210 of 1210**; with it flooring, on **1205 of 1210**. **The run
decides it, against the floor**, on five samples the release names and the floor gets wrong:

    horizontal scale 0.75 translate 1     along 1   release phase 0 base 0    floor says 63, -1
    horizontal scale 0.75 translate -1    along 2   release phase 0 base 4    floor says 63,  3
    horizontal scale 0.75 translate 0.5   along 2   release phase 0 base 2    floor says 63,  1
    horizontal scale 0.75 translate -0.5  along 1   release phase 0 base 2    floor says 63,  1
    horizontal scale 0.75 translate 1/128 along 2   release phase 42 base 2   floor says 41,  2

The section above used a different sample - the vertical's `along 2`, which is BLANK - and so rested on a
sample no measurement can see. The five samples where the two spellings differ *in that vertical case* are
`along 2` (translate 0), `along 1` (translate 1), `along 3` (translate -1), `along 1` (translate -0.5) and
`along 3` (translate 1/128), and all five are among the 737 blank or ambiguous samples of the run. That is
why the floor looked settled on the vertical and is refuted on the horizontal: on the vertical the knife edge
falls where the picture does not reach, and on the horizontal it falls one sample later, where it does.

**So: `A0 = (int64)(start * 2^32)` with C's own truncating cast, which is what the release does. A port that
floors here is wrong at five of the release's own answers and right at the other 1205.**

### 4. The whole position, as the release computes it

    vertical     A0 = (int64)((1 + recip*t + C*(1 - recip) - 0.5*T) * 2^32)      C = dest->height
    horizontal   A0 = (int64)((1 + (row + 1 - dest->height)*recip*slope
                                 - recip*t - 0.5*T) * 2^32)                        per destination row
    step           S = (int64)(recip * 2^32)
    first tap        = (A >> 32) + alongOffset
    centre tap       = first + K0,  K0 = the row's own peak index (taps-2)/2 on every shape measured
    phase            = ((A & 0xffffffff) >> (32 - exponent)) & (phases - 1)
    A(along)         = A0 + along*S

with every `(int64)` a C cast, i.e. truncation toward zero. **There is no half pixel anywhere in it**: the
`1.0` and the `-0.5*numTaps` are what a half pixel does in the port's arrangement, and the `- 0.5` and
`+ 0.5` the port carries are macOS's. **The engine, the 36 rows, the band files and the registry are still
untouched by this section**: it is the reading, and the change that follows from it is measured on the guest
before it lands.

### 5. Where macOS's own vImage differs from it, named case by case

The host differential (`tests/backports/host/shear/run.sh`, the four band files built with the package's own
`-Os -Wall` line) is the second opinion, and with the engine carrying the arithmetic above it is RED - as it
has to be, because it compares the port against **macOS**, and the two are no longer the same mapping. Every
number here is from the run made after the last change to the engine:

    11916 checks, 22652 failures
    the port and the host differ        9443 lines
    the port and this file's own loops  13209 lines   (the harness models the HOST, so this is the same
                                                          difference said twice, not a second defect)
    of the 9443: 2353 at slope 0, 7090 at a non-zero slope
    the 2353 by scale: 0.25 504, 0.5 504, 0.75 504, 1 337, 2 504

**Three distinct places, and they are three different things:**

1. **The start fraction.** At a scale of 0.75 the release's start fraction is `1/3` less a hundred-millionth
   and the port's answer is the `21 42 63` cycle; macOS's own start fraction is a hair under `1/2`, and
   v-tail-a16's host run measured macOS's own row there as **31 where the release names 21**, on both axes.
   One phase in 64, on whichever sample lands on the knife edge - 504 checks' worth at 0.75, every scale-0.75
   case of both axes.
2. **The anchor, and with it a whole half pixel.** macOS's start is `position*recip + C*(1 - recip) - 0.5`
   with `position = along + 0.5`, so the `+0.5` and the `-0.5` cancel only at a scale of one. The release's is
   `1 + C*(1 - recip) + recip*t - 0.5*numTaps` with no half pixel anywhere, and **the two are not one pixel
   apart at a scale of two, they are one pixel apart**: at a scale of two on the horizontal the release's first
   tap is at -2 and its peak sits on source 0 (the identity), and the 6.1.3 guest names `(phase 0, base 0)`
   there; macOS's centre is `-0.25`. The host's own bytes name something else again:
   `FAIL ... translate 0.0078125 slope 0 scale 1 ... the port and the host differ at byte 0 of a 9x5 buffer,
   1 against 216`.
3. **The divisor, at a scale of one.** With the identity mapping on BOTH sides - a scale of one, translate 0,
   slope 0, where the port's peak weight over its own row sum is exactly 1 and the port reproduces the source
   value - macOS's stored value is `250` where the port's is `255`:
   `FAIL vImageVerticalShearD_ARGB16S sweep 9x5 into 9x5 offsets 0,0 translate 0 slope 0 scale 1 flags 0x4:
   the port and the host differ at byte 8 of a 9x5 buffer, 250 against 255`. That is a15's "the divisor matters
   on this release and does not on the Mac" read the other way round: macOS divides by 16384 and its own rows
   do not sum to it, while this engine divides by the row's own sum, which the 6.1.3 guest confirms.

**The non-zero-slope cases, 7090 of them, and the honest state of each axis's slope term:**

* The **horizontal**'s slope term IS the release's and is in the reading above:
  `(row + 1 - dest->height) * recip * shearSlope` at `0x3040f668`..`0x3040f690`. The guest run carries slope 0
  throughout (P15), so this term is read and unmeasured.
* The **vertical**'s slope term is NOT the release's and is named as such in `RevenantShear.h`. The 6.1.3
  vertical worker reads its `shearSlope` and BRANCHES on it at `0x30413d38`: at zero it falls into the path
  this engine implements, which has no cross term at all, and at anything else it jumps to `0x304151e4`,
  which spills its state and CALLS rather than forming a start. That path is not read, so the term carried
  there is macOS's own measured one, in the only units this accumulator has. **It is the one term of the
  mapping that no measurement of any release covers, and every shear row says so.**

**Which engine wins.** The release, and the rows are written for it: the coordinator's ruling on v-tail-a15 is
"the 6.1.3 guest run is item 1; the release wins over macOS", and the guest run answers 1210 of 1210 named
destination samples against the release where the host differential answers 9443 failures against macOS on
every shape it sweeps. **A host differential in this family is not a gate; it is the map of where the host's
own mapping differs, and this section is that map.**
