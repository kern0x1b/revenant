# The indexed and sub-byte planar expansions of vImage, iOS 7.0

`vImageConvert_Planar1toPlanar8` and the three indexed expansions in `Accelerate/vImageIndexed7.m`, of the twelve
names the 26.2 `Conversion.h` declares for this shape. Measured from the release's own armv7 caches, 7.0 is the
first held release that exports all twelve, so the file holds the API of one release.

**The whole `vImageConvert_*` family is 140 C functions.** The earlier claim of 157 counted eleven
Objective-C `vImageConverter` selectors and six declarations the corpus does not carry. The corpus is
authoritative: `coordination/corpus/sdk-26.2-surface.tsv` has 163 rows matching `vImageConvert`, of which 140 are
the C functions. This file is six of them; `facts/Accelerate/vImagePlanar.md` and `facts/Accelerate/vImageAlpha16.md`
carry the rest of the group's shape, because the family is weeks of one band and the extra workers on the
framework take it in parallel.

Every answer is the host's own vImage, compared byte for byte by `tests/backports/host/vimageindexed` over **six**
packed rows, at a width of 19 pixels - which at one bit is three bytes with five bits of the last byte unused - and
over **two rows** with the second the complement of the first, so the row-to-row stride is exercised. The
differential gives each side its own destination and compares the status and every byte of both.

**The six patterns, and why two of them exist.** All zero, all one, the even pixels set, the odd pixels set, 0xb8
and 0x93. **The first four cannot separate a bit order from its reverse at two and four bits a pixel**, which is a
correction: 0xaa is `10 10 10 10` at two bits and 0x55 is `01 01 01 01`, so every pixel holds the same level
whichever end of the byte the read starts from, and a reversed group order reads an identical row. At one bit a
pixel the two become genuinely alternating, which is why they fail a reversed read there and only there - measured:
reversing the shift at `vImageIndexed7.m:79` failed 4 of the 24 checks, all four at one bit, and the suite was
green at two and four.

0xb8 and 0x93 are asymmetric under a group reversal at every width. At two bits 0xb8 is `10 11 10 00`, so a
reversed read gives 0, 2, 3, 2 against the forward 2, 3, 2, 0; at four bits 0x93 is `1001 0011`, giving 3, 9 against
the forward 9, 3; and each is asymmetric at the other two widths as well, and inside its colour table's index
range at all three. **With both added, the same reversal fails 16 of 36** - every one of the six rows, at two and
four bits as well as one. The values are the header's arithmetic and not a coincidence: at four bits the port's
reversed read of 0xb8 gives 0xbb where the host says 0x88, which is 11 × 17 against 8 × 17, and of 0x93 it gives
0x99 against 0x33, which is 9 × 17 against 3 × 17.

Both loops read their patterns from **one table** in the differential. Two separate lists is how the plain
expansions gained a pattern the indexed ones did not, and a pattern only half of the rows pose is a pattern half
the rows are untested on.

**The host reads a sub-byte source row packed, whatever `rowBytes` says.** Widening the stride of a one-bit source
from its packed three bytes to six changes every answer - the host's pixel 0 of an all-one row goes from 0xff to
0x7d, and an all-zero row at four bits answers 0 for its first sixteen pixels and 0xd1 for its sixteenth. That is
the header's "Sub-byte indexing of scanlines is unsupported, because the data and rowBytes fields of the buffer
are specified in whole bytes" taken literally: a strided sub-byte row is outside what the release answers, so the
differential packs its rows and tests the stride *between* them, which is the part that is defined.

The mutations, so that the coverage is not a claim: the bit order reversed inside the byte, the multiplier halved,
the table indexed the wrong way round, and the source row taken without its stride each fail between 3 and 4 of the
8 checks; and a read clamped to the first four bytes is *inert* here, because a one-bit row of 19 pixels is three
bytes and the clamp never bites.

## What the header says, and what the port does

- A source narrower than a byte is **big endian within the byte**: "the low-indexed pixel is in the high-order
  bits of the byte". Widths are in pixels and `rowBytes` in whole bytes, so a scanline may end in the middle of a
  byte and the unused bits of the last byte are not read.
- Expanding multiplies: Planar1 by 255, Planar2 by 85 and Planar4 by 17 - the `(bits * 255 + half) / max` rule
  the delivered pixel group uses, with no rounding step because there is none to do.
- An indexed expansion looks the index up in the caller's colour table and writes that byte.
- The refusals are the release's own and the same ones the pixel group answers: a flag outside the set the
  header lists is `kvImageUnknownFlagsBit`, `kvImageGetTempBufferSize` does no work and answers zero, a NULL
  buffer or a NULL colour table is `kvImageNullPointerArgument`, and a destination larger than the source is
  `kvImageRoiLargerThanInputBuffer`.

## What is delivered and what is not

**Delivered and byte-exact: all six expansions** - `vImageConvert_Planar1toPlanar8`, `Planar2toPlanar8`,
`Planar4toPlanar8` and the three indexed forms at one, two and four bits. Twenty-four checks over four packed
patterns, two rows whose contents differ, and a width that ends mid-byte.

**The anomaly that was measured against the host and was this band's harness, not the host.** An earlier
version of these facts said the host's two- and four-bit forms do not follow the header's bit order, on the
strength of 0x7d and 0xd1 where the packing says 0xff and 0. Three checks, in the order the owner asked for
them:

