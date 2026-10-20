# MPSCNNYOLOLossDescriptor (iOS 12.0)

## What was measured, and where

Measured on the host: Apple M4 Pro, macOS 27.0.1, SDK 27.0. The oracle is Apple's own `MPSCNNYOLOLossDescriptor` in
the system's MetalPerformanceShaders framework. The port (`MPSCNNYOLOLossDescriptor12.m`) is compiled for Catalyst
beside Apple's framework with its classes renamed `RevenantHost<Name>`, and both run in one process. The comparison is
`tests/backports/host/mps-loss-descriptors/` (`run.sh`, `descriptor.m`): 70 checks, 0 failures on this host in the
same run as the other three classes, and the mutant turns the loss-defaults check red.

## Apple's answers

- **The factory** `cnnLossDescriptorWithXYLossType:WHLossType:confidenceLossType:classesLossType:reductionType:anchorBoxes:numberOfAnchorBoxes:`
  builds four `MPSCNNLossDescriptor`s, one per output, each with the given type and the given reduction type. Its
  own defaults are the loss descriptor's (see `MPSCNNLossDescriptor.md`), measured as sub-descriptors here too.
- **The factory's own values**, measured for two sets of types (one with reduction Mean and two anchors, one with
  reduction Sum and three anchors): `rescore` YES, `scaleXY` 10, `scaleWH` 10, `scaleNoObject` 5, `scaleObject` 100,
  `scaleClass` 2, `minIOUForObjectPresence` 0.7, `maxIOUForObjectAbsence` 0.3.
- **The factory's arguments as stored:** `anchorBoxes` is retained, not copied (a later change to the caller's array
  shows through), and `numberOfAnchorBoxes` is stored as given: five over sixteen bytes reads back as five.
- **Refusals in the factory.** A reduction type of 4 aborts, and a loss type of 10 on any of the four sub-types aborts.
  A reduction type of -1 is accepted. The port returns nil for the refused values and accepts -1.
- **Setters are not checked:** `reductionType` (4 is stored), the scales, thresholds and `rescore`, the four
  sub-descriptors (retained as given, so the setter's object is the getter's object), and `anchorBoxes`.
- **Copy** deep-copies the four sub-descriptors (a change made to the original's loss does not reach the copy) and
  shares the anchor boxes (the same object).
- **`-init`** is `NS_UNAVAILABLE`, but the runtime answers a zeroed object: every number 0, `rescore` NO,
  `anchorBoxes` and the four sub-descriptors nil. The port does not override `-init`, so it answers the same.
- **Equality** is object identity; `NSSecureCoding` is not declared, as the header says.

## Not carried: reduceAcrossBatch

The 16.4 header declares `reduceAcrossBatch` on this class with `MPS_AVAILABLE_STARTING(macos(11.0), ios(14.0), ...)`.
That is later than this class's iOS 12.0 declaration, so under the brief's rule (carry only the members the 12.0
declaration has) the port does not carry it, and this class is not required to answer it. The release's own default
is NO, measured with the factory above (`reduceAcrossBatch` 0), and the test does not compare it because the port has
no such member. On `MPSCNNLossDescriptor` the same member is carried, with explicit accessors, because that class is
11.3 and the member's 14.0 availability is a later one.

## Not measured

- The iOS 12.0 to 13.x release, and the iOS 6.1.3 armv7 device. The host is macOS 27.0.1 under Catalyst.
- The loss filter (`MPSCNNYOLOLoss`) that consumes the descriptor: no encode is run here.
- The release's `reduceAcrossBatch` on iOS 14 and later, which the port does not carry.
