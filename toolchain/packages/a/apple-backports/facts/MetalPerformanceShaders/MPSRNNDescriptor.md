# MPSRNNDescriptor (iOS 11.0)

Port: `packages/a/apple-backports/MetalPerformanceShaders/MPSRNNDescriptor11.m`
Test: `tests/backports/host/mps-rnn-descriptors/` (descriptor.m, run.sh)

## Measured

- **Host:** macOS 27.0.1 (26A434), MPSNeuralNetwork of that host, built as Catalyst
  (`arm64-apple-ios16.0-macabi` against the macOS SDK 27.0), run in one process with Apple's
  class and the port's class renamed `CharonHostMPSRNNDescriptor`.
- **Run:** `tests/backports/host/mps-rnn-descriptors/run.sh`, 40 checks, 0 failures; the GRU-default
  mutant turns the run red with `FAIL MPSGRUDescriptor defaults`.
- **Declared members compared:** the five the iOS 16.4 header `MPSRNNLayer.h` declares for this class
  (lines 82-118): `inputFeatureChannels`, `outputFeatureChannels`, `useLayerInputUnitTransformMode`,
  `useFloat32Weights`, `layerSequenceDirection`.
- **Apple's defaults, from `[[MPSRNNDescriptor alloc] init]` on the host:**
  - `inputFeatureChannels` 1
  - `outputFeatureChannels` 1
  - `useLayerInputUnitTransformMode` NO
  - `useFloat32Weights` NO
  - `layerSequenceDirection` 0 (`MPSRNNSequenceDirectionForward`)
  - The header prose gives no default for the two channel counts; the value 1 is Apple's, measured.
- **Set values:** every writable member set to a non-default value on both sides
  (7, 9, YES, YES, Backward) reads back identically.
- **Copy:** Apple's class does not conform to `NSCopying` or `NSSecureCoding`. `copy` raises
  `NSInvalidArgumentException` (`unrecognized selector`), fresh and set. The port does the same, so it
  defines no `copyWithZone:` and no secure-coding methods.
- **Equality:** NSObject identity on Apple's class. `isEqual:` is YES for self and NO for a twin with the
  same values, a fresh object against a set one, and nil. `hash` differs between twins. The port answers
  the same.

## Not declared, not carried

The host's framework also has, on this class, `inputTransform`, `outputTransform`,
`recurrentOutputTransform` (all `id <MPSCNNConvolutionDataSource>`) and `internalKernelSelector`
(`NSUInteger`, default 0). They are absent from the iOS 16.4 header, so the port does not implement them.
Their introduction is not measured here.

## Not measured

- Defaults on an iOS device or an older OS. Every default above is the macOS 27.0.1 host's.
- MPSRNNImageInferenceLayer and MPSRNNMatrixInferenceLayer, which consume this descriptor, are
  not carried; nothing here measures a layer's output.
- Weight sources are checked with stand-in `NSObject`s, not with objects conforming to
  `MPSCNNConvolutionDataSource`, since the layers that would read them are not carried.
