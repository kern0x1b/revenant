# MPSImage

**The image and its descriptor.** `MPSImage` is a texture; `MPSImageDescriptor` is the shape of one. On
this port the texture is a real `MTLTexture` on the carried Metal classes, made through
`MTLTextureDescriptor` and read and written through the texture's own
`getBytes:bytesPerRow:fromRegion:mipmapLevel:` and `replaceRegion:mipmapLevel:withBytes:bytesPerRow:`, so
the read a kernel makes and the read a caller makes go the same way.

**What the 26.2 names in the tree.** `+[MPSImageDescriptor imageDescriptorWithChannelFormat:width:height:featureChannels:]`
and `-[MPSImage initWithDevice:imageDescriptor:]` are what `tests/backports/host/mpscnn/cnn-cases.m`
calls, and both are in the iPhoneOS 16.4 headers this package compiles against with 16.4's own
signatures, so neither is transcribed. What the release has and this build does not is a
`+defaultAllocator` and the allocator protocol behind it; `-initWithDevice:` with no descriptor names no
shape, and rather than answer 1×1×1 the port refuses and says which initialiser it implements.

**The measurement, and what it was before.** `tests/backports/host/mpscnn/run.sh` builds each of its
five cases' source and destination through this class on the port's side and through the release's on
its own, and compares the values that come back:

    cases: 5, tolerance 0.0001 absolute or relative
    closest to the tolerance, as a fraction of it:
      batch-normalization          0.00118
    differing cases: 0

The four pooling cases are bit-identical and are compared exactly; `batch-normalization` differs on one
of nine elements, 0.00118 of that case's tolerance, which is the order a normalisation accumulates in
and not a different answer.

**Before this class existed, that line was hollow.** The port had no `MPSImage`, the harness's rename
header is generated from the classes the port's objects define, and `MPSImage` was not among them — so
on the port's side the case built its images through the release's own class and the five cases compared
the release with itself. The harness printed that and nothing acted on it:

    image MPSImage                               /System/Library/.../MPSCore
    image CharonMPSImage                         (absent)

`cnn-cases.m` now asks, before each case builds anything, whether the port has every class that case
builds from, and a case that does not is named and counted as *not compared*; the comparison then fails
on the uncompared case. `run.sh` is marked with `-DCHARON_PORT_BUILD` so the question is asked on the
port's build only — the system build links the release's classes and has no port to ask about. The red
line, on the tree as it stood before this class:

    cases the harness refused to compare: 2
      system side: pooling: the port has no MPSImage, so this case reached the host's class on both sides and compared the host with itself
      system side: batch-normalization: the port has no MPSImage, so this case reached the host's class on both sides and compared the host with itself
      port side: pooling: the port has no MPSImage, so this case reached the host's class on both sides and compared the host with itself
      port side: batch-normalization: the port has no MPSImage, so this case reached the host's class on both sides and compared the host with itself
      a case that did not run is not a case that passed; this comparison is red

**A case that reads a fresh image, because the other five could not see it.** Every other case writes
its image before it reads it, so none of them can see what a fresh image holds, and a port that left one
with whatever its texture carried would pass all five. `fresh-image` makes no image hold a written value
at all: it builds one and reads it straight back, and both sides must answer zeros. It was added on
2026-09-29 because the zero-fill mutant below was invisible for two separate reasons, and the case is
what makes it visible at all: no case read a fresh image, and the mutant's fill, `0xA5` in every byte, is
`0xA5A5A5A5` as a little-endian float32, which is **-2.87e-16** and sits a thousand million times
inside a 1e-4 tolerance. The fill is `0x7F` now, `0x7F7F7F7F` as a float32, which is 3.4e+38 and which no
tolerance forgives:

    0xA5A5A5A5 as float32: -2.87e-16   0x7F7F7F7F as float32: 3.4e+38

**That the comparison can fail.** `tests/backports/host/mpscnn/mutation.sh` mutates a copy of the
library under `.agent-work` and points the run at it with `MPS=`, so no tracked file is written. Every
anchor is resolved before the first harness run, in one python process that prints a line per site and
a count, and a stale anchor costs a second:

    anchor check: pooling-divisor        1 occurrence(s) in MPSCNNPooling10.m
    anchor check: image-zero-fill        1 occurrence(s) in MPSImage13.m
    anchor check: 2 sites compared, 0 not resolving exactly once

and the control, with one site's anchor replaced by the other's:

    anchor check: pooling-divisor        0 occurrence(s) in MPSCNNPooling10.m
    anchor check: 2 sites compared, 1 not resolving exactly once
      pooling-divisor occurs 0 times in MPSCNNPooling10.m, and a mutation needs exactly one
    the campaign is not startable: an anchor does not resolve exactly once     exit 1

