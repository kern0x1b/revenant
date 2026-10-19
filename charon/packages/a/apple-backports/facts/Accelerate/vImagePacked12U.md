# The packed twelve-bit unsigned conversions of vImage, iOS 7.0

**Both** `vImageConvert_12UTo16U` and `vImageConvert_16UTo12U` in `Accelerate/vImagePacked12U7.m`, held against
the host's own vImage in `tests/backports/host/vimagepacked12u`: **20514 checks, zero failures.** Every width from
1 to 17 - odd and even, which is what a row of two pixels to a triple makes load-bearing - in both directions, and
then both scales swept as values: all 4096 twelve-bit values and every fourth value of the sixteen-bit range.

## The layout, and the odd width the header does not answer

Twelve bits is one and a half bytes a pixel. The header prints the algorithm for both directions and **both
consume three bytes per two pixels**:

```
t0 = (srcRow[0] << 16) | (srcRow[1] << 8) | srcRow[2];
t1 = t0 & 0xfff;  t0 >>= 12;
destRow[0] = scale(t0);  destRow[1] = scale(t1);
```

which answers an even width and says nothing about a half-pair. So the layout was measured instead of read: set
**one source bit at a time** and read every destination pixel, at every width from 1 to 17, and see which source
bit produced which destination bit.

**The layout is regular and an odd width needs no case of its own.** Pixel `p` is the twelve bits at bit offset
`12 * p` of the row, counted from the high-order bit of its first byte — triple `p / 2`, offset `(p % 2) * 12`
within the triple, big endian, the first pixel of a pair in the high half of the twenty-four. The measured map
agrees at every width:

| width | row bytes | where the last pixel lands |
| --- | --- | --- |
| 1 | 3 | pixel 0 at bits 0–11; bits 12–23 unused |
| 2 | 3 | pixels 0 and 1 fill the triple exactly — **no padding at an even width** |
| 3 | 6 | pixel 2 at bits 24–35, the *first* pixel of the second triple |
| 17 | 26 | pixel 16 at bits 192–203, the first pixel of the ninth triple; 4 bits of the 26th byte unused |

A row is `(width + 1) / 2 * 3` bytes, so an odd width is padded up to a whole triple, and **an even width is not
padded at all** — measured, and it is the thing the two failure modes below both turn on. The padding of an odd
row's last triple is read by the loop and belongs to no pixel.

## The scales, swept as values

| direction | rule | measured |
| --- | --- | --- |
| 12U to 16U | `(t * 65535 + (t << 4) + 2055) >> 12` | **all 4096 values, 0 differ**; 0→0, 1→16, 2→32, 3→48, 4→64, 4095→65535 |
| 16U to 12U | `(t * 4095 + 32767 + (t >> 4)) >> 16` | every seventh value of 65536, 9362 points, **0 differ** |

Both are written in the header's own form, not in a form of our own. A form of our own that happens to agree on
the values we checked is not the same thing as the header's rule, and the whole `0x7d` episode in
`vImageIndexed.md` was a form of our own that agreed at one width and not at two.

## A single-bit map cannot measure a scale, and this band wasted a probe on it

The obvious instrument — set one source bit, record which destination bits move — is **right for the layout and
wrong for the scale**, and the second probe in `runs/12u` is the one that shows why. A twelve-to-sixteen
expansion sets up to three destination bits from one source bit, so a map with one source bit per destination bit
silently keeps only the *last* of them and prints a bijection that does not exist. The map's output for a single
source bit in the low nibble looked like a bit-reversal; it is not a bit-reversal, it is three output bits with
two of them overwritten by a later probe.

**So: a bit map for a layout, a value sweep for a scale.** The layout here is genuinely one-to-one and the map
settled it in one pass. The scales are swept as values, and the 12U→16U one is swept exhaustively because 4096
values cost nothing.

## The bug the reverse direction's case found, and why the case was missing

`vImageConvert_16UTo12U` sat uncarried for a while on the honest grounds that the differential could not hold it,
and the reason was **two bugs in this band and one in the port** - not a difference in the host's answers that
survived. With the case written properly, the port's packed row came into exact agreement with the host's at
every width, and what it had been doing was writing the first pixel of every triple as zero. The defect was in
`charon_packed12_put`:

```c
pair = column % 2 ? ((pair & 0xf000u) | (value & 0xfffu))        // four bits, not twelve
                  : ((pair & 0xfffu)  | ((value & 0xfffu) << 12)); // twelve bits, in the wrong half
```

A twenty-four-bit triple is **two twelve-bit pixels, and each branch's mask must be the other's complement
inside the twenty-four** - twelve bits each. The odd branch preserved `0xf000`, four bits, so writing pixel 1
destroyed three quarters of pixel 0; and the even branch preserved the low twelve, which are pixel 1's, so it
kept nothing of pixel 0. The port wrote **0x00 for the first pixel of every triple** where the host wrote 0x100,
0x300 and 0x500. It is the same shape as the sub-byte group's `0x7d`: a mask narrower than the field it is meant
to preserve, and the host's hexdump is what settled it.

**Two harness bugs were in the way first, and both are the same slip as the eight-byte pattern table.** The case
asserted where an odd row's padding was - "the low nibble of the last byte" - which is not what a
two-pixels-to-a-triple layout puts there, and it flagged byte 0, which is real data. And the case wrote the
second row's source values at `row * width` when a sixteen-bit source row is `width * 2` bytes, so row 1's data
landed over row 0's tail. **The oracle settles the padding, so the padding rule is not ours to assert**: the
whole row is compared, host included, with the destination pre-filled, and a port that writes a padding bit or
misses one the host fills fails either way.

## A value sweep, because a fixed set of input values does not settle a scale

Dropping the `+ (t >> 4)` bit replication from the 16U-to-12U rule **changed no answer in the width table** and
survived a full mutation sweep. The seventeen values each width used simply never landed where it matters: the
rule is a quotient, and a quotient's rounding is only visible where a carry crosses a boundary, so the input has
to be swept. The differential now sweeps **all 4096 twelve-bit values and every fourth value of the sixteen-bit
range** through a full triple and compares all of it - 20514 checks in total - and both scale mutations are
caught: dropping the bit term fails 1024, flooring the quotient fails 16397.

## What is not here

The packed 12-bit rows are the only ones in the family that are not one element wide. `vImageConvert_12UTo16U` and
`16UTo12U` are the two, both at 7.0, and the pixel group carries the other 12U consumers as an eight-bit
conversion with a scale.

**One mutation survives, and it is not a gap in the suite.** The even branch's mask is dead code for ascending
columns - pixel 1 has not been written yet when pixel 0 is - so narrowing it fails nothing. It is defensive
rather than wrong, and it is what makes the function correct if the loop ever runs downward. The comment says so
rather than the mask being removed to make a mutation fail.

## What is not here

The packed 12-bit rows are the only ones in the family that are not one element wide: `vImageConvert_12UTo16U` and
`16UTo12U` are the two, both at 7.0, and the pixel group carries the other 12U consumers as an eight-bit
conversion with a scale.
