# AVCapturePhoto, iOS 11.0

The class the 11.0 callback `-captureOutput:didFinishProcessingPhoto:error:` delivers (AVCapturePhotoOutput.h, 26.2 SDK,
`AVCapturePhoto` at line 1979 and its categories). 6.1.3 has no such class (facts/AVFoundation/AVCapturePhotoBracketSettings.md,
"What 6.1.3 has"), so the port defines it in `AVCapturePhoto11.m`. Its members answer from the still's sample buffer, the
preview's, and the settings the capture resolved.

## Members

| Member (header) | Answer | Source |
| --- | --- | --- |
| `timestamp` | the still's presentation time, or invalid for an error photo | the sample buffer |
| `rawPhoto` (`isRawPhoto`) | NO | 6.1.3's still output makes no RAW photo |
| `pixelBuffer` | the buffer of an uncompressed still; NULL for a JPEG | the sample buffer; the header's NULL for a processed compressed photo |
| `previewPixelBuffer` | the preview sample's buffer, NULL when no preview was asked | the preview sample |
| `embeddedThumbnailPhotoFormat` | the settings' own dictionary | the request |
| `depthData`, `portraitEffectsMatte`, `cameraCalibrationData` | nil | the 4S has no depth, no portrait matte and no calibration (below) |
| `semanticSegmentationMatteForType:` | nil | the port's photo output makes no matte |
| `metadata` | the properties of the JPEG container (ImageIO), `{}` for an uncompressed still or an error | the still's JPEG |
| `resolvedSettings` | the request's resolved settings, always non-nil | AVCaptureResolvedPhotoSettings.m |
| `photoCount` | the 1-based index of the photo in its request | the capture |
| `sourceDeviceType` | nil | a single camera names no source (virtual device constituents are not carried) |
| `bracketSettings` (11.0) | the bracket member the photo was taken for; nil for a single capture | facts/AVFoundation/AVCapturePhotoBracketSettings.md |
| `fileDataRepresentation` | the JPEG's own bytes; nil for an uncompressed still (no file container on this release) | the still's JPEG |
| `CGImageRepresentation` | the still as a new CGImage at full size, decoded from the JPEG or converted from the buffer | `CharonCreatePhotoImage` (AVCapturePhotoOutput.m) |
| `previewCGImageRepresentation` | the preview as a new CGImage | the same helper |

The header's rule that the photo is non-nil even with an error holds: an error photo is made with no sample, so it answers
NULL, nil and `{}` for its members, and its `resolvedSettings` is the request's.

## Delegate choice

A delegate that implements `-captureOutput:didFinishProcessingPhoto:error:` gets the AVCapturePhoto, one per photo, and the 10.0
sample-buffer callback is not called for it. A delegate with only the 10.0 callback gets the sample buffers, as on 10.0. The header
does not say which callback is called when a delegate implements both: the port's choice is the 11.0 one, which is the newer, and
it is not measured against the host for a delegate that implements both. The request is refused when the delegate implements
neither (the header's 10.0 rule, with the 11.0 callback counted).

## CoreImage on 6.1.3

The uncompressed photo's CGImage is made by CoreImage (`CharonCreatePhotoImage`). Measured on the release's runtime
(`tests/backports/emulate/release-measure`, runs `releasemeasure-20261017-152721` and `-152926`), for a 64 by 48 BGRA buffer:

| Step | Plain buffer (`CVPixelBufferCreate`, no attributes) | IOSurface-backed buffer (`kCVPixelBufferIOSurfacePropertiesKey`) |
| --- | --- | --- |
| `+[CIImage imageWithCVPixelBuffer:]` | nil, no raise | made |
| `+[CIContext contextWithOptions:nil]` | made | made |
| `-createCGImage:fromRect:` of the image | not attempted (no image) | made, 64 by 48 |
| `+[CIImage imageWithCGImage:]` (a CGBitmapContext image) | made | made |

So the conversion does work on 6.1.3, for an IOSurface-backed buffer. A plain buffer is the one that fails, and the reason is the
buffer's backing, not CoreImage's context (measured). The port's photo buffers come from the still output, which the port does not
create itself; on the device the still's buffers are IOSurface-backed by the camera's pipeline, which is not measured here. The
probe's own BGRA buffer is made IOSurface-backed for that reason. The port's helper converts every buffer through CoreImage, as
the release does; a plain buffer is not converted (a nil image, which the helper returns as NULL).

The earlier change to a CGBitmapContext copy for BGRA is withdrawn: it was a swap of path made because the probe's plain buffer
failed, and the measurement shows the path itself works.

## Not carried

- **Depth, portrait matte, semantic segmentation mattes, calibration.** Each member exists and answers nil for every photo, as the
  real system answers for a photo that has no such data. The reason is the hardware: the 4S has one camera and no depth sensor.
  The output's own availability queries say the same (`depthDataDeliverySupported`, `portraitEffectsMatteDeliverySupported`,
  `cameraCalibrationDataDeliverySupported` answer NO, `availableSemanticSegmentationMatteTypes` is empty), and its setters refuse
  to turn them on (facts/AVFoundation/AVCapturePhotoOutput.md, "The photo output"). The members are not left unimplemented: they
  answer the photo's own absence of the data, with the output's queries as the source.
- **RAW and Apple ProRAW.** `isRawPhoto` is NO for every photo: the output offers no RAW pixel format (`availableRawPhotoPixelFormatTypes`
  is empty), so no photo the port delivers is RAW.
- **`sourceDeviceType`** is carried: the device type of the camera that took the photo, `AVCaptureDevice.deviceType` (wide angle for
  a video camera, AVCaptureDevice+DeviceType.m), passed in when the photo is made. The 4S's back camera is a wide angle camera by
  that rule; on a device the answer is the camera's own, which no run here can show (no device attached; facts/AVFoundation/AVCapturePhotoBracketSettings.md, "Host and device status").
  A photo made without a camera names none (nil).
- **Virtual device constituent photos.** Not carried: a single camera.
- **The 18.0 members** (`constantColorConfidenceMap`, `constantColorCenterWeightedMeanConfidenceLevel`,
  `constantColorFallbackPhoto`) are not in the 16.4 SDK the port compiles against and are not carried; their registry rows, if any,
  are owed.

## Owed

- **`-fileDataRepresentationWithCustomizer:`** (12.0, the `AVCapturePhotoFileDataRepresentationCustomizer` protocol, its
  replacement matte and ProRAW compression methods). Owed: the file container writer that takes a replacement matte and a
  compression setting, which a JPEG-only port with no matte does not have. Until it exists the method is not implemented, and a
  caller that asks for it gets the selector's unrecognized-selector error, which is what absent means.
- **`AVCapturePhotoCaptureDelegate`** (the protocol): its forward row is in `spec/protocol-headers.tsv` (AVFoundation 13), so the
  generated header declares it, and the 16.4 SDK declares it for the compile.

## Verification

tests/backports/emulate/photobracket builds the object from a BGRA buffer, a JPEG (encoded by ImageIO in the probe) and an error,
through the port's own initializer, and checks each member above that the probe names. The result is in the bracket facts file.
No photo from the 4S's own camera is checked: the emulator's captures end in -11800.
