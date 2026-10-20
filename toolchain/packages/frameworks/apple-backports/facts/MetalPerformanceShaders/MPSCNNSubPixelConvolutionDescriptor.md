# MPSCNNSubPixelConvolutionDescriptor (iOS 11.0)

The class is `MPSCNNSubPixelConvolutionDescriptor : MPSCNNConvolutionDescriptor`, declared at
`MPSCNNConvolution.h:326-360` in the iOS 16.4 SDK. Its one own member is `subPixelScaleFactor` (readwrite, :358),
the upscaling factor r of the reshape the header describes at :341-349. The port is
`MPSCNNSubPixelConvolutionDescriptor11.m`; the base it subclasses is `MPSCNNConvolutionDescriptor10.m`.

## What was measured, and where

Host: this Mac, macOS 27.0.1 (Darwin 27.0.0), arm64, an Apple M4 Pro, with the macOS SDK `xcrun` selects. Apple's
object is the release's own framework, and the port's object is built from the port's source in the same process.
The differential is `tests/backports/host/mps-cnn-descriptors/cases.m`, run by `run.sh`, which builds for macOS
(see `MPSCNNDepthWiseConvolutionDescriptor.md` for why not Catalyst). The run passes 58 of 58 checks.

## Apple's defaults

A fresh object answers, measured on Apple's object:

- `subPixelScaleFactor` is **1**.
- Every shape member and the neuron are the same as the depthwise class's fresh object: every shape member 1,
  strides 1, groups 1, dilation 1, neuronType None, neuron parameters A and B 1. The fused neuron descriptor is
  non-nil on Apple's object (see the depthwise page).

The four-argument factory answers an object of the class with `subPixelScaleFactor` 1.

Copy: the copy is of this class and keeps the factor. Measured in the test on Apple's object: a copy made with a factor
of 2 still answers 2 after the original is set to 1. Equality is object identity, as for the depthwise class: a copy is not equal to its original,
and an object is equal to itself.

Coding: a secure archive round-trips, and the factor comes back (measured on Apple's object, and the port's
round trip is compared with it in the test).

## What the port carries, and what it does not

Carried, and compared with Apple's object: the defaults, the factor's default of 1, the four-argument factory, a set
object (every shape member, the neuron, and factor 2), the copy and its independence, equality for set and unset
values, and the secure-coding round trip of the shape and the factor.

The defaults of the inherited shape members and the neuron are set by this class's `init` for the same reason as in
the depthwise class, and the base's own defaults are a defect recorded there.

**Not carried: `fusedNeuronDescriptor`**, for the same reason as the depthwise class (an iOS 11.3 object the port does
not have). The test prints it as a note and does not count it.

**The setter does not assert.** Apple's `setSubPixelScaleFactor:` aborts the process when `outputFeatureChannels` is
not a multiple of the square of the factor. Measured: with 16 output channels, setting a factor of 3 is a failed
assertion (`MPSCNNConvolution.mm:685`, the message says "outputFeatureChannels (16) in convolution descriptor must be
multiple of scaleFactor*scaleFactor=9"), and the process ends. The port stores any value. This is not claimed as
matched: a port that stores 3 for 16 channels does not do what Apple's does. The test never sets such a value.

**The secure-coding answer.** This class overrides `-initWithCoder:`, so it answers `+supportsSecureCoding` YES itself.
Without that the secure round trip fails (measured in this test before the method was added).

## Not measured

- The assertion above, on the port: it is a difference, not a measured match.
- Whether Apple's factor setter asserts for a factor of 0.
- Any convolution built from the descriptor, or a sub-pixel reshape run through a kernel.
- Apple's archive bytes or keys.
