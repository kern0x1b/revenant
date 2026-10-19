# AVCapturePhotoBracketSettings and the bracketed capture, iOS 10.0 and 11.0

What the port builds: the settings class (`AVCapturePhotoBracketSettings.m`, its two factories and its properties), the
output's bracketed capture (`AVCapturePhotoOutput.m`, `revenant_captureOne:` and `capturePhotoWithSettings:delegate:`), and
the 11.0 photo the bracket's callbacks deliver (`AVCapturePhoto11.m`, facts/AVFoundation/AVCapturePhoto11.md).

## What the header says (iPhoneOS 26.2 SDK, AVCapturePhotoOutput.h)

- `AVCapturePhotoBracketSettings` is a subclass of AVCapturePhotoSettings, available from iOS 10.0 and unavailable on macOS.
  Its factories take `bracketedSettings`, an array of AVCaptureBracketedStillImageSettings (the 8.0 classes the port already
  carries, AVCaptureBracket8.m). The 10.0 factory names no file types; the 11.0 factory names the RAW and the processed file type.
- The factories raise NSInvalidArgumentException for a nil or empty array, and for a mix of the manual and the auto classes.
- At capture, `bracketedSettings.count` must be at most the output's `maxBracketedCapturePhotoCount`, else the capture raises.
- Manual members: ISO and exposure duration must lie in the device's activeFormat ranges. Auto members: the exposure target bias
  must lie in the device's `minExposureTargetBias` and `maxExposureTargetBias`.
- `lensStabilizationEnabled` defaults to NO and may be YES only when `lensStabilizationDuringBracketedCaptureSupported` is YES.
- The 11.0 callback `-captureOutput:didFinishProcessingPhoto:error:` fires `resolvedSettings.expectedPhotoCount` times for one
  request, and `photoCount` is the photo's 1-based index in it. The 10.0 callback takes the bracket setting of each photo as its
  `bracketSettings` argument.

## What 6.1.3 has (measured)

- The objc inventory of the 6.1.3 armv7 shared cache (`objc.inventory`, facts/AVFoundation/Demand8.md) finds no
  AVCapturePhotoOutput, no AVCapturePhotoSettings, no AVCapturePhoto and no AVCapturePhotoBracketSettings
  (`tools/cache-index/first-rung.lua _OBJC_CLASS_$_AVCapturePhoto` answers 11.0, the first held rung that carries it, so
  no rung of 6.1.3 or before does; re-measured 2026-10-18 on the current index). The port's output is an
  AVCaptureStillImageOutput subclass (facts/AVFoundation/AVCapturePhotoOutput.md, "Why the output is a still image output").
- `AVCaptureDevice`'s own exposure selectors on 6.1.3 (Demand8.md, the same query on the 8.0 cache for the public names):
  the private `-setAutoExposureBias:` and `-autoExposureBias`; the private `-setExposureDuration:`, `-exposureDuration`,
  `-setExposureGain:`, `-exposureGain`; `-setExposureMode:`, `-exposureMode`, `-isExposureModeSupported:`;
  `-setExposurePointOfInterest:` and `-exposurePointOfInterest`. No ISO member and no bounds accessor of any name exists for
  the bias (AVFoundation80.md, Demand8.md).
- The public `-setExposureTargetBias:completionHandler:`, `exposureTargetBias`, `maxExposureTargetBias` and
  `minExposureTargetBias` are 8.0 names. The port drives the private pair for the first (AVFoundationDemand8.m) and leaves the
  bounds absent (Demand8.md).
- `AVCaptureStillImageOutput` on 6.1.3 has `captureStillImageAsynchronouslyFromConnection:completionHandler:` and none of the
  8.0 bracket members (see "Not carried").

## What the bracket applies, member by member

A bracket of N members is N stills, in order. Each member is applied with the controls 6.1.3 has for it:

