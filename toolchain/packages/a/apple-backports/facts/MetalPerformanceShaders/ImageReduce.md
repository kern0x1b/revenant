# MPSImageReduce - the header's contract

Read from the iPhoneOS 26.2 surface:
`MetalPerformanceShaders.framework/Frameworks/MPSImage.framework/Headers/MPSImageReduce.h`

Nine owed rows: `MPSImageReduceUnary` abstract, and `RowMin`, `ColumnMin`, `RowMax`, `ColumnMax`,
`RowMean`, `ColumnMean`, `RowSum`, `ColumnSum`. `MPS_CLASS_AVAILABLE_STARTING` at :28 is
`macos(10.13.4), ios(11.3), macCatalyst(13.0), tvos(11.3)` - so introduced **11.3**, minimum 6.0.

## What the header says

- :17-26 - the eight operations: reduce row min, column min, row max, column max, row mean, column
  mean, row sum, column sum.
- :29 - `MPSImageReduceUnary : MPSUnaryImageKernel`, so `clipRect`, `offset` and `edgeMode` exist on it
  and the family's encode belongs there.
- :31-42 - `clipRectSource`, MTLRegion: "The source rectangle to use when reading data. If the
  clipRectSource does not lie completely within the source image, the intersection of the image bounds
  and clipRectSource will be used. The clipRectSource replaces the MPSUnaryImageKernel offset parameter
  for this filter. The latter is ignored. Default: MPSRectNoClip, use the entire source texture."
  **A different rule from every other unary kernel in this package**, and one any reference must model
  or the comparison proves nothing.
- :38-40 - "The clipRect specified in MPSUnaryImageKernel is used to control the origin in the
  destination texture where the min, max values are written. The clipRect.width must be >=2. The
  clipRect.height must be >= 1." Two bounds to refuse by name.
- :44-47 - `-initWithDevice:` is `NS_UNAVAILABLE` on the abstract base: "You must use one of the
  sub-classes." The base must not instantiate.
- Each concrete class declares `-initWithDevice:` `NS_DESIGNATED_INITIALIZER`.

## What the header does not say

The **destination's shape**. Every concrete class says it returns a value "for each row of an image"
(:53, :91, :125, :159) or "for each column" (:74, :108, :142, :176), which fixes how many values there
are but never their width or height.

It cannot be answered by measurement on this host: its AGX family lacks
`computeCommandEncoderWithDispatchType:` and the release's own kernel dies encoding with
`-[AGXG16XFamilyCommandBuffer mtlnext computeCommandEncoderWithDispatchType:]: unrecognized selector`.
So it is taken from the clip bounds the header does state, not invented, and every row of this family
carries that AGX reason.

## Where the encode goes, and why it is a category

A CATEGORY on `MPSImageReduceUnary`, not a method in a subclass. `MPSImageThreshold13.m`'s category on
`MPSUnaryImageKernel` already implements `-encodeToCommandBuffer:sourceImage:destinationImage:`, and that
walk is 1:1. A reduction's destination is a different shape from its source, so the reduce walk has to sit
on the reduce class or the inherited 1:1 one wins.

## Next step

1. Cases in `image-cases.m`, one per concrete class over a 4x3 float32 image - a row reduction expects 3
   values, a column reduction 4 - with `CharonReferenceImageReduce` in `mps-reference.h` computing
   min/max/mean/sum in plain C over `clipRectSource` intersected with the image. Exact for min, max and
   the row/column sums; a tolerance for the means, which divide. A row that can make no comparison is
   written `inert-with-reason` with the AGX line above.
2. **Red control before the implementation**: add the cases, watch both plants report `NOT AS EXPECTED`
   while the kernels do not exist yet. That is the control biting before there is anything to pass it. The
   plants are in `CharonMPSStore` and `CharonMPSImageWriteRegion`; a reduction stores through the former,
   so they reach it.
3. `MPSImageReduce13.m`, then the nine rows, then export `mps-reduce` on `160b3baf8` with one Self-review
   on the tip and review-mechanical with the nm sweep.
