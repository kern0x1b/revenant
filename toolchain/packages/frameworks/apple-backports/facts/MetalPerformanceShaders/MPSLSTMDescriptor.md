# MPSLSTMDescriptor (iOS 11.0)

Port: `packages/a/apple-backports/MetalPerformanceShaders/MPSLSTMDescriptor11.m`
Test: `tests/backports/host/mps-rnn-descriptors/` (descriptor.m, run.sh)

## Measured

- **Host:** macOS 27.0.1 (26A434), MPSNeuralNetwork of that host, built as Catalyst
  (`arm64-apple-ios16.0-macabi`), Apple's class and the port's class (`RevenantHostMPSLSTMDescriptor`) in one process.
- **Run:** `tests/backports/host/mps-rnn-descriptors/run.sh`, 40 checks, 0 failures.
- **Declared members compared:** the base class's five and the sixteen the 16.4 header declares here
  (MPSRNNLayer.h lines 389-508): `memoryWeightsAreDiagonal` (BOOL); twelve weight sources, three per gate
  (`inputGate`, `forgetGate`, `outputGate`, `cellGate`, each with `InputWeights`, `RecurrentWeights`,
  and `MemoryWeights` for the input, forget and output gates, `cellGateMemoryWeights` for the cell); `cellToOutputNeuronType`
  (MPSCNNNeuronType); `cellToOutputNeuronParamA`, `B`, `C` (float).
- **Factory:** `createLSTMDescriptorWithInputFeatureChannels:outputFeatureChannels:` (MPSRNNLayer.h line 518).
  Apple answers an instance with the channels set and every other member at its default.
- **Apple's defaults, from `[[MPSLSTMDescriptor alloc] init]`:** the base five (channels 1 and 1, the two flags NO,
  direction 0); `memoryWeightsAreDiagonal` NO; all twelve weight sources nil; `cellToOutputNeuronType` 5, which is
  `MPSCNNNeuronTypeTanH` (the header's own default, confirmed by this read); `cellToOutputNeuronParamA`, `B`, `C` 1.
- **Set values:** every member set away from its default (weights to distinct stand-ins, read back by identity;
  `cellToOutputNeuronType` ReLU; parameters 0.5, 2.0, 3.0; `memoryWeightsAreDiagonal` YES) reads back identically.
- **Copy:** Apple's class is not `NSCopying`; `copy` raises `NSInvalidArgumentException`, fresh and set. The port matches.
- **Equality:** identity on both sides, as for the base class.

## Not declared, not carried

The host's framework also declares `cellClipThreshold` (float, default -1) and `coupleForgetGateToInputGate`
(BOOL, default NO) on this class, and `initWithInputFeatureChannels:outputFeatureChannels:`. The 16.4 header
declares none of them, so the port does not implement them. The base class's extra members are not carried either
(MPSRNNDescriptor.md). Their introduction after the 16.4 SDK is not measured here.

## Not measured

- Defaults on an iOS device or an older OS; the values above are the macOS 27.0.1 host's.
- The LSTM's output: no layer that encodes it is carried, so the cell and gate formulas are not measured.
- Weight sources are stand-in `NSObject`s, not `MPSCNNConvolutionDataSource` conformers.
