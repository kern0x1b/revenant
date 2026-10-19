# vImageAlpha16 — the sixteen-bit alpha placement moves

Five rows in `Accelerate/vImageAlpha7.m`, iOS 7.0, checked against the host's own vImage in
`tests/backports/host/vimagealpha`. Fifteen checks, zero failures, thirteen mutations all caught.

## What is delivered

| row | destination order | what it does |
| --- | --- | --- |
| `vImageConvert_RGB16UtoARGB16U` | A R G B | three channels in, an alpha in front |
| `vImageConvert_RGB16UtoRGBA16U` | R G B A | the same, alpha last |
| `vImageConvert_RGB16UtoBGRA16U` | B G R A | the same, blue first |
| `vImageConvert_RGBA16UtoRGB16U` | R G B | the alpha dropped, the colours unmoved |
| `vImageConvert_BGRA16UtoRGB16U` | R G B | the alpha dropped, and the colours reordered to reach it |

`vImageConvert_ARGB16UtoRGB16U` is the sixth row of this shape and is carried in the planar group already.

## The measurements, and what each one decided

**A NULL alpha buffer is not a refusal.** The header marks only the source and the destination non-NULL
(`VIMAGE_NON_NULL(1,4)`), and the host then writes the `alpha` argument into the alpha slot — 0x1234, over
three fills of 0x1234 for ARGB, RGBA and BGRA alike. A port that returned `kvImageNullPointerArgument` for a
NULL plane would be wrong, and the mutation that does exactly that is one of the thirteen.

**With a plane, the plane's value is the alpha.** 0x2000 in, 0x2000 out, in all three orders. So the alpha is
`aSrc ? plane : fill`, and nothing else.

**`premultiply` scales the three colours and leaves the alpha alone.** An alpha of 0x2000 over colours of
0x1000, 0x4000 and 0x8000 gives 512, 2048 and 4096, and the alpha slot is still 0x2000. 0x1000 × 0x2000 /
65535 is 512.0078, so the sixteen-bit form of the rule is `value * alpha / 65535` — the alpha as a fraction of
its own maximum, which is the only fraction a sixteen-bit alpha has.

**The rounding is round-to-nearest, and it was measured rather than assumed.** 0xffff × 0x8000 is 32767.5, and
floor and round-to-nearest disagree about it by exactly one. The host writes 32768, so the rule carries
`+ 32767` before the divide. Four cases in the differential exist only to pin this: 0xffff and 0x8001 against
0x8000 and 0x4000. Mutating the rounding to a floor fails four of the fifteen.

**Dropping the alpha is a drop, not a rescale.** An ARGB row of `1000 2111 3222 4333` comes out of
`ARGB16UtoRGB16U` as 8465, 12834 and 17203 — that is 0x2111, 0x3222 and 0x4333 unmoved. And because a
three-channel destination is always R, G, B whatever the source called them, `BGRA16UtoRGB16U` is a **reorder**,
not a drop: its colours are at source channels 2, 1 and 0. One table row is not enough for the two; getting
that wrong fails one of the fifteen.

## The bug the differential caught on its first run

The widen core read the source with the destination's stride. A forward source has **three** channels and a
forward destination has **four**, so every pixel after the first was read from the wrong place — nine of the
fifteen checks failed, and the port's value was a real value from a neighbouring pixel rather than noise. The
signature is a difference that only appears at pixel 1 and later, which is what separates it from an order-table
mistake: a wrong table fails at pixel 0.

The mutation that restores the fault fails nine of the fifteen, so this is not a bug the test merely tolerates.

## What is not here, and where it went

- **The same ten moves over 32-bit float** — `vImageConvert_RGBFFFtoARGBFFFF` and its five siblings. The
  multiply is a float multiply with no 65535 in it, so it shares nothing with this file but the tables.
  **Its premultiply is not measured yet**: a probe with an alpha plane of 1.0 cannot show a multiply by 1.0,
  so the rule is known to exist and not known to be `value * alpha`. That belongs in `vImageAlphaF.md` and
  must be measured with an alpha below 1.0 before those rows are carried.
- **The interleaved-to-planar moves** — `vImageConvert_BGRX8888ToPlanar8`, `XRGB8888ToPlanar8`,
  `BGRXFFFFToPlanarF`, `XRGBFFFFToPlanarF` and `ARGB8888toPlanarF`. Same shape, but the destination is
  separate plane buffers rather than one interleaved row, and `ARGB8888toPlanarF` carries a `maxFloat` and a
  `minFloat` per channel, so its scale is a range and not a copy.
- **The narrowing to sub-byte and to an index** — `Planar8toPlanar1/2/4` and `Planar8toIndexed1/2/4`. The
  indexed three take a `tempBuffer`, a colour table and a **dither** argument, so they are a nearest-colour
  search and not a pack.
- **The 2101010 and 16Q12 placements** (`ARGB16UToXRGB2101010` and its siblings) are iOS 9.3, and
  `ARGB16Q12ToRGBA1010102` is 8.0. A file holds one release's API, so those are a third and fourth file.

## The shape of the group, and how many rows are left

The coordinator's "32 rows, one shared shape" is one shape — *no colour arithmetic, only placement* — which
splits by signature into three cores, and the row count is 37 of which 32 are still to do, not 32 in one
file. The three cores, with the whole family's numbers against the corpus:

| core | rows | to do | carries |
| --- | --- | --- | --- |
| 3 ↔ 4 channels with an alpha, a fill and a premultiply | 12 | 10 | this file's five, and the float five |
| interleaved ↔ separate planes | 9 | 8 | — |
| narrowing to sub-byte or to an index | 6 | 6 | — |
| placements at 8.0 and 9.3 (2101010, 16Q12) | 10 | 8 | — |

**The family is 140 C functions, not 157.** The earlier 157 counted eleven Objective-C `vImageConverter`
selectors and six declarations the corpus does not carry. The corpus is authoritative:
`coordination/corpus/sdk-26.2-surface.tsv` has 163 rows matching `vImageConvert`, of which 140 are the C
functions. 42 of them were carried before this file; 49 now.
