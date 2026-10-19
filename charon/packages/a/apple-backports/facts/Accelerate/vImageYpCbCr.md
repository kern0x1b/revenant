# The Y'CbCr conversions of vImage, iOS 8.0

The whole of Conversion.h's Y'CbCr surface: the two generators, and all thirty conversions between the
thirteen Y'CbCr shapes and the three ARGB types - 4:2:2 in three byte layouts and one 16-bit, 4:2:0 in two
plane layouts, 4:4:4 in five byte layouts and one 16-bit, the 10-bit v410 and v210, both directions. The
first delivery of this file carried four of them, the two 4:2:0 8-bit pairs; this one carries the other
twenty-eight, so the family is the header's whole of it.

iOS 8 made vImage's Y'CbCr conversions public. A program that names them and runs on iOS 6 does not start:
the imports are strong, and dyld stops at load. The armv7 cache of iOS 6.1.3 exports 235 `vImage` names
against the 580 of iOS 12.0, and not one `kvImage` matrix among them, so the matrices and the conversions
this file carries are the port's own arithmetic over buffers, not a call into the release.

Read from: `Conversion.h` and `vImage_Types.h` of SDK 16.5, whose per-pixel text writes out the arithmetic of
every one of these conversions and whose generator documentation gives the table of which Y'CbCr type pairs
with which ARGB type; the host's own Accelerate, compared byte for byte in `tests/backports/host/ypcbcr8`
over both matrices, the four pixel ranges of `vImage_YpCbCrPixelRange`'s own documentation at each of the
three bit depths, four permutation maps and four picture sizes.

## The opaque conversion

`vImage_YpCbCrToARGB` and `vImage_ARGBToYpCbCr` are 128 opaque bytes each, and the host fills the first of
them with a tag, the eight fields of the pixel range as `int32_t`, and then the matrix as it was given,
unscaled - which the dump in `tests/backports/host/ypcbcr` reads out. The port keeps its own layout: a tag
of its own, the matrix as given, the two scales the pixel range and the destination's own full scale give,
the two biases and the four clamps. The scales are where the bit depth lives. The header's own per-pixel
text writes

    R = CLAMP(0, ROUND_TO_NEAREST_INTEGER((Yp0 - Yp_bias) * Yp + (Cr0 - CbCr_bias) * Cr_R), max)

with `Yp` and `Cr_R` already carrying the range - which is where the generator puts it. The port keeps the
two apart, because the same matrix has to serve an 8-bit, a 16-bit and a Q12 destination, and the difference
between those three is one multiply on the scale rather than three copies of the matrix. A conversion
whose tag is not the port's is refused with `kvImageNullPointerArgument` rather than read, which is what
keeps one release's library and another's from reading each other's bytes.

## The arithmetic

The header states it in full, and the port does what it states, in `CharonYpCbCr.h`, which is shared by
all thirty. On the way out of a Y'CbCr buffer the luma and the chroma each go into the sum whole, the three
per-channel sums follow, and each rounds once to the destination's own full scale and clamps to 0 and to
that scale. On the way back the luma and chroma of a colour are the header's three dot products, the chroma
of a shared sample the mean of the block's own dot products, and each channel rounds once and clamps to the
pixel range's own limits. A block at the right or bottom edge of an odd-sized picture averages the pixels it
has, which is what the header's pseudo-code does when it adds up what is there.

Three things the header's text does not say, each measured rather than assumed, and each of which a single
value would have hidden:

- **The luma and chroma of a shared sample are averaged before the scale, not after.** CharonYpCbCr.h keeps
  the raw dot products in `charon_ypcbcr_chroma_of` for exactly this: summing answers that already carry the
  scale and the bias applies both a second time. Measured, on a 16-bit source, a Cb of 34331 where the system
  answers 34555.
- **The Y'CbCr input is not clamped to the pixel range.** With the video range clamped to [16,235] for luma
  and [16,240] for chroma, the system turns a luma of 255 into a green of 125 and one of 235 into 120, so
  the value goes into the sum whole and the only clamp is the output's - which is the `CLAMP(0, ...)` the
  header's own per-pixel text writes. The four limits are still taken from the caller's range and kept in
  the conversion, because a caller may read them back; nothing in these conversions reads them.
- **The AA8 shape's alpha is one byte to a pixel, not two bytes to a pair.** A plane of ten, twenty, thirty
  ... over an eight-pixel row puts 10, 20, 30 ... into the eight pixels' alpha channels one for one, and a
  plane narrower than the image is refused with `kvImageRoiLargerThanInputBuffer`. The header's own
  pseudo-code writes two alpha bytes and advances by two, which is a plane half as wide - so the header's
  text and the system's behaviour disagree here, and the port follows the system, which is the one a caller
  of the system has to match.

## What is measured, and what is not

