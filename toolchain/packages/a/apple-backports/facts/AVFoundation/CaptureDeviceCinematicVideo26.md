# The Cinematic Video family of iOS 26: 10 rows, one object

`AVFoundation/AVCaptureDeviceCinematicVideo26.m` carries all ten - seven properties and three methods - over
the same three classes the two slices above it in this folder carry. Registry:
`registry/AVFoundation/cinematicvideo26.json`, ten rows, one per row the
`coordination/corpus/ledger-2026-10-03/AVFoundation.tsv` snapshot reads `missing` for them at 26.0. Header:
`CharonAVCaptureDeviceCinematicVideo26.h`, transcribed from the SDK 26.2 (`AVCaptureDevice.h:1299-1328`,
`:2682-2696`, `:3782-3818` and `AVCaptureInput.h:425-439`), with two types of its own: the string enum
`AVCaptureSceneMonitoringStatus` and the focus-mode enum `AVCaptureCinematicVideoFocusMode` (the header's own
three values).

## What the feature is, and why this port's devices cannot do it

Cinematic Video "produces a controllable, simulated depth of field and adds beautiful focus transitions for a
cinema-grade look" (`AVCaptureDevice.h:3784`): it renders a depth of field out of two lenses and a depth map
and moves focus between them. A single-lens iPhone 4S or iPad 2 has neither the second lens nor the depth map,
and the release carries no member for any of it - 6.1.3's `AVCaptureDevice`, `AVCaptureDeviceFormat` and
`AVCaptureDeviceInput` own none of these ten selectors (tools/corpus/objc-inventory.lua over the 6.1.3 armv7
cache, and the same for the arm64e caches of 16.0 and 18.0 where they were read for the slices above).

So every answer here is the header's own answer for hardware that lacks the feature, which is what the header
documents for the two formats' rows and what the host's own class answers for the rest.

## The oracle, and the one row it cannot answer

`tests/backports/host/avf-capabilities` asks both sides in one process. **The host's own framework does not
carry `-cinematicVideoCaptureSceneMonitoringStatuses` at all** - measured, `class_getInstanceMethod` finds
nothing and sending it raises `doesNotRecognizeSelector` - so that row has no host cell and the port's answer
comes out of the header alone. The harness has a way to say so and not to paper over it: `expectations.tsv`
records a `-` in that row's host column, the probe prints a `NOHOST` line and an empty host cell for it, and
`run.sh` refuses the run unless both are there. A host that later gains the selector therefore fails the run
with a message asking for a re-measurement, rather than quietly going on comparing nothing.

Every other row the host answers, and its answers are the header's own for hardware that cannot:

| row | host | port |
| --- | --- | --- |
| `AVCaptureDeviceFormat.cinematicVideoCaptureSupported` | 0 (all seven formats) | 0 |
| `AVCaptureDeviceFormat.videoMin/MaxZoomFactorForCinematicVideo` | 1 and 1 | 1 and 1 |
| `AVCaptureDeviceFormat.videoFrameRateRangeForCinematicVideo` | nil | nil |
| `AVCaptureDeviceInput.cinematicVideoCaptureSupported` | 0 | 0 (the active format's answer) |
| `AVCaptureDeviceInput.cinematicVideoCaptureEnabled` | 0 | 0 |
| `setCinematicVideoCaptureEnabled:` YES | raises | raises, **the same string character for character** |
| `setCinematicVideoCaptureEnabled:` NO | accepted, kept 0 | accepted, kept 0 |
| the three focus methods | all three raise | all three raise, Apple's tail with this port's class |

Apple's three focus refusals, measured verbatim, one per method:

```
*** -[AVCaptureDALDevice setCinematicVideoFixedFocusAtPoint:focusMode:] Not supported - use activeFormat.isCinematicVideoCaptureSupported
*** -[AVCaptureDALDevice setCinematicVideoTrackingFocusAtPoint:focusMode:] Not supported - use activeFormat.isCinematicVideoCaptureSupported
*** -[AVCaptureDALDevice setCinematicVideoTrackingFocusWithDetectedObjectID:focusMode:] Not supported - use activeFormat.isCinematicVideoCaptureSupported
```

Each names **the format member the three need**, which is what the port asks: the release's own `-activeFormat`
and then this port's `AVCaptureDeviceFormat` member. The class in Apple's prefix is `AVCaptureDALDevice`, a
private class of its device-access layer; the port names `AVCaptureDevice`, the class it has and the header
declares the members on. For `-setCinematicVideoCaptureEnabled:` no swap is needed: Apple's own string names
`AVCaptureDeviceInput`, which is the class the header declares that member on.

## The one answer that is derived rather than stated

`-isCinematicVideoCaptureSupported` on the input reads the device's **active format** rather than answering NO,
because the header's rule is about the session's configuration and not about the input: "This property returns
`true` if the session's current configuration allows Cinematic Video capture. When switching cameras or formats,
this property may change" (`AVCaptureInput.h:427`). A configuration can only allow what a format supports, so
the port asks the release's own `-device` and `-activeFormat` and then this port's format member, and answers
NO where there is no active format - which is what 6.1.3 answers outside a running session (measured on a
device, facts/AVFoundation/Release11.md). **The plant `cinematic` is what shows the derivation rather than a
constant:** it makes the format claim support, and the input's row, its setter and all three focus methods
move with it - 6 of the 67 table answers.

## Not carried

- **`AVCaptureSceneMonitoringStatusNotEnoughLight`** is a 26.0 `code+lift` row of its own and is **not** here,
  so nothing a caller can name is ever in the set `cinematicVideoCaptureSceneMonitoringStatuses` answers. The
  row says so.
- **Four more Cinematic Video rows sit on other owners** and are not in this delivery:
  `AVCaptureMetadataOutput.requiredMetadataObjectTypesForCinematicVideoCapture` and
  `AVMetadataObject.cinematicVideoFocusMode` (the metadata half, which needs the detection this port has no
  hardware for), and the two `AVMetadataIdentifierQuickTimeMetadataCinematicVideoIntent` /
  `AVMetadataQuickTimeMetadataKeyCinematicVideoIntent` constants (exported symbols).
- **The three `AVCaptureDeviceFormat` simulated-aperture rows** (`defaultSimulatedAperture`,
  `minSimulatedAperture`, `maxSimulatedAperture`) are declared in 26.2's *same* category as four of the rows
  above and are carried with `AVCaptureDeviceInput.simulatedAperture` in the aperture half, which is where the
  setter that can refuse them lives.

## Checks

```
sh tests/backports/host/avf-capabilities/run.sh   exit 0
  ok  AVCaptureDevice.cinematicVideoCaptureSceneMonitoringStatuses is asked of the port alone: expectations.tsv
      records no host column and the probe printed NOHOST for it
  ok  38 members are answered by both sides, or by the port alone where the table says the host has none
  ok  67 answers are the ones expectations.tsv names, the host's and the port's columns both
AVFCAPSMUTANT=cinematic  ok  the mutation was noticed: 6 of 67 table answers, 0 of 8
CONTROL=1 with each of the seven plants  ok  the control is clean
```

### Two more harness defects this family found

1. **A selector with two arguments.** The member list's own regex takes the selector out of `-[Class foo:bar:]`
   with `rstrip(":")`, which leaves `foo:bar`; a declaration is `foo:`. It reported "no declaration in any of
   the port's headers" for the three focus methods while holding the header that declares them. The first piece
   of the selector is what it compares now.
2. **`sys.argv[1:-2]` is not "the pairs".** With four header/prefix pairs the slice is three of them, so the
   fourth header was never read. The pair count is an argument of its own now, and the generator refuses a count
   that does not match what it was given.