The campaign, with a control on each side of each mutation, and `CAMPAIGN=all` green:

    pooling divisor      before   cases: 6, tolerance 0.0001 absolute or relative differing cases: 0
    pooling divisor      mutated  cases: 6, tolerance 0.0001 absolute or relative differing cases: 3
    pooling divisor      reverted cases: 6, tolerance 0.0001 absolute or relative differing cases: 0
    image zero fill      before   cases: 6, tolerance 0.0001 absolute or relative differing cases: 0
    image zero fill      mutated  cases: 6, tolerance 0.0001 absolute or relative differing cases: 1
    image zero fill      reverted cases: 6, tolerance 0.0001 absolute or relative differing cases: 0
    CAMPAIGN=all exit: 0

A divisor one short takes three of the six cases red and a fresh image that is not zeros takes the sixth,
and each revert takes them back, so the green cases above are measuring this port's arithmetic over this
port's image and not the release's twice.

**Where the two class rows are placed, and why that is not their `introduced`.** `MPSImage` is
introduced in 9.0 and `MPSImageDescriptor` in 26.2, and both rows carry a **`minimum` of 6.0**, which is a
different field: `introduced` is when the release has the class, and `minimum` is the earliest release the
object holding it is carried on. `minimums()` in `modules/apple/backports.lua` takes an object's bound from
the registry entries for the names that object *defines*, so `MPSImage13.o` is bounded by these two rows
and by nothing else. With no minimum it was carried by every band, and it names
`_OBJC_CLASS_$_MTLTextureDescriptor` — the class `Metal/MTLTextureDescriptor8.m` defines, and that file is
carried from 6.0 on — so below 6.0 the object would name a class the band does not carry, and the 4.3 gate
says so:

    error: 1 objects cannot be placed by their registry minimum above iOS 4.3: MPSImage13.o is carried by
    every band and names _OBJC_CLASS_$_MTLTextureDescriptor, which MTLTextureDescriptor8.o defines only
    from 6.0 on; it would not link below that, so give its entries that minimum or move the symbol to a
    file of its own

**This is the rule for the rest of this family**, and it is worth stating once here: a class row whose
class calls into a Metal class needs a `minimum` at the release that Metal class is carried from, or its
object must be a file of its own. Declaring `libraries = {"FoundationBackports", "MetalBackports"}` in
`modules/apple/backports.lua` does not bound the placement; only the registry minimum does. The sweep over
the two libraries' objects, on the same tree, names one object and one symbol:

    MPSImage13.o    _OBJC_CLASS_$_MTLTextureDescriptor
    (every other object of the 51 names no Metal class)

so the bound belongs to these two rows and to no other row of either framework.

**A fresh image reads as zeros.** The port zeroes a texture it made, because a texture's contents are
whatever was in it and a kernel reads them; the release zeroes a fresh image too, and a caller that
reads an image before it writes it is answered zeros. The second mutant, `image-zero-fill`, is that
line changed to leave the texture as it came.

**Not carried.** `MPSImageBatch`, `MPSImageState`, `+defaultAllocator` and the allocator protocol, the
image kernels of this family (`MPSImageArithmetic` and the four operations, the five thresholds, the nine
reductions, the statistics, the area and integral kernels, transpose, copy to matrix, median, box and the
four histograms), and the image's `writeBytes:...bytesPerColumn:bytesPerImage:` form. None of them is
carried, and none of them is described here as if it were.

## This slice: the five thresholds and the arithmetic kernel, and what is measured

`MPSImageArithmetic` and its four operations, `MPSImageThresholdToZero`, `MPSImageThresholdToZeroInverse`,
`MPSImageThresholdTruncate`, `MPSImageThresholdBinary` and `MPSImageThresholdBinaryInverse` - ten rows,
each `implemented` with `minimum: 6.0`, because every one reaches `MTLTextureDescriptor` and `MTLDevice`
through `MPSImage13.m` and the 4.3 gate refuses an object naming a class a band below Metal does not carry.

### The host cannot be the oracle on this machine, and that is measured

The release's own `MPSImageThresholdToZero` is the class that would answer - `dladdr` on its encode
method resolves it to
`/System/Library/Frameworks/MetalPerformanceShaders.framework/…/Frameworks/MPSImage.framework/…` - and
then the process dies:

    *** Terminating app due to uncaught exception 'NSInvalidArgumentException', reason:
      '-[AGXG16XFamilyCommandBuffer_mtlnext computeCommandEncoderWithDispatchType:]': unrecognized selector