| Member or setting | 6.1.3 control | Applied |
| --- | --- | --- |
| `AVCaptureAutoExposureBracketedStillImageSettings.exposureTargetBias` | the private bias pair, under `lockForConfiguration` (the same setter `-setExposureTargetBias:completionHandler:` drives) | Yes: set before the member's still. The camera's own bias, read before the bracket, is given back after the last photo. |
| `AVCaptureManualExposureBracketedStillImageSettings.exposureDuration` | the release's private `-setExposureDuration:` (CMTime) and `-exposureDuration`, measured on the 6.1.3 runtime (below) | Yes, device-unverified: set under the camera's lock before the member's still; the camera's own duration, read before the bracket, is given back after the last photo. |
| `AVCaptureManualExposureBracketedStillImageSettings.ISO` | the release's private `-setExposureGain:` (float) and `-exposureGain`, measured on the runtime; the gain's unit is not measured | Yes, device-unverified: the ISO is passed as the gain, given back after the last photo with the duration. **Open crutch: the ISO-to-gain mapping is unmeasured, and stays unmeasured until a 4S is attached.** See "Manual exposure". |
| `AVCapturePhotoSettings.flashMode` (the request's, applied to every photo) | public `-setFlashMode:` on the camera (4.0) | Yes, for each photo, through the output's flash handling (`revenant_setFlashMode:ofCamera:`). |
| Exposure point and lock, focus, white-balance lock | public members of 6.1.3's AVCaptureDevice | Not per member. No bracket member carries them; they are the application's own settings on the device, which the bracket does not change. |

The last row is a reading of the coordinator's instruction to apply each setting with exposure point and lock, focus, flash and
white-balance lock. Exposure lock applied per member would hold the exposure fixed and so cancel the bracket, and nothing in the
settings names a focus or a white-balance value. The reading is stated here so it can be overturned.

The bracket's photos are therefore: N stills, each taken with its member's bias (an auto member) or its duration and gain (a manual
member) set in front of it, and the camera's own values given back after the last photo.

## Manual exposure

Measured on the 6.1.3 runtime (`tests/backports/emulate/release-measure`, run `releasemeasure-20261017-152926`, the release's own
frameworks with no port package linked; 6.1.3 has no public manual exposure, and the selectors below are the release's):

| Selector on AVCaptureDevice | Release | Encoding |
| --- | --- | --- |
| `-setExposureDuration:` | instances yes | returns void, argument `{?=qiIq}` (CMTime) |
| `-exposureDuration` | instances yes | returns `{?=qiIq}` (CMTime) |
| `-setExposureGain:` | instances yes | returns void, argument `f` (float) |
| `-exposureGain` | instances yes | returns `f` (float) |
| `-setExposureMode:` / `-exposureMode` | instances yes | `i` (int) |
| `-setManualExposureSupportEnabled:` / `-isManualExposureSupportEnabled` | instances yes | `c` (BOOL) |
| `-setAutoExposureBias:` / `-autoExposureBias` | instances yes | `f` (float) |
| `-setExposureTargetBias:completionHandler:`, `-setExposureTargetBias:`, `-setExposureModeCustomWithDuration:ISO:completionHandler:`, `-deviceType` | instances no | the 8.0 and later API; the port's own category supplies the first, see below |

No ISO setter exists on 6.1.3 (`-setExposureModeCustomWithDuration:ISO:completionHandler:` is 8.0). The port drives the private
duration and gain setters under `lockForConfiguration`, the same lock as the bias.

**Open crutch (coordination/crutches.md): the ISO-to-gain mapping is unmeasured.** The release's gain (`setExposureGain:`, a float) has
a unit that no run here shows, so passing the ISO as the gain is an assumption. It stays open until a 4S is attached and the gain's
effect on the exposure is measured there. The exposure mode a custom duration needs is in the same position and is open with it.
Until then the manual member's duration and gain are applied as the release's own setters take them, and nothing here claims more.

## maxBracketedCapturePhotoCount

The port answers **three**: `RevenantBracketedCapturePhotoLimit` in AVCapturePhotoOutput.m, the count its bracket path delivers and
its capture enforces (a bracket above it is refused at capture with the header's rule as its text, `revenant_checkBracket:`).

Derivation from the code. The bracket is a chain of stills: the next still is taken when the previous photo's callbacks have
returned (`revenant_captureOne:` completes, then the next step), and the port holds no sample buffer past its callback. So nothing in
the chain bounds the count; the bound is the one the port states and enforces. Three is the bracket the probe exercises
(`tests/backports/emulate/photobracket`, the three auto members), so the answer is the count the port has been built to deliver
and checks, not a count it has not checked.

What this is not:
- Not the host's answer. The macOS AVCapturePhotoOutput answers 0 (measured, `host-photo/run-3.log`): the property is present at
  run time, and the Mac has no bracket support (its bracket factories raise). The port does deliver brackets, so 0 would refuse
  every bracket it takes.
- Not infinity, and not a capacity of the 4S. No device is attached, so the 4S's own limit is not measured. A measured device limit
  replaces this value; until then it is an implemented limit of the port, and the registry row says so
  (`ios10capturephoto.json`, `AVCapturePhotoOutput.maxBracketedCapturePhotoCount`).

## lensStabilizationDuringBracketedCaptureSupported

NO. The 4S has no lens stabilization. A bracket whose `lensStabilizationEnabled` is YES is refused at capture
(`NSInvalidArgumentException`, with the header's rule as its text).

## The capture

- The request counts as one capture in flight, from its call until its last photo is delivered.
- The photos run one after another: the next member's still is taken after the previous photo's callbacks.
- Callbacks: `willBeginCaptureForResolvedSettings:` once, before the first photo; `willCapturePhotoForResolvedSettings:`,
  `didCapturePhotoForResolvedSettings:` and the photo callback for each photo; `didFinishCaptureForResolvedSettings:error:` once,
  after the last. The camera's flash mode is given back after the last photo, as for a single capture.
- Each photo's callback carries its member: the AVCapturePhoto's `bracketSettings` is the member, its `photoCount` is the index
  (1-based), and its `resolvedSettings.expectedPhotoCount` is the bracket's count. The 10.0 callback gets the member as its
  `bracketSettings` argument.
- The bias of an auto bracket is set under the camera's lock, which the header requires; a camera that cannot be locked keeps its
  bias and the photo is taken at it, logged.

Refusals at capture: a count above `maxBracketedCapturePhotoCount` (cannot occur with the port's value), lens stabilization YES
where it is not supported, and a delegate with neither photo callback. A single request is refused in the same way it was before
the bracket was carried, except that the 11.0 callback now satisfies the rule.

## Not carried, and owed

- **AVCaptureStillImageOutput's own bracket members** (8.0): `captureStillImageBracketAsynchronouslyFromConnection:withSettingsArray:completionHandler:`,
  `prepareToCaptureStillImageBracketFromConnection:withSettingsArray:completionHandler:`, `maxBracketedCaptureStillImageCount`,
  `lensStabilizationDuringBracketedCaptureEnabled` and `lensStabilizationDuringBracketedCaptureSupported` on that class,
  `highResolutionStillImageOutputEnabled`, `stillImageStabilizationActive`, `stillImageStabilizationSupported` and
  `automaticallyEnablesStillImageStabilizationWhenAvailable`. They are the still output's own bracket API, which this port
  carries only where the photo output needs it. Owed: what they need is the still output's bracket delivered as an array of
  sample buffers at one completion, which the photo output's chain does not provide.
- **The header's device checks**: the exposure ranges (`minExposureTargetBias`, `maxExposureTargetBias`, the activeFormat's ISO and
  duration ranges). 6.1.3 reports none (Demand8.md), so the port checks none; a bias or duration outside what the sensor allows
  is not refused.
- **Manual exposure** on the 4S: applied through the release's private pair (above). Open crutch: the ISO-to-gain mapping, unmeasured
  until a 4S is attached; the custom-duration mode likewise.
- **Measurement on a device.** Nothing here has been captured on the 4S. The bias's effect on the exposure, the time between the
  stills and the photos' pixels are unmeasured.
- **Overlapping requests.** A second request asked while a bracket runs starts its own still at once; the output's queue does not
  wait for a capture's completion. What the still image output does with two captures in flight from one connection is not
  measured here.

## The emulator

tests/backports/emulate/photobracket: the probe (app/main.m) checks the factories, members, refusals, the output's values and
refusals, the bracket's callback order, each photo's member and count, a single capture through the 10.0 callback, and the
AVCapturePhoto object from a BGRA buffer, a JPEG and an error. The emulator's captures end in AVFoundationErrorDomain -11800
(facts/AVFoundation/AVCapturePhotoOutput.md), so the bracket's photos are error photos there: the probe checks the sequence of
callbacks and the members, not pixels.

Result (iPhone4,1 at 6.1.3, 10B329, `run-app.sh` through heavy.sh; run `.agent-work/runs/v-impl-avf-1/photobracket-20261017-110255`):
26 of 30 checks pass: the factories, the members, the refusals, the output's values (the maxBracketedCapturePhotoCount port
answer, lens stabilization) and the photo objects (BGRA buffer, CGImage, JPEG file, metadata, error photo). Four fail, all of
them the camera: the emulator image reports 0 video devices (`camera-present`), so `camera-input`, `session-built` and
`connection-present` fail. The capture checks, which are the bracket's callback order, each photo's member and count, and the
single 10.0 capture, do not run on a session that has no camera: the bracket capture is NOT verified on the emulator. The
-11800 captures described above were not reproduced by this run, which had no camera to capture with. Re-running needs an
emulator image that presents a camera device; the probe then runs the capture checks unchanged.

## Host and device status (this session)

- **Device.** No iOS device is attached: `xmake device list` shows no holder and no tunnel, `idevice_id -l` lists none, and the
  device.env host does not answer. Every measurement that needs the 4S is therefore device-unverified: the exposure-bias effect, the
  manual duration and gain effects and the gain unit, the not-carried answers on the 4S, the bracket's callbacks and pixels, and the
  bracket limit.
- **Host callback order** (the macOS AVCapturePhotoOutput with the MacBook camera): the camera opens and the session runs, but
  `AVCaptureDevice.authorizationStatusForMediaType:` is 0 (not determined) for the probe binary, so no frame arrives and no photo
  callback is delivered in 60 s (`host-photo/run-3.log`). The callback order per delegate (both callbacks, the 11.0 callback only,
  the 10.0 callback only) is therefore not measured. It needs the camera permission granted to the probe, a decision for the owner.
- **Emulator.** The 6.1.3 emulator has no camera device, so the photobracket probe's capture checks do not run. On origin/main
  `a6a64b263` the probe installs and runs (`photobracket-20261017-154406`): 26 of 30 checks pass. The four failures are
  camera-present, camera-input, session-built and connection-present. Among the passing checks is `photo-bgra-cgimage`: the BGRA
  still converts to a CGImage through CoreImage on the port's own path, with an IOSurface-backed buffer. The bracket is therefore
  **not verified on the emulator**. (An earlier run on d7b5d3cb10, `photobracket-20261017-111030`, showed the same 26 of 30; the
  apple-backports install failed on the base in between, 184dcf16c1, and main's split of the 16.0 name objects fixed it.)
- **Release measurement** (`tests/backports/emulate/release-measure`, device-free, no port package): the signatures above, and the
  CoreImage steps in facts/AVFoundation/AVCapturePhoto11.md, "CoreImage on 6.1.3".
