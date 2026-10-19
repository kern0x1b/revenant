# The MPSImage kernels SDK 16.4's headers mark ios(9.0)

`MetalPerformanceShaders.framework` does not exist before iOS 9, so every release this package
carries has no MPS framework to shadow: a client that links one and asks a kernel a question reaches
this port's class instead. These three are carried in `MPSImage9.m`, one object for the one release
they all belong to.

## The band, and what became of each of its seven rows

From `coordination/corpus/queue/mps.tsv`, the lowest band, seven rows. **Three carried, two owed, two
untouched.**

| row | outcome | why |
| --- | --- | --- |
| `MPSImageIntegral` | `implemented` | the rectangle sum is the header's own formula and the CPU does it exactly |
| `MPSImageIntegralOfSquares` | `implemented` | the same rectangle over the squares |
| `MPSImageSobel` | `implemented` | the gradient magnitude is a 3x3 weighted sum the header states |
| `MPSImageMedian` | **`owed`** | two of its own members have no value in any header |
| `MPSImageLanczosScale` | **`owed`** | its base `MPSImageScale` is 11.0, so a 9.0 object would be mixed-release |
| `MPSImageHistogramEqualization` | untouched | on `coordination/api-queue.md`; a GPU compute encoder, owed |
| `MPSImageHistogramSpecification` | untouched | the same entry |

**Zero proven absent.** Nothing in this band was found to be dead on this release; two are owed, which
is a debt, not a decision, and two were already owed before this.

## What is measured, and how

`tests/backports/host/mpsimage9/run.sh`, run through `coordination/heavy.sh` while the load was under 12
on 2026-09-30. One build of one case file covers all three kernels; nothing is built per row.

    renamed: 79 classes of 79
      port:        9 case lines, exit 0
      port-plant1: 9 case lines, exit 1
      port-plant2: 9 case lines, exit 1
      ok  port:        exit 0, COMPARED 96  MISMATCHES 0
      ok  port-plant1: exit 1, COMPARED 96  MISMATCHES 96
      ok  port-plant2: exit 1, COMPARED 96  MISMATCHES 9
    mps9: the red control holds - the port agrees with the header and both plants are caught

**96 elements over 9 cases, 0 mismatches**, across three shapes: 1x1 (one pixel, so every integral sum
is a single sample and the 3x3 neighbourhood is entirely outside the image), 3x2 (non-square, so a
transposed walk is caught) and 5x5 (square and large enough for the neighbourhood to have an interior).
The source is a fixed LCG, so the case is the same on every run and every machine.

**The oracle is a CPU reference, and it is not the release's own kernel.** This host's AGX family does
not implement `computeCommandEncoderWithDispatchType:`, and the release's own MPSImage kernels die
encoding. So the case file computes the header's formulas in plain C, in the same process, and compares
every element itself; each binary's own exit status is the verdict. That is why there is no system
build in the script, and it is the same reason 180 rows of the other frameworks say so. **No number on
these three rows is a measurement of Apple's code**, and the rows say so in their reason.

**The tolerance is one ulp of the stored float32** (`mps9-reference.h`). The kernels accumulate in double
and store float32, so one ulp is exactly the difference between "right" and "one rounding off"; a wider
one would hide a defect and a narrower one would fail every case. The integral and the OfSquares sum in
the **same loop order** as the reference, because the header states no order and a prefix-sum reference
against a per-pixel sum would measure the difference between two implementations rather than against the
header.

**The red control bites.** Plant 1 perturbs every float32 element on its way out of the walk
(`MPSImageWalk13.m:227`) and is caught on 96 of 96; plant 2 perturbs one element per case and is caught
on 9 of 9 — one per case, which is what a one-wrong plant is written to be. A comparison never seen to
fail is not a comparison.

## What each kernel computes, from the headers

- **`MPSImageIntegral`** — MPSImageIntegral.h:19-20 gives the rectangle exactly: `sumRect.origin =
  MPSUnaryImageKernel.offset`, `sumRect.size = dest_position - MPSUnaryImageKernel.clipRect.origin`. The
  size is a difference of two **positions**, not a count, so the rectangle holds one more sample per axis
  than its length and the destination position is **inclusive**. The class declares no member at all
  (:33-35 is `@end` after the `@interface`).