**`tests/backports/host/ypcbcr8` runs 8 947 checks over the whole family and 0 of them fail.** Over the
fourteen shapes the port and the system's own vImage are compared sample for sample - 5 708 800 samples -
and 17 975 of them differ, **0.31 per cent, and none by more than the tolerance the case's own scale
sets**. That is the last bit, the header's "faithfully rounded", and the fixed-point-versus-float difference
the first delivery recorded for the 4:2:0 pair.

Six bugs came out of getting there, each found by a probe rather than by a reading, and each measured:

- **A shape whose own alpha is sixteen bit narrows it for an eight-bit destination** with the rule
  Conversion.h gives for a sixteen-bit channel to eight: `(bits * 255 + 32767) / 65535`. Measured over
  seventeen values, and it is a rounding rule and not a shift: 255 gives 1 and 511 gives 2, where a shift
  gives 0 and 1. Only `kvImage444AYpCbCr16` carries such an alpha.
- **An eight-bit source's alpha widens into a sixteen-bit shape by 257**: 32 becomes 8224, 128 becomes
  32896, 255 becomes 65535.
- **A caller's alpha arrives at the width its own signature declares.** `vImageConvert_422CbYpCrYp16ToARGB16U`
  takes a `uint16_t` and the port was handing it to a `uint8_t` parameter, so 40000 became 64.
- **A v210 unit is six pixels of one row and the unit is at `column / 6` of it.** The port read the first
  unit of a row for the whole row, and its three per-unit arrays at the column rather than the column
  modulo six, which walks off the end of all three from the seventh column on.
- **A shared sample's chroma is the mean of the block's raw dot products** (see above), and
  `charon_v210_join` was handed a `uint32_t` array through a `float *` cast, so every chroma of a Q12
  source was a float's bit pattern read as an integer.

The one tolerance that is not one, and what it is. A sixteen-bit shape stores the chroma multiplied by
`2 * (CbCrRangeMax - CbCr_bias) / 255`, which is the **ceiling** on what a one-unit difference in the
eight-bit dot product could be worth in a stored sample: **514.0** at the full sixteen-bit range and
**224.88** at the 28672 chroma range. An earlier version of this page used that ceiling as the bound, and
the reviewer's sweep is what shows it was wrong: the suite is green at 256 with the measured maximum 255, so
a bound of 514 admitted a real one-unit chroma error in silence.

So the bound is the **measured maximum plus a stated margin**, and both comparisons are **exclusive** so
that the stated limit is not itself admitted:

- the eight-bit shapes: measured maximum **1**, bound **2**, so a difference of 0 or 1 is the last bit and a
  difference of 2 is refused;
- the two sixteen-bit shapes `kvImage422CbYpCrYp16` and `kvImage444AYpCbCr16`: measured maximum **255**,
  bound **256**, so 255 is the last bit and 256 is refused.

The widest difference in the whole run is **255**, in a sixteen-bit sample, and the differential's own
summary now says where it is, what the ceiling is, and that the bound is not the ceiling.

## The ten-bit shapes: measured, and not a layout

The first reading of this was that the system's ten-bit paths read the channels from the wrong bit
positions, because the luma moved a third of the distance the header's formula gives. **A bit-by-bit
measurement refutes that**: `probe-bits.m` sets one source bit of a v410 word at a time and records which
destination bits move, and the answer is exactly the header's drawing. Cb, in bits 0-9, moves the green and
nothing else - `Cb_G` is the only non-zero coefficient it has. Cr, in bits 20-29, moves the red and the green
- `Cr_R` and `Cr_G`. Yp, in bits 10-19, moves the green and the blue - `Yp_G` and `Yp_B`, the red already
clamped to zero at every input tried. Three fields, three coefficient rows, no cross-talk.

Each field's own sweep is smooth and monotonic over the whole 0 to 1023, so nothing is being mis-shifted
either. What differs is the **scale**, and it is a scale inside the system's ten-bit code path:

| sweep | header, with the caller's ten-bit range | system | ratio |
| --- | --- | --- | --- |
| luma, `G` per unit of Yp | 0.2911 | 0.0728 | 1/4.00 |
| `G` per unit of Cb | −0.0979 | −0.0244 | 1/4.01 |
| `G` per unit of Cr | −0.2032 | −0.0502 | 1/4.05 |
| `B` per unit of Cb, at the full range | 0.2208 | 0.1263 | 1/1.75 |

and the system's luma slope is the **same 0.0728 for every pixel range the caller passes** - the ten-bit
video range and the full range both give it - where the header's is `255 / (YpRangeMax − Yp_bias)` and so
differs between them. Its *base* is the header's: the value at a zero sample is 136 with the ten-bit video
range and 0 with the full range, and the header's own value at a zero sample is 135.575 and 0.

**And it is not affine, which settles it.** Fitting the full three-by-three matrix and bias by least squares
over 10 000 random pixels per pixel range - the test that decides whether a linear rule can express it at
all - gives a worst residual of **175, 176 and 178** for the ten-bit video range, the clamped one and the
full one, and 178 for the 709 matrix. A rule that fits to within a unit would be the system's rule and the
port would use it; 175 is not that.

