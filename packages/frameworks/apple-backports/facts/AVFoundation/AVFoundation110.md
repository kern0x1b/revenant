# iOS 11's AVFoundation rows on 6.1.3: the 35 that `absent_AVFoundation.json` places at 11.0, 11.1 and 11.2

Read class by class, with the reader certified on every release it was run against.

## The reader, and its control on every release

```
REVENANT_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.revenant/dyld/6.1.3/dyld_shared_cache_armv7 \
    > .agent-work/runs/wav/inv-6.1.3.tsv                      # 12549 lines
REVENANT_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.revenant/dyld/4.3/dyld_shared_cache_armv7 \
    > .agent-work/runs/wav/inv-4.3.tsv                         #  7751 lines
REVENANT_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.revenant/dyld/7.0/dyld_shared_cache_armv7 \
    > .agent-work/runs/wav/inv-7.0.tsv                          # 16492 lines
# the removed class-scoped row read, arguments: \
    $HOME/Git/projects/ios/coordination/corpus/queue/SLICE-AVFoundation-absent_AVFoundation-11.tsv \
    6.1.3=.agent-work/runs/wav/inv-6.1.3.tsv 4.3=.agent-work/runs/wav/inv-4.3.tsv \
    7.0=.agent-work/runs/wav/inv-7.0.tsv
```

Its three controls, on all three releases, from the first nine lines of that run's output:
`-[AVPlayerItem duration]` CARRIED, `-[AVPlayerItem aSelectorNoFrameworkHas]` ABSENT,
`-[AVCompositionTrack mediaType]` INHERITED - all three as wanted on 6.1.3, on 4.3 and on 7.0.

Every row of the slice reads ABSENT, NO CLASS or NO PROTOCOL on 6.1.3, so none of the 35 is the
release's own.

## `AVRouteDetector`, where the blocker is narrower than it looks

6.1.3's `AVAudioSession` carries 64 own instance methods and among them
`-overrideOutputAudioPort:error:` and `-currentRoute`, so a caller on this release can choose a route
and read the route in use. What this release has no member for is the report of which route the *user*
chose, which is the one thing `AVRouteDetector`'s delegate is called with, and the class itself is not
on the release: first-rung answers NONE for the class name and the deleted class-scoped row reader answers NO CLASS
at 6.1.3, 4.3 and 7.0. The row is absent for that half only, and says so.

## The two carried rows

Both spellings of `sourceTrackIDForFrameTiming` - on `AVVideoComposition` and on
`AVMutableVideoComposition` - are the same answer, and each is a definition of its own: a category adds
a selector to the class it is written on and not to that class's subclasses, so the subclass's category
forwards to the superclass's with `[super sourceTrackIDForFrameTiming]` rather than computing the value
twice. The answer is computed from the release's own members:

| what the SDK says | what 6.1.3 has |
| --- | --- |
| `AVVideoComposition.h:94` "frame timing for the video composition is derived from the source asset's track with the corresponding ID" | `-[AVVideoComposition instructions]`, 26 own instance methods |
| `AVVideoComposition.h:650` the layer instruction's own `trackID` | `-[AVVideoCompositionLayerInstruction trackID]` |
| `kCMPersistentTrackID_Invalid` is the value for a composition that names no track | an enumeration case at `CMBase.h:347`, not a symbol, so nothing has to be exported for it |

`-layerInstructions` is declared on the instruction class (`AVVideoComposition.h:569`) and not on the
7.0 protocol, which is why the release's own class is named in the category; 6.1.3's
`AVVideoCompositionInstruction` carries 18 own instance methods including `-layerInstructions`,
`-mutableCopyWithZone:` and `-timeRange`.

## The three families the 30 absent rows fall into

**HLS offlining (8 rows).** `AVAggregateAssetDownloadTask`, `AVAssetDownloadStorageManager`,
`AVAssetDownloadStorageManagementPolicy`, `AVMutableAssetDownloadStorageManagementPolicy` and
`AVPlayer.availableHDRModes` all stand on a download task and a variant list, and 6.1.3 has neither:
first-rung answers NONE for `_AVAssetDownloadTask` and for `_AVAssetVariant`, and there is no
`NSURLSession` either - NONE for `_NSURLSession`, which is what a download URL session would be built
on. `AVAsset.allMediaSelections` is the same shape: 6.1.3's `AVMediaSelection` family is
`AVMediaSelectionGroup`, `AVMediaSelectionOption`, `AVMediaSelectionTrackOption`,
`AVMediaSelectionTrackGroup`, `AVMediaSelectionKeyValueGroup`, `AVMediaSelectionKeyValueOption` and the
two `...Internal` classes - eight classes, and `AVMediaSelection` itself is not one of them, which is
what `NO CLASS` is reading.

