# The dynamic aspect ratio, lens smudge detection and simulated aperture of iOS 26: 13 rows, one object

`AVFoundation/AVCaptureDeviceDynamic26.m` carries all thirteen - seven members of `AVCaptureDevice`, five of
`AVCaptureDeviceFormat` and one of `AVCaptureDeviceInput`, with the two setter methods among them - in one
object. Registry: `registry/AVFoundation/dynamic26.json`, thirteen rows, one per row the
`coordination/corpus/ledger-2026-10-03/AVFoundation.tsv` snapshot reads `missing` for them at 26.0. Header:
`CharonAVCaptureDeviceDynamic26.h`, transcribed from the SDK 26.2 (`AVCaptureDevice.h:2698-2736` and
`:3862-3895`, `AVCaptureInput.h:443-452`) with two types of its own: the string enum `AVCaptureAspectRatio` and
the `AVCaptureCameraLensSmudgeDetectionStatus` enum with the header's own four values.

**Neither type's constants are carried.** `AVCaptureAspectRatio`'s five values (`1x1`, `16x9`, `9x16`, `4x3`,
`3x4`) are 26.0 `code+lift` rows of their own, and the smudge status's four are `header-ok`/`lift` rows. So the
supported-ratios array this port answers is empty - a device that can change its shape has none to list - and
nothing a caller can name is ever in it. Both rows and the header say so.

## Three features, one hardware question, and the header answers it for each

| row | host | port | the sentence that decides it |
| --- | --- | --- | --- |
| `dynamicAspectRatio` | nil | nil | "If the activeFormat's `supportedDynamicAspectRatios` is an empty array, this property returns nil" (`:2722`) |
| `dynamicDimensions` | 0x0 | 0x0 | "If the device's activeFormat's `supportedDynamicAspectRatios` is an empty array, this property returns `{0,0}`" (`:2728`) |
| `supportedDynamicAspectRatios` | 0 ratios | 0 ratios | measured on the host for all seven of its formats, and the list both rows above are derived from |
| `cameraLensSmudgeDetectionEnabled` | 0 | 0 | "By default, this property returns `false`" (`:3871`), and the only setter refuses |
| `cameraLensSmudgeDetectionInterval` | kCMTimeInvalid | kCMTimeInvalid | "By default, this property returns `kCMTimeInvalid`" (`:3877`) |
| `cameraLensSmudgeDetectionStatus` | 0 | 0 | the enum's first value is "Indicates that the detection is not enabled" (`:3881`) |
| `defaultSimulatedAperture` | 0 | 0 | "This property return a non-zero value on devices that support the shallow depth of field effect" (`:3893`) |
| `minSimulatedAperture` | 0 | 0 | "On devices that do not support changing the simulated aperture value, this returns a value of `0`" (`:3898`) |
| `maxSimulatedAperture` | 0 | 0 | the same sentence (`:3903`) |
| `simulatedAperture` (input) | 0 | 0 | the three above are what it is bounded by, and the setter refuses below |

A simulated aperture is part of Cinematic Video - a simulated depth of field is what two lenses and a depth
map render - so these three aperture rows are here while the three Cinematic Video rows are in
`AVCaptureDeviceCinematicVideo26.m`, even though 26.2 declares both halves in the same category. That is this
port's hardware: one lens.

## The three setters, each with Apple's own measured reason

```
-[AVCaptureDevice setDynamicAspectRatio:completionHandler:]
  *** -[AVCaptureDALDevice setDynamicAspectRatio:completionHandler:] Dynamic Aspect Ratio not supported by this device
-[AVCaptureDevice setCameraLensSmudgeDetectionEnabled:detectionInterval:]
  *** -[AVCaptureDALDevice setCameraLensSmudgeDetectionEnabled:detectionInterval:] Not supported - use -activeFormat.isCameraLensSmudgeDetectionSupported
-[AVCaptureDeviceInput setSimulatedAperture:]
  *** -[AVCaptureDeviceInput setSimulatedAperture:] Not supported - the source device must have an activeFormat.minSimulatedAperture greater than 0.
```

The first two raise with Apple's **tail character for character** and this port's own class in the prefix
(`AVCaptureDALDevice` is a private class of Apple's device-access layer that this port does not have); the third
raises character for character including the class, because Apple's class there IS the port's class. Each
header rule is quoted beside it in the source, and the aperture setter reads the format's minimum **before**
refusing, so the refusal is the header's rule read through that member and not a written-down refusal.

## The one row where the host has no answer, and how the harness says so

**`-[AVCaptureDeviceFormat isCameraLensSmudgeDetectionSupported]` raises on this host for every one of its
seven formats** - measured: `NSInvalidArgumentException`, reason `-[__NSCFType mediaType]: unrecognized
selector sent to instance 0x...`, raised inside Apple's own `-[AVCaptureDeviceFormat
figCaptureSourceVideoFormat]`. There is no host value for that row.

Two consequences, both in the harness rather than smoothed over: the probe asks that row with its exception
**name** and not its reason, because that reason carries an object's address and is a different string on every
run - and `expectations.tsv` holds `RAISED NSInvalidArgumentException` in the host's cell for that row, with the
measurement and the port's answer beside it. The port answers NO, which is the hardware.

## What the harness needed for this family, and one thing worth knowing about the host SDK

`AVCaptureAspectRatio` is declared by the **host** SDK too, and there it is marked `API_UNAVAILABLE(macos)`,
so a copy of the port's source that spells it in a method signature does not compile against the host at all:
clang says the type is unavailable, and that is an error and not a warning. The harness's generated prologue now
gives the copy its own name for it (the same arrangement its three class renames use), and the port's own build
- the iOS SDK, where the type is available - is untouched. The port's header also drops 26.2's
`API_UNAVAILABLE(macos, macCatalyst, tvos, visionos)` from the typedef, for the same reason and with the
reason stated in the header.

## Checks

```
sh tests/backports/host/avf-capabilities/run.sh   exit 0
  ok  58 members are answered by both sides, or by the port alone where the table says the host has none
  ok  88 answers are the ones expectations.tsv names, the host's and the port's columns both
AVFCAPSMUTANT=smudge  ok  the mutation was noticed: 1 of 88 table answers, 0 of 8
CONTROL=1 with each of the eight plants  ok  the control is clean
```

Eight plants, all noticed: `reactions` (1 of 88), `prefcam` (6 of the 8 preferred-camera steps),
`capabilities` (3 of 88), `multichannel` (4 of 88), `rectsupport` (1 of 88), `cinematic` (6 of 88), `syncmin`
(2 of 88), `smudge` (1 of 88 - a format with a real minimum aperture, which is the number the aperture setter
reads).
