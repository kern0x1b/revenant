# The scalar fixed-point conversions of vImage, iOS 7.0 and 10.0


This group answers **4.3** as well, for the same reason and with the same measurement: `vImageCGImage7.m` and `vImageYpCbCr8.m` use `BOOL`, which is Foundation's, and at 4.3 the include chain does not bring that header in - so both now import Foundation themselves, which is what the gate found when the floor came down.
Nine entry points in `Accelerate/vImageFixedPoint7.m` (iOS 7.0) and `Accelerate/vImageFixedPoint10.m` (iOS 10.0), with
the shared half-float and saturation code in `Accelerate/CharonVImageFixed.h`. Measured from the release's own armv7 caches,
7.0 is the first held release that exports the seven of its group and 10.3.4 the first that exports the two of 10.0, so the two
files hold the API of one release each.

**Every mapping here was read off the host's own answers, not off a comment.** `Conversion.h` gives the layout of each format and not
the arithmetic between them, and the probe that read them (`tests/../.agent-work/runs/vimage/probe-fixedpoint.m`) asks the host each
conversion over a table bracketing both ends of the range; `tests/backports/host/vimagefixed` asks the same tables again, so a mapping
that drifts shows up as a difference.

## The formats

| name | what it is |
| --- | --- |
| `Pixel_8` | eight bits unsigned, 0 to 255 |
| `Pixel_16U` | sixteen bits unsigned, 0 to 65535 |
| `16Q12` | sixteen bits **signed** with twelve fractional bits: 4096 is 1.0, and the range is -8 to 7.996 |
| `Pixel_F` | a thirty-two bit IEEE float |
| `16F` | a sixteen bit IEEE **half** |

That `16F` is an IEEE half and not a format of Apple's own is the tables' answer and not the header's word: 65535 comes back as
`0x3C00`, which is 1.0 in a half, and 1 comes back as `0x0100`, which is the subnormal 256 * 2**-24 - and 1/65535 *is* 2**-16,
which is below the half's smallest normal of 2**-14.

## The mappings, each with the host's numbers

| conversion | the rule | what the host answers |
| --- | --- | --- |
| `vImageConvert_16Q12to16U` | `round(value / 4096 * 65535)`, clamped to 0..65535 | 0 -> 0, 16 -> 256, 2048 -> 32768, 4095 -> 65519, 4096 and up -> 65535, negative -> 0 |
| `vImageConvert_16Q12to8` | `round(value / 4096 * 255)`, clamped to 0..255 | 16 -> 1, 1024 -> 64, 2048 -> 128, both ends saturate |
| `vImageConvert_16Q12toF` | `value / 4096.0f`, exactly | 16 -> 0.00390625, 2048 -> 0.5, 32767 -> 7.99976, -1 -> -0.000244141 |
| `vImageConvert_Fto16Q12` | `round(value * 4096)`, clamped to -32768..32767 | 1.0 -> 4096, 0.5 -> 2048, 10.0 and 16777216.0 -> 32767, -2.0 -> -8192 |
| `vImageConvert_8to16Q12` | `(value * 4096 + 127) / 255` in integer arithmetic | 8 -> 129, 254 -> 4080, 16 -> 257, 191 -> 3068 - the only rule that gives both 8 and 254 |
| `vImageConvert_16Uto16Q12` | `(value + 8) >> 4` | 15 -> 1, 127 -> 8, 255 -> 16, 65535 -> 4096, where a plain shift gives 0, 7, 15 and 4095 |
| `vImageConvert_16Uto16F` | the half nearest `value / 65535` | 65535 -> `0x3C00`, 1 -> `0x0100`, 16 -> `0x0C00` |
| `vImageConvert_16Fto16Q12` | `round(half * 4096)`, clamped | 1.0 -> 4096, 0.5 -> 2048, an infinity -> 32767, a negative one -> -32768 |
| `vImageConvert_16Q12to16F` | the half nearest `value / 4096` | 4096 -> `0x3C00`, 2048 -> `0x3800`, 32767 -> `0x4800` |

The two integer rules are the ones a rounding of the fraction does not give: `8to16Q12` is 129 where `8 * 4096 / 255` rounded to
nearest is 129 but truncated is 128, and 254 is 4080 where rounded to nearest is 4081 and truncated is 4080 - so the host's is the
integer `(value * 4096 + 127) / 255` and nothing else. `16Uto16Q12` is the same kind of finding: a plain `>> 4` gives 0 for 15 and the
host gives 1.

The refusals are the release's own, and they are the ones the pixel group already answers: a flag outside the set the header lists
is `kvImageUnknownFlagsBit`, `kvImageGetTempBufferSize` does no work and answers zero, a NULL buffer is
`kvImageNullPointerArgument`, and a destination larger than the source is `kvImageRoiLargerThanInputBuffer`.

## `vImageConvert_16Fto16U` is not carried, and the reason is three measurements

The rule above is `round(half * 65535)` clamped, which is what the obvious reading gives. It is **not** carried, because the host's
answers for this one conversion are not stable enough to be the oracle:

1. Over a table of twenty half values in a buffer whose row is twenty elements, the host answers the whole table, and the subnormal
   `0x0200` comes back as **2** - the round of `0x0200 * 65535`.
2. Over a table of thirty-two the host answers thirty-one of them the same way and `0x0200` comes back as **1**, while its own
   `0.5` is 32768, which is a round and not a truncation. So the two answers are not one rule.
3. Asked over the same four inputs in a buffer of eight, sixteen, twenty-four or thirty-two pixels with a guard after the row, the
   host writes **one** element and leaves the rest, and over four pixels it stops the process.

A row whose oracle writes one element in one shape and the whole row in another is not a row this port can hold a differential
against, so it waits until the behaviour is understood. `tests/backports/host/vimagefixed` keeps the one measurement that does
reproduce (0.5 -> 32768 on a row of thirty-two) so the record stays checkable.

## What is not carried, and what is next

- **`vImageConvert_16Fto16U`** - as above.
- **`vImageConvert_12UTo16U` and `vImageConvert_16UTo12U`** - 12-bit values are *packed*, so a row of them is one and a half bytes
  a pixel and the two are two different shapes from the rest of this group. Measured so far: the host answers them with
  `rowBytes` set both to two bytes a pixel and to one and a half, and with the two it gives 0, 272, 4385, 8738, ... for a
  0x1111, 0x2222, 0x3333, ... input, which is not yet read off. The next step is a single-pixel row, where the two or three bytes of
  one value are exactly the ones the port chooses; `probe-12u.m` in `.agent-work/runs/vimage/` is the probe.
- The planar and interleaved group, the permuting converters and the dithered ones are the other three shapes of the conversion
  family; none of them is in this file.

## What has not been run

No device or emulator call test has been run for Accelerate in this port at all, so every answer on this page is a host measurement
and a device-unverified one.
