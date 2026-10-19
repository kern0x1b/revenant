# AVDepthData and AVCameraCalibrationData (iOS 11.0)

What the port carries, what the host measured, and the one place they differ. The code is
`AVFoundation/AVDepthData11.m`; the measurements are `tests/backports/host/avf-depthdata`, which asks the same
questions of this Mac's AVFoundation (macOS 27.0.1) and of the port's classes in one binary and diffs the answers
line for line. The declarations are the 16.4 SDK's, read through the generator's spec table
(`.gen/AVFoundation/spec.sdk-26.2-headers.tsv`, the rows for both classes); the header text itself was not used.

## What the port carries

- `AVDepthData`: the depth map as a CVPixelBuffer of one of the four depth formats, its type, quality,
  accuracy, filtering and calibration. Built from a dictionary (`+depthDataFromDictionaryRepresentation:error:`),
  converted between the formats, turned by an EXIF orientation, given a new map of its own format, and written
  back as a dictionary.
- `AVCameraCalibrationData`: the seven fields of the class, all zero. See "Calibration".

## What the host measured, and what the port does

Refusals (both fail with `AVFoundationErrorDomain`):

- a dictionary without its data and its description: code -11865, "Depth is malformed";
- a PixelFormat that is not one of the four depth formats, and a BGRA buffer given as a map: code -11864,
  "Format Unsupported" (the replacement refuses the buffer; the factory refuses the format).

Formats: `availableDepthDataTypes` lists disparity float16, disparity float32, depth float16, depth float32, in
that order. The map of a depth data object is one of them; `depthDataType` is its OSType.

Conversion (measured in both directions on the same values):

- between the two precisions of one family, the values are kept: a float32 value rounds to the float16 nearest;
- between a disparity and a depth, the value is the reciprocal, computed in single precision. Where the
  reciprocal is not finite and positive, or is beyond 10000, or the input is not positive, the answer is 10000
  (measured: 0 -> 10000, -2 -> 10000, 1e-6 -> 10000 both ways, 70000 -> 1/70000 at either precision);
- a conversion to a non-depth format raises `NSInvalidArgumentException` with the reason
  "*** -[AVDepthData depthDataByConvertingToDepthDataType:] Unsupported depth data type";
- a conversion returns a new object, never the receiver, even when the format is the same.

EXIF orientations 1 to 8, measured on a 2x2 map and applied to the 3x2 map of the probe: 1 is the identity, 2 mirrors
across the vertical axis, 3 turns half a circle, 4 mirrors across the horizontal axis, 5 transposes, 6 turns a quarter
clockwise, 7 is the anti-transpose, 8 turns a quarter counter-clockwise. Orientations 5 to 8 exchange the rows and
the columns of the map.

Replacing the map keeps the object's quality, accuracy, filtering and calibration, and takes the buffer's own size
(measured: a 2x2 buffer over a 3x2 map gives 2x2).

The dictionary a depth data object gives back has three keys, the data (the map's bytes, one row at the buffer's
own stride), the description (Width, Height, BytesPerRow, PixelFormat) and the metadata. Its type is
`kCGImageAuxiliaryDataTypeDisparity` for a disparity format and `kCGImageAuxiliaryDataTypeDepth` for a depth format
(both measured). The key strings are the host's: `kCGImageAuxiliaryDataInfoData`,
`kCGImageAuxiliaryDataInfoDataDescription`, `kCGImageAuxiliaryDataInfoMetadata`. They are spelled as strings
because 6.1.3's ImageIO exports no symbol for them.

## The named divergence: the metadata

The host's metadata entry is a `CGImageMetadata` object. 6.1.3 has no such type to return, so the port writes the
same facts as text and reads them back from text:

    depthData:Quality = high | low
    depthData:Filtered = True | False
    depthData:Accuracy = absolute | relative

The probe gives both sides a metadata string, and the host reads a string differently from its own object: every
string reads as high quality, whatever its Quality line says, and its Accuracy and Filtered lines are not read. So
the probe's metadata cases (`metadata-0` to `metadata-4`, `tagged`, `tagged-converted`) differ between the two
sides, and `run.sh` allows exactly those labels. A dictionary the host wrote itself, with no metadata, round trips
the same on both sides (`bare-reparsed`).

Without metadata: quality low, accuracy relative, not filtered (measured).

## Calibration

The host's public `-init` of AVCameraCalibrationData is marked unavailable in the header, and sent by name it segfaults
on this Mac (measured). The host's own zero object comes from its private `-_initEmpty`, which answers every field
with its zero value (measured: intrinsic matrix zeros, reference dimensions 0x0, pixel size 0, lens centre 0,0, no
lookup table). The port's object has the same zero values, and that is the whole of its calibration.

Public paths to a calibration object, measured on this Mac:

- `-[AVCameraCalibrationData init]`: unavailable in the SDK, segfaults when sent. No public path.
- `-[AVDepthData cameraCalibrationData]`: nil for every depth object the host builds from a dictionary of its own
  shape (the three keys above and nothing else), and nil for every object the port builds.
- `depthDataFromDictionaryRepresentation:error:` is the only public reader that could carry one. Whether the host
  reads a calibration out of a dictionary is not measured, because no dictionary this Mac can produce carries one:
  none of the 239 HEIC files on this Mac holds depth or disparity auxiliary data, so no file here yields a calibrated
  object (probe: CGImageSourceCopyAuxiliaryDataInfoAtIndex for each of the three depth types).

So no public path on 6.1.3 reaches a zero-valued calibration object, and none reaches a calibrated one that this
measurement can show. The port's depth objects therefore carry nil. What a calibrated map would need: a depth file
holding its calibration, measured on the host, and the reader the host uses for it.

## Not measured, and what it would take

- Depth maps are CVPixelBuffers of depth formats. 6.1.3's CoreVideo creates buffers of these formats in the port's
  build only if it accepts the four OSTypes; this is measured by the device run, not by the host test, and is the
  reason this row says device-unverified below.
- A dictionary with a short data buffer is refused as malformed. The host's answer to a short buffer was not
  measured; the port's is the rule that the data must cover every row at its stride.

## Caveats

- device-unverified: the host test runs against macOS's CoreVideo. The port's depth pixel buffers on 6.1.3 are not
  yet measured on a device or in the emulator.
- Calibration is the zero object, not a measured one (above).
