# MPSNNNeuronDescriptor (iOS 11.3)

## What was measured, and where

Measured on the host: Apple M4 Pro, macOS 27.0.1, SDK 27.0. The oracle is Apple's own `MPSNNNeuronDescriptor` in the
system's MetalPerformanceShaders framework. The port (`MPSNNNeuronDescriptor11.m`) is compiled for Catalyst beside
Apple's framework with its classes renamed `CharonHost<Name>`, and both run in one process. The comparison is
`tests/backports/host/mps-loss-descriptors/` (`run.sh`, `descriptor.m`): 70 checks, 0 failures on this host, and the
mutant turns the loss-defaults check red (which is the loss descriptor's check, not this class's; this class has no
mutant of its own).

## Apple's answers

- **The type-only factory** `cnnNeuronDescriptorWithType:` answers a=1, b=1, c=1 for every type that takes no
  parameters from it: types 0 to 9 and 11 to 15, measured one by one.
- **The parameter factories** keep the arguments given, and the parameters not given take 1: `(type, a)` gives b=1
  and c=1; `(type, a, b)` gives c=1; `(type, a, b, c)` takes all three. A negative type (-1) is accepted.
- **The PReLU factory** `cnnNeuronPReLUDescriptorWithData:noCopy:` sets the type to 10 (PReLU) and a, b and c to 0.
  The data is retained as given (the same object), and `noCopy` changes nothing that can be read back: YES and NO give
  the same answer.
- **Refusals.** The release aborts on a PReLU type through any parameter factory, on a type of 16 or past it (16 and
  99 measured), and on a PReLU data length that is not a positive whole number of floats: 0, 1, 2, 3, 5, 6 and 7 bytes
  abort, while 4, 8, 12 and 4096 are taken. The port returns nil for the same calls and logs once through
  `CharonMPSRefuse`.
- **Setters are not checked:** `neuronType` (PReLU and 16 are stored as set, and setting PReLU does not require data),
  `a`, `b`, `c`. `data` is retained as set (the same object).
- **Copy** carries neuronType, a, b and c. The data is copied as an `NSData` (`-[NSData copy]`): a mutable array's
  copy is a snapshot and does not change when the original's bytes change, and an immutable array's copy is the same
  object (both measured).
- **-init** is `NS_UNAVAILABLE`, but the runtime answers a zeroed object: type 0, a, b and c 0, data nil. The port does
  not override `-init`, so it answers the same.
- **Equality** is object identity on both sides; `NSSecureCoding` is declared and `supportsSecureCoding` is YES.
- **Coding.** The archive keys are `MPSNNNeuronDescriptor.neuronType` (an integer), `.A`, `.B` and `.C` (reals), and,
  for a PReLU neuron only, `.PReLuCount` (an integer, the element count) and `.PReLuData` (the data). The port writes
  and reads the same keys, so an archive has the same shape on both sides. An ELU descriptor that holds data does not
  archive it, and reads back with data nil, on both sides.
- **The release's PReLU decoder answers zeros.** A PReLU archive's `.PReLuData` holds the bytes written (measured:
  1.5 and 2.5 are in the archive), but the release's own decoder returns the count of floats in `.PReLuCount` as
  zeros. Two floats read back as 0 0, three as 0 0 0, five as 0 0 0 0 0. The port mirrors that decoder on
  purpose, so an archive that is read on the port means what it means on the release: this is the release's answer,
  not a port choice, and the port writes the data in full, as the release does. The test's PReLU round trip compares
  the two decoders' answers, and both are zeros.

## Not measured

- The archive bytes compared with each other: the class name inside each archive differs (`MPSNNNeuronDescriptor`
  and `CharonHostMPSNNNeuronDescriptor`), so the two are decoded by their own classes and not across.
- A cross-decode of the release's archive by the port, or the reverse: it needs the class name rewritten in the
  archive, which this test does not do.
- The iOS 11.3 to 16.x release, and the iOS 6.1.3 armv7 device. The host is macOS 27.0.1 under Catalyst.
- The neuron filter (`MPSCNNNeuron`) that consumes the descriptor: no encode is run here.
- The convolution descriptor's `fusedNeuronDescriptor`, which is another agent's file and is not compared here.
