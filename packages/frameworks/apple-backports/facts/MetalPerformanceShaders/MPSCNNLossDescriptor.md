# MPSCNNLossDescriptor (iOS 11.3)

## What was measured, and where

Measured on the host: Apple M4 Pro, macOS 27.0.1, SDK 27.0. The oracle is Apple's own `MPSCNNLossDescriptor` in the
system's MetalPerformanceShaders framework. The port (`MPSCNNLossDescriptor11.m`) is compiled for Catalyst beside
Apple's framework with its classes renamed `RevenantHost<Name>`, and both run in one process. The comparison is
`tests/backports/host/mps-loss-descriptors/` (`run.sh`, `descriptor.m`): 70 checks, 0 failures on this host, and the
mutant (the factory's default weight changed to 2.0 in a scratch copy) turns the loss-defaults check red on
`weight: apple 1, port 2`.

## Apple's answers

- **The factory** `cnnLossDescriptorWithType:reductionType:` takes the two types as arguments. Defaults, the same
  for every loss type 0 to 9 and every reduction type -1 to 3: `reduceAcrossBatch` NO, `weight` 1, `labelSmoothing`
  0, `numberOfClasses` 1, `epsilon` 1e-7, `delta` 1.
- **Refusals in the factory.** A loss type of 10 or -1 aborts the release, and so does a reduction type of 4. A
  reduction type of -1 is accepted (the reduction is a signed enum). The port returns nil for the three refused values
  through `RevenantMPSRefuse`, and accepts -1.
- **Setters that the release validates**, each against the loss type the descriptor holds at the moment of the set,
  measured for all ten loss types:
  - `labelSmoothing` only for softmax cross entropy (type 2) and sigmoid cross entropy (type 3);
  - `numberOfClasses` only for softmax cross entropy (2);
  - `epsilon` only for log (8);
  - `delta` only for Huber (6).
  Any other type aborts the release. The port keeps the value and logs, so a set is refused without a crash. Changing
  the loss type afterwards is not checked, and neither is a set made before it.
- **Setters that the release does not check:** `lossType` (10 is stored), `reductionType` (4 is stored), `weight`,
  `reduceAcrossBatch`.
- **`reduceAcrossBatch`** is declared at iOS 14.0 in the 16.4 header, later than this class's 11.3. The port writes its
  accessors out explicitly, as the coordinator's brief asks, so the member's availability is recorded here and not
  inferred from the class.
- **`-init`** is `NS_UNAVAILABLE`, but the runtime answers a zeroed object: `lossType` 0, `reductionType` 0, `weight`
  0, `labelSmoothing` 0, `numberOfClasses` 0, `epsilon` 0, `delta` 0, `reduceAcrossBatch` NO. The port does not
  override `-init`, so it answers the same.
- **Copy** carries all eight members, and a later change to the original does not reach the copy.
- **Equality** is object identity on both sides; `NSSecureCoding` is not declared, as the header says.

## Not measured

- The iOS 11.3 to 13 behaviour of `reduceAcrossBatch`, which the release does not have there: the host is macOS
  27.0.1. The port answers the member on every release it targets, so on an iOS 11 to 13 device it is a member the
  release does not have.
- The filter that consumes the descriptor (`MPSCNNLoss`, `MPSNNLossGradient`): no encode is run here.
- Validated setters on a loss type outside 0 to 9. The `lossType` setter stores 10 unchecked, so a descriptor can hold
  it. A later `labelSmoothing` set on it is refused by the port (type 10 is not softmax or sigmoid), and the release is
  expected to refuse it too, but that is not measured: the test's setter matrix covers types 0 to 9 only.
- The values of the setters at the edges of their range (a `NaN` or a huge `numberOfClasses`).
