# MPSImageStatistics: three classes at 11.0, and the walk that answers for them

`MPSImageStatisticsMinAndMax`, `MPSImageStatisticsMeanAndVariance` and `MPSImageStatisticsMean`. One
object, `MPSImageStatistics11.m`, and `MPSImageStatistics.h:24`, `:72` and `:117` each put
`MPS_CLASS_AVAILABLE_STARTING(macos(10.13), ios(11.0), macCatalyst(13.0), tvos(11.0))` above its own
declaration, so the object carries one release and nothing else does.

## What decided that this is work and not a missing capability

The release's own cache, read with `tools/corpus/objc-inventory.lua` over
`$HOME/.charon/dyld/16.0/dyld_shared_cache_arm64e`: **none of the three declares an encode of its own.**
`MPSImageStatisticsMinAndMax`'s entire instance list is `-clipRectSource`, `-initWithCoder:device:` and
`-initWithDevice:`; `MPSImageStatisticsMean`'s is the same three. So the walk is the one they **inherit**
from `MPSUnaryImageKernel`, and `MPSUnaryImageKernel` is a class this port already carries (`image.json`,
introduced 9.0, **implemented**) whose own `-encodeToCommandBuffer:sourceImage:destinationImage:` is a CPU
walk here, as `MPSImage9.m`'s and `MPSImageReduce12.m`'s are. That is why these rows are `implemented`
and not `owed`.

The base does not carry the encode and the three concrete classes each implement it, which is how
`MPSCNNPooling10.m` does it. A category cannot read the ivars the base declares — the lesson
`MPSImageReduceUnary16.m:29-40` records for the same family of reduction over an image.

## The walk, and what it reuses

The read is `CharonMPSImageReadRegion` and the write `CharonMPSImageWriteRegion`, the same pair every
`MPSImage` kernel in this package uses, with `CharonMPSImageLoad` / `CharonMPSImageStore` at the image's
own element width. The window is `CharonMPSImageResolvedRegion` — which intersects a clip rectangle with
the image, as `MPSImageStatistics.h:30-31` requires by name — and `CharonMPSImageRegionIsEmpty` is what
says a window with no pixels does no work at all.

**One thing this file had to set itself, and it is worth naming.** `CharonMPSImageReadRegion` sets the
region's element `count` on a **copy** of the layout it is handed (`MPSImageWalk13.m:176-205`), so the
caller's layout keeps the zero its `memset` leaves — and the guard in `CharonMPSImageLoad` then refuses
every load. Measured on this host, 2026-10-01: the first run of this differential printed nine
`MPSImage: the walk asked for element N of a region of 0 element(s) (3x3 pixels, 1 channel(s))` refusals
and answered zeros. `CharonMPSImageMapUnary` sets the count the same way and says so in its own comment,
and `MPSImageTranspose13.m:52-53` does the same. This file sets it on both layouts, before the read.

## What the header fixes, and what it does not

| class | header sentence | where the answers go |
| --- | --- | --- |
| `MPSImageStatisticsMinAndMax` | `:18` "computes the minimum and maximum pixel values for a given region" | `:19-20` min at **(0,0)**, max at **(1,0)** — the header's own words |
| `MPSImageStatisticsMeanAndVariance` | `:66` "computes the mean and variance" | along the destination's first row, mean then variance — **this file's choice**, the header does not place them |
| `MPSImageStatisticsMean` | `:114` "computes the mean" | at the destination's own origin, one answer so any shape holds it |

The read window is the header's: `:28-33` `clipRectSource`, "If the clipRectSource does not lie completely
within the source image, the intersection of the image bounds and clipRectSource will be used", and "The
clipRectSource replaces the MPSUnaryImageKernel offset parameter for this filter. The latter is ignored.
Default: MPSRectNoClip, use the entire source texture." So **offset does not enter these three kernels.**

The destination's `clipRect` means something different, and that is stated: `:35-36` "The clipRect
specified in MPSUnaryImageKernel is used to control the origin in the destination texture where the min,
max values are written. **The clipRect.width must be >=2. The clipRect.height must be >= 1.**" A
destination narrower than two pixels cannot hold the min and the max at (0,0) and (1,0), so this file
**refuses that by name**, with the shape in the message, rather than writing the second value past the
edge. Measured: the refusal case prints exactly that and writes nothing.

## Arithmetic and the bound

A minimum and a maximum **select** values the source already holds, so they are exact and are compared
for **equality** — a copy that moved a bit is a copy that moved a bit. A mean and a variance **divide**,
and dividing cannot be exact in binary, so each sum is taken in `double` and divided **once**, leaving the
answer within one whole float32 ulp. That is the split `CharonNNReduceReference.h` and `mps-reference.h`
already state for the reduce families, applied here rather than reinvented.

The **variance is the mean of the squared deviations**, `sum((x - mean)^2) / count`, and not the mean of
the squares minus the square of the mean. The two differ in the last bits on any input where they differ
at all, and the second form is not what a variance is. This is the `variance-form` mutation's whole
subject.

## The measurement

    $ cd $HOME/Git/projects/ios/charon && sh tests/backports/host/mpsstatistics/run.sh
    system: 15 cases, 0 died on the missing encoder
    compared 23 mismatches 0
    PASS: 23 elements compared, 0 mismatches

**What the oracle is, and is not.** `CharonMPSStatisticsReference.h` is the header's own sentences written
as arithmetic in plain C; it takes the source values and the operation as arguments and **never names the
port's class**, so a case that agrees is two implementations of one sentence and not one implementation
compared with itself. No number on these rows is a measurement of Apple's code: this host's AGX family
lacks `computeCommandEncoderWithDispatchType:` and the release's own kernel dies encoding with
`'-[AGXG16XFamilyCommandBuffer mtlnext computeCommandEncoderWithDispatchType:]': unrecognized selector`.

The sources are chosen so that a wrong walk cannot agree by accident: three 3×3×1 sources (ascending,
mixed-sign with values at and below zero, all-negative), one 3×2×**2** source — which is what catches a
walk that reads only plane 0 — and two 1×1 sources, which catch a mean that divides by the window's
*area* instead of the count of values really read. **23 answers**: 15 over the 3×3s, 5 over the
two-channel source, 3 over the 1×1s.

## The mutation campaign

    $ sh tests/backports/host/mpsstatistics/mutation.sh
    baseline: PASS: 23 elements compared, 0 mismatches
      extrema-seed:  compared 23 mismatches 4
      variance-form:  compared 23 mismatches 4
      mean-divisor:   compared 23 mismatches 8
    restored: PASS: 23 elements compared, 0 mismatches
    campaign: 3 caught, 0 not caught

A green differential says nothing unless it **can** be red, so each claim above is defended by a mutation
that breaks exactly that claim: seeding both extrema from zero (`extrema-seed`), the other form of the
variance (`variance-form`), and dividing the mean by the pixel count rather than the value count
(`mean-divisor`, which differs on exactly the two-channel source and on nothing else).