- **`MPSImageIntegralOfSquares`** — :38 sums the **squares** over the same rectangle (:40-41). That is
  the whole difference between the two classes, and both share one function with a flag.
- **`MPSImageSobel`** — :281-288 gives the luminance the filter runs on, `Luminance = v[0]*x + v[1]*y +
  v[2]*z`, and :301-302 its default transform, BT.601/JPEG `{0.299f, 0.587f, 0.114f}`. :350-352 states the
  operator for the filters this same header uses: `G = sqrt(Sx^2 + Sy^2)`. The 3x3 pair is the standard
  operator those lines name.

## What is owed, and what a caller gets today

- **`MPSImageMedian`** — the median itself is exact and an object for it compiles; what is missing is a
  **source**. `MPSImageMedian.h:67` and `:71` declare `+maxKernelDiameter` and `+minKernelDiameter` and
  **no header in either SDK states a value for either** (`grep axKernelDiameter` over both SDKs'
  `MetalPerformanceShaders` returns those two declarations and nothing else). Two members answered with
  numbers this port chose is a class that loads and lies, so the whole class is owed. A caller gets
  `nil` from `NSClassFromString` and a crash on a compile-time reference — the intended failure.
  **Unblocked by:** a value for those two from a source that is not this port. The host framework image
  under Mac Catalyst is the route the rest of the tree uses for a constant the header does not carry,
  recorded with the host and the command.
- **`MPSImageLanczosScale`** — a placement problem, not a measurement. MPSImageResampling.h:122
  annotates it `ios(9.0)` while **:29 annotates its own base, `MPSImageScale`, `ios(11.0)`**: a later base
  under an earlier class, which is the release's own hierarchy. Carrying it in a 9.0 object would put an
  11.0 class in a 9.0 file — the mixed-release object the band machinery must not be given — and
  `MPSImageScale` is itself an absent row of this family at 11.0, so the base cannot simply be written
  either. The filter is computable on the CPU (:110-121 names the Lanczos algorithm). A caller gets
  `nil` and a crash, not a resample that is not the filter's. **Unblocked by:** the 11.0 surface.

## Two limits of the walking layer, measured and named

Neither is a defect in the kernels; both are in the shared layer and both are owed with it.

1. **The header's recommended conversion is not walkable.** MPSImageIntegral.h:22-26 says "if the
   channels in the source image are normalized, half-float or floating values, the destination image is
   recommended to be a 32-bit floating-point image". The layer's walkability check compares the two
   images' **data types** (`CharonMPSImageDataTypeOf`), so an Unorm8 source (`MPSDataTypeUInt8`) into a
   Float32 destination is **refused by name** and nothing is written. Measured: 95 mismatches of 96,
   every value 0. The cases therefore measure the data type the layer does walk, and the rows say so.
2. **A non-zero `offset` is answered against the origin.** The integral reads the rectangle from
   `{0,0,0}`, the header's default (MPSImageKernel.h:131-138), and the kernels are documented as
   answering that. A caller who set an offset is owed that path rather than answered against the wrong
   rectangle.

## One thing this band cost, recorded because it is worth knowing

The first pass of the case file filled the source texture with `bytesPerRow: cols * 4 * sizeof(float)`,
a four-channel stride, on an image whose `featureChannels` is 1. The region read then returned
`1, 1.4e-45, -4.7e30, 4` instead of `1, 2, 3, 4, 5, 6`, which reads exactly like a stride defect in
`MPSImageWalk13.m`, and I reported it as one. It is not: the port maps a one-channel descriptor to
`MTLPixelFormatR32Float` (`MPSImage13.m:42`, value 55), whose row is `cols * sizeof(float)` = 12, and the
layer's own `bytesPerRow` is that same 12. With the right stride `CharonMPSImageReadRegion` returns
`1..6` for the 3x2 image. **The walking layer is correct; the case was wrong.** Recorded because a
mis-measurement that looks like a defect in main is worth a note, and because the next person to fill a
texture in a harness will hit the same four-channel instinct.
