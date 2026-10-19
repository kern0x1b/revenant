# The pixel conversions of vImage, iOS 7.0 and 8.0

Sixteen names: the four the first delivery carried - `vImageConvert_RGB565toBGRA8888`,
`vImageConvert_BGRA8888toRGB565`, `vImageConvert_ARGB16UtoRGB16U` and `vImageConvert_ARGBFFFFtoRGBFFF` - and the twelve
added since, which are the whole of the 5/6/5, 5/5/5/1 and 1/5/5/5 shapes: `vImageConvert_RGB565toRGBA8888`,
`vImageConvert_RGBA5551toRGBA8888`, `vImageConvert_RGBA8888toRGB565`, `vImageConvert_RGBA8888toRGBA5551` at 7.0, and
`vImageConvert_RGB565toRGB888`, `vImageConvert_ARGB1555toRGB565`, `vImageConvert_RGB565toARGB1555`,
`vImageConvert_RGB565toRGBA5551` and `vImageConvert_RGBA5551toRGB565` at 8.0. The two that drop an alpha channel were the
first four; iOS 6 has `vImageConvert_RGB565toARGB8888` and `vImageConvert_ARGB8888toRGB565` from iPhone OS 5 but neither of
the BGRA pair, and neither of the two that drop an alpha channel.

Read from: `Conversion.h` of SDK 16.4, which writes the arithmetic of the two words out; the host's own Accelerate, compared byte
for byte in `tests/backports/host/vimagepixels` over the corners of each word; the release's own armv7 caches for which release
first exports each name.

## The arithmetic

The header gives it exactly, and it is integer arithmetic with no rounding left to choose:

    red   = (5 bit red   * 255 + 15) / 31
    green = (6 bit green * 255 + 31) / 63
    blue  = (5 bit blue  * 255 + 15) / 31

on the way out of a 565 word, and

    red   = (8 bit red   * 31 + 127) / 255
    green = (8 bit green * 63 + 127) / 255
    blue  = (8 bit blue  * 31 + 127) / 255

on the way in, packed as `(red << 11) | (green << 5) | blue` into a word of the machine's own order. A BGRA8888 pixel
is blue, green, red, alpha in that order in memory, and the alpha of a 565 word is the byte the caller passes.
`vImageConvert_ARGB16UtoRGB16U` and `vImageConvert_ARGBFFFFtoRGBFFF` drop the first channel of each pixel and move the
other three down, which the header says works in place, so the port moves rather than copies them.

Unlike the Y'CbCr conversions beside them, these four agree with the system on every byte: the differential's count of
bytes that differ did not move by one when they were added to it. There is no floating point in them to differ in.

## The shapes, and what the header gives for each

`Conversion.h` writes the arithmetic of a 5/6/5 word and of a 5/5/5/1 word out, and they are the same rule both ways: a channel
goes up to eight bits with `(bits * 255 + half) / max` and comes down with `(bits * max + 127) / 255`, where `max` is 31 for five
bits and 63 for six. A one-bit alpha is that bit times 255 going up and `(bits + 127) / 255` coming down, which is 0 or 1.

For the conversions **between** a 5/6/5 word and a 1/5/5/5 or 5/5/5/1 word the header gives no formula at all - it says only
"first at high bitdepth, then convert to lower bitdepth" - and that composition is what the four below are, and it is **not** a
bit shift: the green of a 5/6/5 word is six bits and of the other two five, so going up from 1555 the green goes through a
five-bit expansion and coming down it goes through a six-bit narrowing (and the other way round for 565 to 5551). Measured
against the host over the corners of each word, all four agree with it byte for byte.

**Two of them take a dither.** `vImageConvert_RGB565toARGB1555` and `vImageConvert_RGB565toRGBA5551` have an `int dither`
parameter between the destination and the flags, and this port records it and answers for a dither of zero, which is what the
differential asks. The twelve `*_dithered` conversions of the wider family are **not blocked**, and an earlier version of this
page said they were, which was wrong: the host's dither was measured rather than assumed. Run over the same input,
`vImageConvert_PlanarFtoPlanar8_dithered` answers **byte for byte identically on eight consecutive runs**, with a dither of zero
and with a dither of one - so the host's dither is a *fixed pattern* and not noise that moves between calls, and a port can
recover it from the host's output rather than merely match its statistics. What the next measurement reads off is the pattern
itself: a constant input across a long row gives the rounded value plus a position's offset, and the set of those offsets and
their period are what a port has to carry. The probes are `probe-dither3.m` and `probe-dither4.m` in
`.agent-work/runs/vimage/`.

**The sixteen-bit interleaved conversions are not fixed repacks.** The ten names of that shape -
`vImageConvert_ARGB16UToARGB8888`, `ARGB8888ToARGB16U`, `ARGB8888ToRGB16U`, `RGB16UToARGB8888`, `RGB16UtoARGB16U`,
`RGB16UtoBGRA16U`, `RGB16UtoRGBA16U`, `ARGB16UtoRGB16U`, `BGRA16UtoRGB16U` and `RGBA16UtoRGB16U` - are the *general*
channel-permuting converters: the four with a `permuteMap` and a `copyMask` take a background colour as well, and the other six
take an alpha buffer, an alpha value and a `premultiply` flag. So each is a permute, a fill from the background and a
premultiply rather than a move, and `Conversion.h` does document the arithmetic - `(alpha * rgb[i*3+0] + 32767) / 65535` is the
premultiply rule for these and belongs to them, which an earlier reading of this page mistook for a neighbouring function's.
They are not in this group because each is a permute with a caller-supplied map rather than a fixed layout, and that is a
different piece of work from this one's.

## The refusals

They are the system's own, and the differential checks each against it. A destination larger than the source is
`kvImageRoiLargerThanInputBuffer` in all four. The header's own comment above the 565 expansion says
`kvImageBufferSizeMismatch` there; the system does not, and the differential caught the port agreeing with the comment
rather than with the release, so the port answers what the release answers. A flag outside the set the header lists is
`kvImageUnknownFlagsBit`; and `kvImageGetTempBufferSize` does no work and answers zero, as the header says, for the two
that take it.
