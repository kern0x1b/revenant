# MPSNNDefaultPadding: the TensorFlow average-pooling factories

The two factories are `+paddingForTensorflowAveragePooling` (`MPSNeuralNetworkTypes.h:500`, header `ios(11.3)`) and
`+paddingForTensorflowAveragePoolingValidOnly` (`:503`, header `ios(11.3)`), in the iOS 16.4 SDK. They are placed by
the measurement, not the header:

- `+paddingForTensorflowAveragePooling` is in the 11.0 band: the release's arm64 shared cache of 11.0 carries the
  selector, so it is in `MPSNNDefaultPadding11.m`. The header's 11.3 is recorded in the registry row as the
  discrepancy it is.
- `+paddingForTensorflowAveragePoolingValidOnly` is in the 11.3 band: the 11.0 cache does not carry it, and it is in
  `MPSNNDefaultPadding113.m`. A file that carried both bands would be the mixed release `misplaced()` refuses.

The base object is `MPSNNDefaultPadding` in `MPSNNGraph11.m`, which carries `+paddingWithMethod:`,
`-paddingMethod`, `-destinationImageDescriptorForSourceImages:...` and the coding pair. Each factory here is a
subclass of that object, created through `+paddingWithMethod:`, with its own `label` and destination.

## What was measured, and where

Host: this Mac, macOS 27.0.1 (Darwin 27.0.0), arm64, an Apple M4 Pro (`MTLCreateSystemDefaultDevice` answers it). The
release's own `MPSNNDefaultPadding` runs here. The differential is `tests/backports/host/mps-cnn-descriptors/cases.m`,
run by `run.sh` for macOS; 58 of 58 checks pass, and the destination cases below are compared value for value on both
sides with the same inputs.

## Apple's answers

Both factories answer a subclass of `MPSNNDefaultPadding` (the release's class names are
`MPSNNTensorFlowPoolingPadding` and `MPSNNTensorFlowPoolingPaddingValidOnly`; the port names its own classes
differently, and the test does not compare class names).

| factory | paddingMethod | label |
| --- | --- | --- |
| ...PoolingPadding... | 0x401c (Custom, SizeSame, AlignCentered, AddRemainderToBottomRight) | `AlignCentered, AddRemainderToBottomRight, SizeSame, MPSNNPaddingMethod.CustomAllowForNodeFusion (ignored without MPSNNPaddingMethodCustom)  variant: MPSNNTensorFlowPoolingPadding` |
| ...ValidOnly | 0x400d (Custom, SizeValidOnly, AlignTopLeft, AddRemainderToBottomRight) | `AlignTopLeft, AddRemainderToBottomRight, SizeValidOnly, MPSNNPaddingMethod.CustomAllowForNodeFusion (ignored without MPSNNPaddingMethodCustom)  variant: MPSNNTensorFlowPoolingPaddingValidOnly` |

Both answer the same object on every call. The two are not equal to each other (identity), and the two are different
objects with different methods.

**The destination.** For a source image, a suggested descriptor, and a kernel (an `MPSCNNPoolingAverage` with window
and stride), Apple's object:

- returns the suggested descriptor itself (the same object), with its size unchanged;
- sets the kernel's `edgeMode` to `MPSImageEdgeModeClamp` (1), from 0 (measured for every case below);
- does not change the kernel's `offset` (0,0 before and after, for every case).

Cases measured (source, suggested, window, stride): 3x3/3x3/2/2, 3x3/2x2/2/2, 5x5/5x5/3/1, 5x5/4x4/3/1, 7x7/3x3/3/2;
the same five on the valid-only factory.

## What the port carries

The port's factories answer those objects: the method above, the label above, the same object on every call, and the
same destination for the same inputs: the suggested object returned, the edge mode set to Clamp, the offset untouched.
The test compares each of these with Apple's object, case for case.

The sizing is not computed by these objects. The release does not compute it either, for these policies: it returns the
suggested descriptor that the graph prepared. A caller that passes a different suggested size gets that size back, from
both sides.

## Not measured

- The edge mode of a kernel without an `edgeMode` property. The port sends the message only to a kernel that has it;
  what Apple does for such a kernel was not run.
- Either object inside a running `MPSNNGraph`. The graph is not run by this test.
- `-inverse`, which the header gives `ios(11.3)` and which neither factory's object answers (`respondsToSelector:`
  is NO on Apple's object). The port does not implement it, and the registry row for `-[MPSNNPadding inverse]` is
  separate.
- Apple's archive keys for these objects. The port's objects are not round-tripped by this test.

## The label of +paddingWithMethod:

Measured on the macOS host (`.agent-work/runs/mps-metal/nng-label/probe.m`, one process per value for the bits):

- For all 64 combinations of the align (0..3), remainder (0..3) and size (0..3) fields, Apple's label is
  `<align>, <remainder>, <size>, ` with the names `AlignCentered`, `AlignTopLeft`, `AlignBottomRight`;
  `AddRemainderToTopLeft`, `...TopRight`, `...BottomLeft`, `...BottomRight`; `SizeValidOnly`, `SizeSame`, `SizeFull`,
  `Size_reserved`. Example: `AlignCentered, AddRemainderToTopLeft, SizeSame, `.
- The align value 3 is reserved: `+paddingWithMethod:` answers nil for all 16 of its combinations, with no log.
- The custom bit (1 << 15) adds the suffix `MPSNNPaddingMethod.Custom (inhibits node fusion)` with no trailing
  separator: `AlignCentered, AddRemainderToTopLeft, SizeValidOnly, MPSNNPaddingMethod.Custom (inhibits node fusion)`.

The port's `+paddingWithMethod:` (`MPSNNGraph11.m`) answers exactly these labels, and nil for align 3. The test is
`tests/backports/host/mps-nn-padding-label` (66 checks, all pass; the mutant that swaps SizeSame and SizeFull is red).

## Not matched: the bits the host rejects

Measured one bit at a time (`one.m`): Apple's `+paddingWithMethod:` accepts bits 0 to 10 and bit 15, and asserts
(`MPSCreatePaddingPolicy(): invalid / unknown bits in MPSNNPaddingMethod.`, status 134) for bits 11 to 14 and 16 to 20.
Bit 14 (0x4000) is `MPSNNPaddingMethodCustom` in the 26.2 header, and bit 15 is `MPSNNPaddingMethodExcludeEdges`
there, yet on this host bit 15 carries the custom label and bit 14 asserts; Apple's own TensorFlow objects have
0x4000 in their method (0x401c, 0x400d). So the host and the 26.2 header disagree about these bits, and the TensorFlow
factories are built on the header's value. The port accepts every bit (unchanged here) and labels only the fields and
bit 15. Not matched; the choice of which set of bits the port accepts is open.
