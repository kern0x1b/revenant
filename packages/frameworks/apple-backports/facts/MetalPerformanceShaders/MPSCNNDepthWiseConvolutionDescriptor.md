# MPSCNNDepthWiseConvolutionDescriptor (iOS 11.0)

The class is `MPSCNNDepthWiseConvolutionDescriptor : MPSCNNConvolutionDescriptor`, declared at
`MPSCNNConvolution.h:362-388` in the iOS 16.4 SDK. Its one own member is `channelMultiplier` (readonly, :386).
The port is `MPSCNNDepthWiseConvolutionDescriptor11.m`; the base it subclasses is `MPSCNNConvolutionDescriptor10.m`.

## What was measured, and where

Host: this Mac, macOS 27.0.1 (Darwin 27.0.0), arm64, an Apple M4 Pro, with the macOS SDK `xcrun` selects
(`/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk`). Apple's object is the release's own framework, linked
from that SDK, and the port's object is built from the port's source in the same process.

The differential is `tests/backports/host/mps-cnn-descriptors/cases.m`, run by its `run.sh`. The build is for
macOS, not Catalyst: the 16.4 header marks the neuron accessors `MPS_UNAVAILABLE(macCatalyst)`
(`MPSCNNConvolution.h:266-284`), so a Catalyst build cannot compile them. The run passes 58 of 58 checks,
and its mutant (the sub-pixel default changed, see that class's page) turns the default comparison red.

## Apple's defaults

A fresh object (`alloc` and `init`) answers, measured on Apple's object:

| member | Apple's default |
| --- | --- |
| kernelWidth, kernelHeight | 1, 1 |
| inputFeatureChannels, outputFeatureChannels | 1, 1 |
| strideInPixelsX, strideInPixelsY | 1, 1 |
| groups | 1 |
| dilationRateX, dilationRateY | 1, 1 |
| neuronType | 0 (MPSCNNNeuronTypeNone) |
| neuronParameterA, neuronParameterB | 1, 1 |
| channelMultiplier | 1 |
| fusedNeuronDescriptor | a non-nil MPSNNNeuronDescriptor of type None, A 1, B 1, C 1 |

The four-argument factory (`MPSCNNConvolution.h:177`, inherited from the base; the port's base does not
implement it, so this class does) answers the same object with the four shape members set to the arguments.

`channelMultiplier` is derived, not stored. Measured pairs (inputFeatureChannels, outputFeatureChannels) give
whole-number division, with 0 when there are no input channels:

    (1,1) 1   (4,8) 2   (4,4) 1   (4,6) 1   (6,4) 0   (3,4) 1   (4,12) 3   (0,4) 0

## Copy, equality and coding, measured

- A copy is of the same class and answers the same members. The copy does not share with the original: a later
  change to the original does not reach the copy.
- `isEqual:` is object identity on Apple's object. Two fresh objects are not equal, a fresh object is not equal to a
  set one, and a copy is not equal to its original, and the hashes differ. The port has the same behaviour, because
  it adds no equality of its own.
- A secure-coding archive of the object round-trips, and the shape members come back.

## What the port carries, and what it does not

Carried, and compared with Apple's object in the test: every shape member, the neuron type and parameters A and B,
`channelMultiplier`, the four-argument factory, the copy, equality for set and unset values, and the coding of the
shape members.

**The base's defaults.** `MPSCNNConvolutionDescriptor10.m`'s `init` leaves the kernel size, the channel counts and
the neuron parameters A and B at zero, and its fresh object's `fusedNeuronDescriptor` is nil. This class's `init`
sets Apple's values after the base's, so this class answers Apple's defaults. The base itself still answers the
zeros for a fresh `MPSCNNConvolutionDescriptor`; that is a defect in the base file, outside this change, and is
recorded for the coordinator rather than fixed here.

**Not carried: `fusedNeuronDescriptor`.** Apple's fresh object has a non-nil `MPSNNNeuronDescriptor`. The port has no
such class: it is an iOS 11.3 object (`MPSCNNElements10.m:278` says so), so the port answers the base's nil. The
test prints this as a note and does not count it.

## Not measured

- Apple's neuron behaviour through the descriptor on a running kernel. Only the descriptor's own answers are compared.
- Apple's archive keys. The port's archive keys are its own; the test compares the shape a secure round trip returns,
  not the bytes.
- Any behaviour of a convolution built from the descriptor. The descriptor is compared, the convolution is not.
