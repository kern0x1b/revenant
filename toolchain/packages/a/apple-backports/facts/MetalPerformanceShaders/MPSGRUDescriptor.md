# MPSGRUDescriptor (iOS 11.0)

Port: `packages/a/apple-backports/MetalPerformanceShaders/MPSGRUDescriptor11.m`
Test: `tests/backports/host/mps-rnn-descriptors/` (descriptor.m, run.sh)

## Measured

- **Host:** macOS 27.0.1 (26A434), MPSNeuralNetwork of that host, built as Catalyst
  (`arm64-apple-ios16.0-macabi`), Apple's class and the port's class (`CharonHostMPSGRUDescriptor`) in one process.
- **Run:** `tests/backports/host/mps-rnn-descriptors/run.sh`, 40 checks, 0 failures; the mutant that sets the
  port's default `gatePnormValue` to 2 turns the defaults and factory checks red with `FAIL MPSGRUDescriptor defaults`
  and `gatePnormValue: apple 1, port 2`.
- **Declared members compared:** the base class's five and the nine the 16.4 header declares here
  (MPSRNNLayer.h lines 251-310): the seven weight sources `inputGateInputWeights`, `inputGateRecurrentWeights`,
  `recurrentGateInputWeights`, `recurrentGateRecurrentWeights`, `outputGateInputWeights`,
  `outputGateRecurrentWeights`, `outputGateInputGateWeights`; `gatePnormValue` (float); `flipOutputGates` (BOOL).
- **Factory:** `createGRUDescriptorWithInputFeatureChannels:outputFeatureChannels:` (MPSRNNLayer.h line 318).
  Apple answers an instance with the channels set and every other member at its default; the port does the same.
- **Apple's defaults, from `[[MPSGRUDescriptor alloc] init]`:** the base five (channels 1 and 1, the two flags NO,
  direction 0); all seven weight sources nil; `gatePnormValue` 1; `flipOutputGates` NO.
- **Set values:** every member set away from its default (weights to distinct stand-ins, read back by identity;
  `gatePnormValue` 2.5; `flipOutputGates` YES) reads back identically on both sides.
- **Copy:** Apple's class is not `NSCopying`; `copy` raises `NSInvalidArgumentException`, fresh and set. The port
  matches, so it defines no copy.
- **Equality:** identity on both sides, as for the base class.

## Not declared, not carried

The host's framework also declares `initWithInputFeatureChannels:outputFeatureChannels:` on this class, which the
16.4 header does not. It is not implemented. The base class's extra members are not carried (MPSRNNDescriptor.md).

## Not measured

- Defaults on an iOS device or an older OS; the values above are the macOS 27.0.1 host's.
- The GRU's output: no layer that encodes it is carried, so the formula in the header is not measured here.
- Weight sources are stand-in `NSObject`s, not `MPSCNNConvolutionDataSource` conformers.