- **The hexdump.** The `vImage_Buffer` and the bytes it points at, immediately before the call, over all four
  patterns and all three widths: the host answers exactly the header's - 0xff and 0x00 for an all-one and an
  all-zero row at one bit, two and four, and 0xff/0x00 interleave for the even and odd patterns at one bit.
- **AddressSanitizer.** It named the defect, and the defect was ours: a four-bit row of nineteen pixels is
  **ten** bytes and the probe's pattern table was **eight**, so the probe's own `memcpy` read two bytes past the
  table and the answers were whatever followed it. With the table widened, all twelve cases match the header
  and ASan reports nothing.
- **The width's unit.** The host wants `width` in pixels, as the header says: handing it a width in bytes is
  *refused*, with `kvImageRoiLargerThanInputBuffer` (-21766). And a sub-byte source row is read packed, whatever
  `rowBytes` says - widening a one-bit row's stride from three bytes to six changes every answer - which is the
  header's "Sub-byte indexing of scanlines is unsupported" taken literally. The differential therefore packs its
  rows and exercises the stride *between* them, which is the part that is defined.

**All six expansions are now carried, and 0x7d and 0xd1 were this band's own multiplier.** They were read for
a long time as the host's answers, and the differential that printed them never said otherwise - it put the
port's byte first and the host's second, and the two were read the wrong way round. The host's answers, from
the hexdumps above and from `probe-rows2`, are 0xff for an all-one row and 0x00 for an all-zero row at one,
two and four bits, over two rows whose contents differ, and the packed row in `probe-rows2` is printed next
to the output so the read can be checked by eye.

The two constants are this file's scale, `255 >> (bits - 1)`, truncating at a byte:

| width | the shift gives | widest packed value times it | truncated to a byte |
| --- | --- | --- | --- |
| 1 bit | 255 >> 0 = 255 | 1 * 255 = 255 | **0xff, right** |
| 2 bits | 255 >> 1 = 127 | 3 * 127 = 381 | **125 = 0x7d** |
| 4 bits | 255 >> 3 = 31 | 15 * 31 = 465 | **209 = 0xd1** |

The rule the header prints divides the maximum value into 255 - 255 / (2^bits - 1), which is 255, 85 and 17.
Both divisors divide 255 exactly, so there is no rounding to argue about. **The one-bit form was byte-exact
throughout, which is what made the fault look like a host defect confined to the two wider forms**: the shift
happens to be the right answer at one bit and at no other width, and the two- and four-bit *indexed* forms -
which share the same read and the same lookup, and not the scale - agreed with the host all along.

Restoring the shift form now fails 8 of the differential's 24 checks - exactly the 8 that were failing - and
five further mutations fail 12, 4 and 4 of them: the multiplier one lower, the source row taken without its
stride, the bit order reversed inside the byte, and the colour table indexed the wrong way round.

**How the reading went wrong, since the same slip recurred three times in this file.** The 0x7d came from a
probe whose pattern table was eight bytes where a four-bit row of nineteen pixels is ten; the 0x7d then came
from the port, above; and a third probe called neither function at all, because it declared its setup helper
and never called it, and both functions agreed on the zero buffer they were handed. Two rules came out of it,
both mechanical: **a pattern table is indexed per pixel, so it is at least as wide as the row** - AddressSanitizer
finds the first one and not the second - and **a differential that prints the port's byte first and the host's
second must be read in that order, because the difference is the only thing it is reporting.**

## The other direction, and the dither, which is no longer the blocker it was

The three `Planar8toPlanarN` and three `Planar8toIndexedN` narrowings take a `dither` argument, and that is a
separate axis with its own measurements (probes `probe-dither-refusal.m` and `probe-dither-table.m`):

- **A dither the enumeration does not name is refused, and the code is `kvImageInvalidParameter` (-21773)** -
  measured for -1, 5, 6 and 7. So `kvImageConvert_DitherFloydSteinberg` and `kvImageConvert_DitherAtkinson` are
  refused by the host too, and refusing them is the answer rather than a gap.
- **`DitherNone` is the nearest representable value**, which the header prints as the same shape the sixteen-bit
  narrowing uses: `((value * max) + 127) / 255`.
- **The ordered modes are reproducible within a process.** `kvImageConvert_DitherOrdered`,
  `DitherOrderedReproducible` and the two shaping options all answer 0, and two consecutive calls over the same
  row give the same bytes - so the noise is a fixed table, not the per-call randomisation the header's wording
  describes, and it is readable from a constant row, which is how the earlier "the dither is unreproducible"
  note in `vImagePixels.md` is now superseded for these six.
- **The noise shows where the destination has room for it.** Over a ramp of all 256 values, a one-bit and a
  two-bit narrowing answer the same as no dither at all, and a four-bit one does not: dither 1 gives
  `0,0,0,0,0,0,1,1,0,1,1,1` where dither 3 gives `0,0,0,0,0,0,1,0,1,0,1,1`. Reading the table needs
  inputs *at the level boundaries* rather than a ramp.

So the dithered shape is a table to read and an addition to apply before the rounding, and both are measured
down to the numbers. It is the next row of work with these names.

## What has not been run

No device or emulator call test has been run for Accelerate in this port at all, so every answer on this page is
a host measurement and a device-unverified one.