**Depth and calibration (10 rows).** `AVDepthData`, `AVCaptureDepthDataOutput`,
`AVCaptureDepthDataOutputDelegate`, `AVCameraCalibrationData`, `AVCaptureDevice.activeDepthDataFormat`,
`AVCaptureDeviceFormat.supportedDepthDataFormats`, `AVCaptureConnection.cameraIntrinsicMatrixDeliveryEnabled`,
`AVCaptureConnection.cameraIntrinsicMatrixDeliverySupported`, `AVCaptureDeviceFormat.videoMaxZoomFactorForDepthDataDelivery`
and `AVCaptureDeviceFormat.videoMinZoomFactorForDepthDataDelivery` all name a depth format. 6.1.3's
`AVCaptureDeviceFormat` carries 11 own instance methods - `-formatDescription`, `-mediaType`,
`-videoSupportedFrameRateRanges`, `-isBinned`, `-supportedStabilizationMethod`, `-supportsLowLightBoost`
and their few companions - and no depth member of any kind; `AVCaptureDevice`'s 100 and
`AVCaptureConnection`'s 56 carry none either.

**The classes that are not on this release (12 rows).** `AVCapturePhoto` (first-rung answers NONE for
`_AVCapturePhoto`, and 6.1.3's cache carries no `AVCapturePhotoOutput` either), `AVRouteDetector`,
`AVSampleBufferAudioRenderer`, `AVSampleBufferRenderSynchronizer`, `AVCaptureSystemPressureState`,
`AVCaptureDevice.systemPressureState`, `AVPlayerItem.preferredMaximumResolution` and
`AVPlayerItem.videoApertureMode`. `AVRouteDetector` gets a paragraph of its own below, because
6.1.3's `AVAudioSession` *does* carry `-overrideOutputAudioPort:error:` among its 64 own instance
methods and the blocker is narrower than it looks.

Two of those are worth naming, because they are the shape a reader would expect to be a forward:

- `-[AVCaptureVideoDataOutput availableVideoCodecTypesForAssetWriterWithOutputFileType:]` - 6.1.3's
  `AVCaptureVideoDataOutput` **does** carry `-availableVideoCodecTypes`, so the question looks
  answerable. The answer is not: on this release the only statement of what a writer takes is the
  *instance* method `-[AVAssetWriter canApplyOutputSettings:forMediaType:]` (`AVAssetWriter.h:243`; the
  class-method spelling that later SDKs carry is not in this release), and the only way to have a
  writer is `+assetWriterWithURL:fileType:error:`, which needs a file to write into. Answering the row
  would create a file per call, which is not what a getter is.
- `-[AVCaptureVideoDataOutput recommendedVideoSettingsForVideoCodecType:assetWriterOutputFileType:]` -
  the release's own settings vocabulary is `-videoSettings`, `-setVideoSettings:` and
  `-availableVideoCVPixelFormatTypes`, none of which takes a codec or a file type, and there is no
  recommendation table on this release to look a pair up in.

## The two zoom rows, and the 4.3 NO CLASS answers

`AVCaptureDevice.maxAvailableVideoZoomFactor` and `.minAvailableVideoZoomFactor` are absent for a reason
worth writing down: 6.1.3's `AVCaptureDevice` carries 100 own instance methods and no zoom member at
all. The zoom on this release is the port's own 7.0 category (`AVCaptureDevice+VideoZoom7.m`), whose
bound is a per-connection `videoScaleAndCropFactor` rather than a device factor, so there is nothing on
the release for a device-wide maximum to be read from.

`AVCaptureDeviceFormat.unsupportedCaptureOutputClasses`,
`videoMaxZoomFactorForDepthDataDelivery` and `videoMinZoomFactorForDepthDataDelivery` read `NO CLASS` on
4.3 as well, because 4.3's armv7 cache has no `AVCaptureDeviceFormat` at all.

## What was not verified here

No band build and no 6.1.3 gate was run; the only build this worktree may run is the light guard, which
is green. The object was compiled on its own with the shared `llvm` package's clang at
`-target armv7-apple-ios6.0 -isysroot` the 16.4 SDK with the flags `modules/apple/backports.lua`'s
`compile_arguments` uses. Whether a band links it is not verified.