The period of the output in the luma field is **four**, which is a width signature rather than a scale: over
every one of the 1023 steps of Yp at Cb = Cr = 0, not one of them changes the green by 0 or 1 - the values
run 136, 111, 85, 60, 136, 111, 86, 61, 136, ... - so the low bits of one field are reaching the answer as
if the field were read wider than it is. Searching the rule space that suggests, each field read at a width
of 8 to 16 bits and divided by 1 to 16, over 2 304 rules and 3 000 random pixels, the best is **a residual of
82** - a twelve-bit luma divided by four and an eight-bit chroma divided by two. Also not that.

So the ten-bit path is non-linear, and it is neither a matrix, nor the header's formula at another scale, nor
a field read at the wrong width. It is a fixed-point pipeline whose coefficients are not published, and a
port that fitted a rule to it would be reproducing a fit with an 82-unit error and calling it the system.
Conversion.h's formula is what the port answers, and the difference is measured and stated: **63.4 per cent
of 760 480 samples**, every one of them in one of the two ten-bit shapes. The two Q12-source conversions are
the same shape - the system's luma there is 258 at a zero pixel and a channel past 1023 wraps to zero - and
are held to the same standard.

The differential is explicit about it. For those two shapes, in both directions, it holds the port to the
formula **written out a third time and independently in the test** - `reference_decode`, `reference_v410`,
`reference_v210` and `reference_of` in the differential - and counts the system's divergence rather than
asserting it. The other twelve shapes are compared against the system itself, and agree to within the last
bit.

## What it refuses

The refusals are the system's own, and the differential holds the codes to the system's. A destination
larger than the source is `kvImageRoiLargerThanInputBuffer`; a flag outside `kvImageDoNotTile` and
`kvImagePrintDiagnosticsToConsole` is `kvImageUnknownFlagsBit`; a conversion structure the port did not make
is `kvImageNullPointerArgument`; a pair the system does not convert is `kvImageUnsupportedConversion`, and
the support table is measured in both directions - the system pairs an 8-bit type with `kvImageARGB8888`
and `kvImageARGB16Q12`, a 10-bit type with the same two, a 16-bit type with `kvImageARGB8888` and
`kvImageARGB16U`, and in the other direction every type with `kvImageARGB8888`, the 16-bit ones with
`kvImageARGB16U` and the rest with `kvImageARGB16Q12`. The pixel range's own depth does not enter into it:
the system answers the same for an 8-bit, a 10-bit and a 16-bit range on every pair.

One refusal is the port's and not the system's: a permutation map that is not a permutation of 0 to 3. The
system **accepts** a map that repeats a channel, and answers `kvImageNoError`; it rejects a map that names a
channel past the third with `kvImageInvalidParameter`. The port refuses both with
`kvImageInvalidParameter`, because a map naming channel 9 is a read of four bytes of a four-byte array and a
port cannot do that. The differential prints both answers rather than asserting either.

## What is not carried

Nothing of this family. Every name Conversion.h declares for Y'CbCr is here; the four the first delivery
carried are the 4:2:0 8-bit pair and are counted in the same table.

searched: **libyuv** (BSD-3-Clause, `third_party/libyuv` under `libyuv/`) for the Y'CbCr layouts and the
ten-bit bit positions, and **nothing reused**. libyuv's `I420ToARGB` and its v210 and v410 readers were read
for the channel order and the field positions, and the layout this package uses agrees with them and with
the header's own drawing — `probe-bits.m` confirmed the drawing bit by bit against the host's answers, and
libyuv puts its fields in the same places. None of it is usable here beyond that: libyuv converts **8-bit 4:2:0
only**, and this family is 4:2:2 in three byte layouts, 4:2:0 in two plane layouts, 4:4:4 in five byte
layouts and one 16-bit, the 10-bit v410 and v210, the 16-bit v216 and y416, and a Q12 source — so four
fifths of the family has no counterpart to borrow, and the one fifth that has differs in its argument shape
rather than its arithmetic. What was taken is the *confirmation* that the bit positions are the conventional
ones, not a line of code: there is no code from libyuv in this package.

**This delivery's rows, counted on its own base `4d2e24e7`: 28.** The 28 are the Y'CbCr shapes of
`ios8ypcbcr-shapes.json` - the 4:2:2, 4:2:0, 4:4:4, v410, v210 and sixteen-bit conversions in both
directions, which the file carries and which the differential holds to the system over 8 947 checks. The ten
Y'CbCr symbols, the four matrices and the two generators of `ios8ypcbcr.json`, and the seven rows of
`ios7.json` and `ios7pixels.json`, were already in `charon` on this base and are **not** part of this
delivery: main's Accelerate band put them there. The delivery's whole Accelerate count is therefore 28 here
plus the 5 of `ios7-15-rotate90.json`, which is **33 rows** — not the 51 I have been reporting, which
counted main's eighteen as well.
