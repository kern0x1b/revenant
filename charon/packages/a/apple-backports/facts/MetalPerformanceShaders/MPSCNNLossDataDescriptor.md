# MPSCNNLossDataDescriptor (iOS 11.3)

## What was measured, and where

Measured on the host: Apple M4 Pro, macOS 27.0.1, SDK 27.0. The oracle is Apple's own `MPSCNNLossDataDescriptor`
in the system's MetalPerformanceShaders framework. The port (`MPSCNNLossDataDescriptor11.m`) is compiled for Catalyst
(`arm64-apple-ios16.0-macabi`) beside Apple's framework, with every class the port defines renamed
`CharonHost<Name>`, and both run in one process. The comparison is `tests/backports/host/mps-loss-descriptors/`
(`run.sh`, `descriptor.m`). Its result on this host: 70 checks, 0 failures, and the mutant (a changed default in a
scratch copy of `MPSCNNLossDescriptor11.m`) turns the loss-defaults check red.

Probe programs under `.agent-work/runs/mps-loss/probe/` produced the first readings of the rules below; the test
reproduces each of them against Apple's object.

## Apple's answers

- **The factory** `cnnLossDataDescriptorWithData:layout:size:` takes the data, which the descriptor does not keep, and
  a layout and a size. Layout 0 (`MPSDataLayoutHeightxWidthxFeatureChannels`) gives `bytesPerRow` = width x feature
  channels x 4 and layout 1 (`MPSDataLayoutFeatureChannelsxHeightxWidth`) gives `bytesPerRow` = width x 4. In both,
  `bytesPerImage` = `bytesPerRow` x height. Checked for sizes 3x2x4, 5x3x2, 1x1x1, 7x11x13 and 0x2x2.
- **Layouts outside the enum** (2, 7, and -1 as an unsigned value) abort the release. The port returns nil for them
  and logs once through `CharonMPSRefuse`, which is the package's refusal convention.
- **The data's length is not checked.** Ten bytes for a 3x2x4 size, 200 bytes, and empty data with a zero size are
  all accepted; a zero size answers a descriptor with zero byte counts.
- **`-init`** is `NS_UNAVAILABLE` in the header, but the runtime answers a zeroed object: layout 0, size 0x0x0,
  `bytesPerRow` 0, `bytesPerImage` 0. The port does not override `-init`, so it answers the same.
- **Setters.** `bytesPerRow` and `bytesPerImage` are stored as set.
- **Copy.** `-copy` carries all five members. A later change to the original does not reach the copy.
- **Equality** is object identity on both sides: `isEqual:` is NO between a copy and its original, YES with itself,
  NO against an unset descriptor, and hashes differ. The port does not override either.
- **Protocols.** `NSCopying` yes. `NSSecureCoding` no, as the header says (it declares only `NSCopying`).

## Not measured

- The iOS 11.3 to 16.x behaviour: the host is macOS 27.0.1, and the port runs under Catalyst on it. The iOS 6.1.3
  armv7 device is not measured.
- The data itself. The header gives the descriptor no accessor for its `NSData`, so whether Apple keeps or copies it
  is not observable here, and the port does not keep it. The labels object that consumes the data is not carried.
- The byte counts for layouts beyond the two measured ones: there are no others in the enum.
- Refusal text. Only the abort (for Apple) and the nil (for the port) are compared, not the log wording.