This host's AGX family does not implement the encoder selector the framework calls, so the release's
kernels answer **nothing** here. Every row's `reason` and `effect` says so:
*host MPS cannot run here: AGX family lacks computeCommandEncoderWithDispatchType:; behaviour taken from
the header formula and checked against a CPU reference.* The port's own kernels do not touch an AGX
command buffer - the encode walks the image on the CPU - which is why the port side produces nine cases
where the host side produces none.

### What the measurement is

`tests/backports/host/mpsimage/run.sh` builds the slice from the current tree into a fresh directory and
runs nine cases over a twelve-value source `{-1.5, -0.25, 0, 0.25, 0.5, 0.5, 0.75, 1.0, 1.5, 2.0, -0.75, 0.1}`
and a second image, with a threshold of 0.5 and a maximum of 1.0. `mps-reference.h` computes each
expected answer in plain C from the header's own formula - `MPSImageThreshold.h:194`, `:246`, `:141`,
`:21`, `:81` and `MPSImageMath.h` - **independently of the port**, and the case compares and exits
non-zero on any mismatch beyond one whole float32 ulp of the answer, which is the bound these kernels
need: they accumulate in double and store float32, so a narrower bound fails every case and a wider one
hides a real defect.

    COMPARED 108  MISMATCHES 0
    RESULT case_lines=9 AGX_assertion=0

    port  threshold-to-zero         12 0 0 0 0 0 0 0 0.75 1 1.5 2 0 0
    ref   threshold-to-zero         12 0 0 0 0 0 0 0 0.75 1 1.5 2 0 0
    port  threshold-binary          12 0 0 0 0 0 0 1 1 1 1 0 0
    ref   threshold-binary          12 0 0 0 0 0 0 1 1 1 1 0 0
    port  MPSImageAdd               12 -1 0.25 0.5 0.75 1.5 2.5 4.75 1.5 1.75 2.5 0.75 2.0999999
    port  MPSImageSubtract          12 -2 -0.75 -0.5 -0.25 -0.5 -1.5 -3.25 0.5 1.25 1.5 -2.25 -1.89999998
    port  MPSImageMultiply          12 -0.75 -0.125 0 0.125 0.5 1 3 0.5 0.375 1 -1.125 0.200000003
    port  MPSImageDivide            12 -3 -0.5 0 0.5 0.5 0.25 0.1875 2 6 4 -0.5 0.0500000007

The largest difference from the reference is **1e-07**, one float32 ulp at that magnitude.

### Two defects the reference and the header found, and what each was

**A strict comparison.** `MPSImageThreshold.h:21` and `:81` write `sourcePixelValue > thresholdValue`,
strictly greater. The port compared `>=`, so a source sitting **exactly on** the threshold took the
maximum branch. The reference caught it at elements [4] and [5] of the twelve-value source, which is where
the two 0.5 values are, on both kernels and both times:

    COMPARED 108  MISMATCHES 4
      MISMATCH threshold-binary [4] reference 0 port 1, one ulp 1.4e-45
      MISMATCH threshold-binary-inverse [4] reference 1 port 0, one ulp 1.19e-07

**A transform that was never in the rule.** `MPSImageThreshold.h:18-19`, and the same at `:78-79`,
`:138-139`, `:198-199` and `:258-259`: *"If the input image is not a single channel image, convert the
input image to a single channel luminance image using the linearGrayColorTransform and then apply the
threshold."* That is **one scalar luminance per pixel** - 0.299r + 0.587g + 0.114b at the default -
computed from the three channels and then thresholded **once**. The port multiplied each channel by its
own coefficient and thresholded each separately, which is three comparisons where the header does one and
three writes where the header writes one; and on a **one** channel image it multiplied the value by
0.299, which is where a case's `0.598` came from against a source of `2.0`. The five thresholds now
answer a one channel image, thresholded on its own value, and **refuse a multi channel image by name**,
quoting the rule they are not answering, rather than answering per channel.

### Owed, and not claimed

- **The multi channel luminance.** All five thresholds. The header states the rule and the default
  coefficients; the port refuses the image instead of implementing it. A caller with an RGB or RGBA
  image gets a refusal naming the feature channel count, not an answer.
- **The arithmetic clamp**, `minimumValue` and `maximumValue` on `MPSImageArithmetic`. The header
  declares both; no case sets either, and the port's `CharonMPSCombine` applies them, but nothing here has
  measured that it does so where the release would.
- **The strides**, `primaryStrideInPixels` and `secondaryStrideInPixels`. Declared by the header, carried
  by the port, and **no case exercises them**: a kernel given a stride and a kernel given none are the
  same code path in every case run here.
- **`MPSImageDivide` at a zero secondary divisor.** The port answers 0; no case divides by zero, and
  what the release answers there is not established by anything on this machine.
