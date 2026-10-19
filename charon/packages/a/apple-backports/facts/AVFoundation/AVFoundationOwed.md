# AVFoundation: what is still owed, and why it is not here

The corpus carries **590** `absent` AVFoundation rows at `2c7d8a7b8`. This file is the plan for them,
in the order they can honestly be answered. It exists so that a deferred row is a line with a reason
and a measurement on it, and never a row quietly left `absent` as though `absent` were a finished
answer.

**Answered so far: 64** - 47 constant rows, in [MetadataKeySpaces.md](MetadataKeySpaces.md) and
[CoordinatedPlaybackReasons.md](CoordinatedPlaybackReasons.md), and the 17 metadata-object rows in
[AVMetadataObjects.md](AVMetadataObjects.md). Each is measured against the host's own build by a
differential, and against the held release caches so that nothing the port defines is a class or a
member a release already has.

**Left: 526** - the families below, none of them a metadata row: the family that answered the 17 is
gone from this file, and its 13 metadata classes are not in the table any more.

## The rest, largest families first

| family | absent rows |
| --- | --- |
| `AVCaptureDevice` | 69 |
| `AVCaptureDeviceFormat` | 31 |
| `AVPlayerItem` | 27 |
| `AVAsset` | 16 |
| `AVPlayer` | 16 |
| `AVAssetTrack` | 15 |
| `AVPlayerItemAccessLogEvent` | 12 |
| `AVMutableVideoComposition` | 11 |
| `AVAssetWriterInput` | 10 |
| `AVCaptureMovieFileOutput` | 10 |
| `AVVideoComposition` | 10 |
| `AVAssetWriter` | 9 |
| `AVCaptureStillImageOutput` | 9 |
| `AVAssetExportSession` | 8 |
| `AVAssetResourceLoadingRequest` | 8 |
| `AVCaptureSession` | 7 |
| `AVCaptureVideoPreviewLayer` | 6 |
| `AVSampleBufferDisplayLayer` | 6 |
| `AVCaptureVideoDataOutput` | 5 |
| `AVMutableComposition` | 5 |
| `AVAssetResourceLoaderDelegate` | 4 |
| `AVComposition` | 4 |

Of the families above, these are pure data and can be answered the way this slice was, one
`dlsym`-measurable table or one constructible object at a time, in this order:

- **the format and configuration descriptors** - `AVCaptureBracketedStillImageSettings`,
  `AVCaptureAutoExposureBracketedStillImageSettings`, `AVCaptureManualExposureBracketedStillImageSettings`,
  `AVCapturePhotoBracketSettings`, `AVCaptureSystemPressureState`, `AVAssetDownloadConfiguration`,
  `AVAssetDownloadContentConfiguration`, `AVAssetVariant*`, `AVAssetSegmentReport*`,
  `AVAssetWriterInputPassDescription`, `AVContentKey*`, `AVCoordinatedPlaybackSuspension`. All
  constructible and readable, none touching a device.
- **the timing and range classes** - `AVMediaSelection`, `AVMutableMediaSelection`,
  `AVMediaSelectionGroup`, `AVMediaSelectionOption`, `AVPlayerMediaSelectionCriteria`, which are
  pure ranges and options.
- **the composition and instruction classes** - `AVComposition`, `AVMutableComposition`,
  `AVCompositionTrack`, `AVMutableCompositionTrack`, `AVVideoComposition`,
  `AVMutableVideoComposition`, and the layer and time-range instruction objects. These need a media
  source, so they want the same fixture as the seventeen above.
- **the capture and session layer, last** - `AVCaptureDevice` (69 rows), `AVCaptureDeviceFormat`
  (31), the outputs, the session and the device inputs. These are the rows where the policy in the
  brief bites: hardware the device lacks answers as Apple documents (`isSupported` NO, the
  documented error), and nothing may be called on this Mac's real capture devices. That slice needs
  the device-session discipline and the coordinator's gate, not a host differential alone.
