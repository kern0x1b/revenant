# MPSRNNSingleGateDescriptor (iOS 11.0)

Port: `packages/a/apple-backports/MetalPerformanceShaders/MPSRNNSingleGateDescriptor11.m`
Test: `tests/backports/host/mps-rnn-descriptors/` (descriptor.m, run.sh)

## Measured

- **Host:** macOS 27.0.1 (26A434), MPSNeuralNetwork of that host, built as Catalyst
  (`arm64-apple-ios16.0-macabi`), Apple's class and the port's class in one process
  (`RevenantHostMPSRNNSingleGateDescriptor`).
- **Run:** `tests/backports/host/mps-rnn-descriptors/run.sh`, 40 checks, 0 failures (this class: defaults,
  factory at (3, 5) and at (0, 0), set values, copy, equality).
- **Declared members compared:** the base class's five (see MPSRNNDescriptor.md) and the two the 16.4 header
  declares here, `inputWeights` and `recurrentWeights` (MPSRNNLayer.h lines 166-176).
- **Factory:** `createRNNSingleGateDescriptorWithInputFeatureChannels:outputFeatureChannels:`
  (MPSRNNLayer.h line 183). Apple answers an instance of the class with the two channel counts set and every
  other member at the base default. A factory call with (0, 0) also answers an object, with 0 and 0, not nil.
  The header asks for at least 1; the host does not refuse 0, and the port does not either.
- **Apple's defaults, from `[[MPSRNNSingleGateDescriptor alloc] init]`:** the five base defaults
  (channels 1 and 1, the two flags NO, direction 0), `inputWeights` nil, `recurrentWeights` nil.
- **Weight sources:** retained. Setting an object and reading it back returns that object, and setting nil
  clears it, on both sides.
- **Copy and equality:** as the base class. Apple's class is not `NSCopying`, `copy` raises
  `NSInvalidArgumentException`, and equality is identity.

## Not declared, not carried

The host's framework also declares `initWithInputFeatureChannels:outputFeatureChannels:` on this class.
The 16.4 header does not, so the port does not implement it. The base class's four extra members are not
carried either (MPSRNNDescriptor.md).

## Not measured

- Defaults on an iOS device or an older OS; the values above are the macOS 27.0.1 host's.
- Whether a zero-channel descriptor can be encoded by a layer; no layer is carried.
- Weight sources are stand-in `NSObject`s, not `MPSCNNConvolutionDataSource` conformers.
