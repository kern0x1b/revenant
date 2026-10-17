# iOS 13's AVFoundation on releases that arrived before it: the 47 rows, read at both band ends

The 47 rows of `registry/AVFoundation/absent_AVFoundation.json` that `API_AVAILABLE(ios(13.0))` - one
`ios(13.4)` - puts at 13. Every one of them was `absent` with a reason that cited only the SDK's own
declaration. This is the read that replaces that citation: what each row's OWNER class carries at
6.1.3 and at 12.0, what it carries at 16.0, and - for the two rows the release does answer - the code
that answers them.

Two of the 47 became `implemented` (`AVFoundation13.m`); the other 45 stay `absent`, each with the
substrate it would have been built from named and counted. Nothing here is a claim about the port
having not written something: every row below is a claim about the release.

## The measurement, and the controls that certify it

One `objc-inventory.lua` dump per release, read through the deleted class-scoped row reader, which
asks each row of its OWNER's class line and walks the superclass chain, telling `CARRIED` (own table)
from `INHERITED` (a superclass answers it) from `ABSENT` from `NO CLASS`. A member row asks whether
ONE class has ONE selector, so a first-rung answer is the wrong question: measured twice on
2026-09-30, `fileSystemRepresentation` reads first-rung 3.0 from another class while
`-[NSURL fileSystemRepresentation]` is 7.0.

```
$ # the removed class-scoped row read, arguments: --inventory 6.1.3 12.0 16.0 -- rows13.tsv
# 47 rows x 3 releases: 6.1.3-armv7, 12.0-arm64, 16.0-arm64e
# control 6.1.3-armv7  -[AVPlayerItem duration]                           method  want CARRIED   got CARRIED
# control 6.1.3-armv7  -[AVPlayerItem aSelectorNoFrameworkHas]            method  want ABSENT    got ABSENT
# control 6.1.3-armv7  -[AVCompositionTrack mediaType]                    method  want INHERITED got INHERITED
# control 12.0-arm64   ... same three, all as wanted
# control 16.0-arm64e  ... same three, all as wanted
# --- per release ---
# 6.1.3-armv7  {'ABSENT': 33, 'INHERITED': 1, 'NO CLASS': 13}
# 12.0-arm64   {'ABSENT': 34, 'INHERITED': 1, 'NO CLASS': 12}
# 16.0-arm64e  {'ABSENT': 1, 'CARRIED': 46}
```

The three controls are the tool's and they are in the run on purpose: a reader that read nothing
answers `ABSENT` for every row, which is the verdict a wrong reader produces happily, and the tool
writes no row when a control is wrong. `AVPlayerItem.duration` answering `CARRIED` is the positive
control that the class tables came from the right place; `aSelectorNoFrameworkHas` answering `ABSENT`
is the negative control that they were read as tables and not as one bag of names;
`AVCompositionTrack.mediaType` answering `INHERITED` is asked deliberately because it is the trap
this file hits itself (below).

**Where the dumps came from.** The three `*.inventory.tsv` files were produced by an earlier
AVFoundation band's run and copied read-only out of
`.agent-work/worktrees/bat-avf/.agent-work/runs/bat-avf/`; this band did not re-dump them, because
dumping is an `xmake l` run and this band runs no xmake. The run that reads them is the one above and
it answered all nine controls, which is what certifies the reader; a reader that cannot re-run the
dump can re-run the deleted class-scoped row reader against the same three files.

**The 16.0 end is the release that carries these rows, and it is not a 13.0 reading.** Nothing is
held between 12.0 and 16.0 (`tools/release-split.lua` says so in the same words), so a 13.0, 14.0 or
15.0 name reads 16.0 on this ladder. The 16.0 column is used here only to show that the release
family does carry the name, which is what makes `absent` a claim about 6.x and not about the port.

| release | CARRIED | INHERITED | ABSENT | NO CLASS |
| --- | --- | --- | --- | --- |
| 6.1.3 armv7 | 0 | 1 | 33 | 13 |
| 12.0 arm64 | 0 | 1 | 34 | 12 |
| 16.0 arm64e | 46 | 0 | 1 | 0 |

## The one row the tool cannot ask as a property: AVPlayer.eligibleForHDRPlayback

The single `ABSENT` at 16.0 is this row, and the verdict is the tool's spelling rather than the
release's. `AVPlayer.h:641` declares it `@property (class, readonly) BOOL eligibleForHDRPlayback`,
so its accessor is the CLASS method `+eligibleForHDRPlayback`, and the 16.0 arm64e class table
carries exactly that plus `+availableHDRModes`, `+checkForAvailableHDRModesChanges` and the two
notification firers - and no instance selector of that name anywhere on AVPlayer's 348. The tool asks
`property_of()`'s three answers (the property's own name, `set…:` and `is…`), which is why a class
property reads `ABSENT`. `modules/apple/backports.lua`'s `carried_by_release` asks the same three, so
`absent` is the answer the gate itself would read, and it is the right one here for a second reason:
6.1.3 carries 140 own instance selectors on AVPlayer and 12.0 carries 251, and neither end has an
HDR display path of any kind.

## What each owner carries, and what it would have been built from

Own selectors per owner, from the same three dumps. These are the numbers the reasons cite.

| owner | 6.1.3 | 12.0 | 16.0 | the substrate at 6.1.3 that the row is not |
| --- | --- | --- | --- | --- |
| `AVMutableVideoComposition` | 12 + 3 | 22 + 4 | 26 + 8 | `+videoCompositionWithPropertiesOfAsset:` IS there - see below |
| `AVCaptureVideoPreviewLayer` | 54 + 2 | 67 + 3 | 82 + 3 | `-session`, `-connection`, `-isPaused`; no render-state member |
| `AVCaptureSession` | 84 + 2 | 96 + 8 | 128 + 9 | `-isRunning`, `-addConnection:`; its connections live in the private `-_liveConnections` |
| `AVCaptureConnection` | 56 + 3 | 75 + 3 | 97 + 3 | `-isEnabled`, `-isActive`, `-videoPreviewLayer` |
| `AVAssetExportSession` | 54 + 23 | 49 + 7 | 53 + 7 | `-estimatedOutputFileLength` and `+maximumDurationForPreset:properties:`, both synchronous |
| `AVAssetTrack` | 52 + 2 | 78 + 3 | 102 + 4 | `-isEnabled`, `-formatDescriptions`, `-estimatedDataRate`; no sample-dependency member |
| `AVCompositionTrack` | 6 + 0 | 7 + 0 | 8 + 0 | only `-_initWithAsset:trackID:trackIndex:`, `-_mutableComposition`, `-segments` |
| `AVMutableCompositionTrack` | 19 + 0 | 29 + 1 | 32 + 1 | no setter for the enable flag, no format-description member at all |
| `AVAsset` | 65 + 2 | 149 + 12 | 185 + 23 | `-duration`, `-naturalSize`, `-isPlayable`, `-tracksWithMediaType:`; no live offset |
| `AVPlayerItem` | 237 + 35 | 406 + 30 | 563 + 31 | no live offset, no spatial-audio switch |
| `AVSampleBufferDisplayLayer` | 20 + 0 | 41 + 3 | 66 + 3 | no display-server hint member of any kind |
| `AVCaptureDevice` | 100 + 5 | 207 + 15 | 289 + 60 | `-deviceType` is 12.0's; 6.1.3 has no device-type vocabulary at all |
| `AVCaptureDeviceFormat` | 11 + 3 | 86 + 1 | 133 + 1 | 11 own selectors: the format's dimensions and ranges |
| `AVCaptureDeviceInput` | 15 + 1 | 22 + 2 | 48 + 2 | `-device`, `-ports`, `-initWithDevice:error:` |
| `AVCaptureInputPort` | 11 + 1 | 17 + 2 | 23 + 3 | `-mediaType`, `-formatDescription`, `-isEnabled` |
| `AVCaptureVideoDataOutput` | 26 + 2 | 45 + 2 | 56 + 2 | `-videoSettings`, `-availableVideoPixelFormatTypes` |

`AVCaptureDeviceDiscoverySession` is `NO CLASS` at 6.1.3 - it arrived with iOS 10 - and
`AVAudioEnvironmentNode`, the spatial-audio node `AVPlayerItem.audioSpatializationAllowed` asks for,
is `NO CLASS` at 6.1.3 and carries 13 own selectors at 12.0.

### The trap this file hits twice, and the `is` spelling

**`AVMutableCompositionTrack.enabled` is the file's one `INHERITED`.** 6.1.3's
AVMutableCompositionTrack carries 19 own instance selectors and none is an enable setter; the answer
comes from `-[AVAssetTrack isEnabled]` 51 selectors up the chain, which is read-only. An own-table
read would have called it `ABSENT` and named the wrong release for it.

**`previewing`'s getter is not `previewing`.** `AVCaptureVideoPreviewLayer.h:135` declares
`@property(nonatomic, readonly, getter=isPreviewing) BOOL previewing`, and the 16.0 class table
carries `-isPreviewing`, which is what `AVFoundation13.m` defines. The same shape is measured on four
more of these rows and named in their reasons: `geometricDistortionCorrectionEnabled`,
`geometricDistortionCorrectionSupported`, `globalToneMappingEnabled` and `virtualDevice` are all
`getter=is…`, and `AVPlayerItem.audioSpatializationAllowed` is `getter=isAudioSpatializationAllowed`.

**And a name's presence in the image says nothing about its owner.** A raw selector-string search of
the 6.1.3 armv7 cache answers 1 for `isPreviewing`, and that one string belongs to
`-[AVCaptureSession isPreviewing]`, which no SDK header declares and which the layer does not carry;
the class-scoped read answers `ABSENT` for the layer at 6.1.3 and at 12.0 and `CARRIED` at 16.0. A
second reader over the same two band ends, for the pair this file implements:

| selector | 6.1.3 armv7 | 12.0 arm64 |
| --- | --- | --- |
| `videoCompositionWithPropertiesOfAsset:prototypeInstruction:` | **0** | **0** |
| `videoCompositionWithPropertiesOfAsset:` | 1 | 2 |
| `charonProbeNoSuchSelectorAVF13` (control) | 0 | 0 |
| `isRunning` (control) | 12 | - |
| `isEnabled` (control) | 40 | - |

```
$ strings -a ~/.charon/dyld/6.1.3/dyld_shared_cache_armv7 | grep -cxF SELECTOR
```

The two non-zero controls are what makes the zeros evidence: the same run that finds 0 for the row's
selector finds 1 and 2 for the sibling factory and 12 and 40 for `isRunning` and `isEnabled`, so the
reader was looking. This is the measurement `tools/release-split.lua` asks for in place of its own
walk, which cannot cover a category file at all - a category's methods compile to no nm-visible
exported symbol, so that script checks zero symbols for one and reports clean either way.

## The two rows the release answers

### +[AVMutableVideoComposition videoCompositionWithPropertiesOfAsset:prototypeInstruction:]

`AVVideoComposition.h:322` defines it as the release's own factory plus an override: "Also see
videoCompositionWithPropertiesOfAsset:. The returned AVVideoComposition will have instructions that
respect the spatial properties and timeRanges of the specified asset's video tracks. Anything not
pertaining to spatial layout and timing, such as background color for their composition or
post-processing behaviors, is eligible to be specified via a prototype instruction."

Both halves are present at both band ends, and the halves are separate: 6.1.3's
AVMutableVideoComposition carries the class selectors `+videoComposition`,
`+videoCompositionWithPropertiesOfAsset:` and `+videoCompositionWithPropertiesOfAsset:videoGravity:`
(the first half, since iOS 6, deprecated only at iOS 18), and AVVideoCompositionInstruction carries
`backgroundColor`, `enablePostProcessing`, `layerInstructions` and `timeRange`. So the spatial and
timing half is the release's own computation and is not recomputed: `AVFoundation13.m` asks for the
composition the release builds and replaces each of its instructions with a copy of the caller's
prototype that keeps the release's two spatial members. An asset with no video track gives the
release no instruction, and an empty instruction array is what the header says that case returns.

### AVCaptureVideoPreviewLayer.previewing

`AVCaptureVideoPreviewLayer.h:128` states when the value changes: "An AVCaptureVideoPreviewLayer
begins previewing when -[AVCaptureSession startRunning] is called. While a session is running, you
may enable or disable a video preview layer's connection to re-start or stop the flow of video to the
layer." That is the predicate `AVFoundation13.m` implements, from four members that are public API at
iOS 6 and carried at both band ends: `-session` and `-connection` on the layer (the latter
`API_AVAILABLE(ios(6.0))`), `-isRunning` on the session (`AVCaptureSession.h:509`) and `-isEnabled` on
the connection.

The session's own `-isPreviewing` would have been the shorter answer and is not taken: no SDK header
declares it, so forwarding to it is a private call. The layer's `-connections` and
`-activeConnections` are likewise undeclared at 6.1.3, so neither is asked; `-connection` is the
public singular form and is what `-initWithSession:` and `-setSession:` fill in.

Both rows are categories, and both are inert from 13.0 up, which is what makes carrying them from 6.0
safe: `packages/a/apple-backports/attach.c`'s `charon_collect` adds a category's method only when
`charon_implements()` finds nothing, walking the class and its superclasses. At 6.1.3 and 12.0
nothing implements either selector, so the port's methods are installed; at 13.0 and above the
release implements both and the port's are not installed at all.

## The 45 that stay absent, by the substrate each would have needed

Each reason in the registry names the count and the members. Grouped by what is missing:

- **Multi-camera and virtual devices** (`AVCaptureMultiCamSession`, `AVCaptureDevice.virtualDevice`,
  `.constituentDevices`, `.virtualDeviceSwitchOverVideoZoomFactors`, `AVCaptureDeviceFormat.multiCamSupported`,
  `AVCaptureDeviceDiscoverySession.supportedMultiCamDeviceSets`, `-[AVCaptureDeviceInput
  portsWithMediaType:sourceDeviceType:sourceDevicePosition:]`, `AVCaptureInputPort.sourceDeviceType`,
  `.sourceDevicePosition`): the vocabulary is AVCaptureDeviceType, which 6.1.3's AVCaptureDevice does
  not have at all - its 100 own selectors carry no `-deviceType` and no device-type constant, and
  `-deviceType` itself first appears at 12.0. There is no dual camera to be a constituent of.
- **Tone mapping, geometric distortion correction and photo quality** (`globalToneMappingEnabled`,
  `.globalToneMappingSupported`, `geometricDistortionCorrectionEnabled`, `.geometricDistortionCorrectionSupported`,
  `AVCaptureDeviceFormat.geometricDistortionCorrectedVideoFieldOfView`, `.highestPhotoQualitySupported`,
  `+[AVCaptureDevice extrinsicMatrixFromDevice:toDevice:]`): each asks the format or the device
  about hardware the release cannot name. The extrinsic matrix is calibration data the kernel driver
  holds for a multi-camera device; 6.1.3's AVCaptureDevice carries no member that returns one.
- **Live streaming** (`AVAsset.minimumTimeOffsetFromLive`, `AVPlayerItem.configuredTimeOffsetFromLive`,
  `.recommendedTimeOffsetFromLive`, `.automaticallyPreservesTimeOffsetFromLive`): the time offset from
  live is the difference between a playlist's live edge and the presentation clock, and 6.1.3's
  AVAsset carries `-duration`, `-naturalSize`, `-isPlayable` and `-tracksWithMediaType:` and no live
  member; its only streaming member is the private `-_isStreaming`.
- **The movie-file editing family** (`AVMovie`, `AVMutableMovie`, `AVMovieTrack`, `AVMutableMovieTrack`,
  `AVFragmentedMovie`, `AVFragmentedMovieTrack`, `AVFragmentedMovieMinder`, `AVMediaDataStorage`): 16.0
  gives AVMovie 39 own instance and 5 class selectors and AVMutableMovieTrack 73 own instance
  selectors, and 6.1.3 has none of the eight classes. What 6.1.3 does have is AVAssetExportSession's
  54 own instance selectors, which is the whole of the file-level editing this release can do.
- **Spatial audio, display hints and neural mattes** (`AVPlayerItem.audioSpatializationAllowed`,
  `AVSampleBufferDisplayLayer.preventsCapture`,
  `.preventsDisplaySleepDuringVideoPlayback`, `AVSemanticSegmentationMatte`,
  `AVVideoCompositionRenderHint`): AVAudioEnvironmentNode is `NO CLASS` at 6.1.3; the sample buffer
  display layer's 20 own selectors are the queue, the video gravity and the control timebase, and
  neither display hint is among them; a semantic segmentation matte is a matting network's output
  and AVSemanticSegmentationMatte's 16.0 table is 15 own instance selectors over one pixel buffer
  and its metadata; AVVideoCompositionRenderHint's 6 own instance selectors are four CMTime bounds
  that VideoToolbox's video compositor of that release reads.
- **Composition-track format description replacement**
  (`AVCompositionTrack.formatDescriptionReplacements`,
  `-[AVMutableCompositionTrack replaceFormatDescription:withFormatDescription:]`,
  `AVCompositionTrackFormatDescriptionReplacement`): 6.1.3's AVMutableCompositionTrack has no
  format-description member of its own, and AVCompositionTrackFormatDescriptionReplacement has no
  public initializer at all - `AVCompositionTrack.h:253` declares two readonly properties and
  NSSecureCoding, and the 16.0 image's initializer `initWithOriginalFormatDescription:andReplacementFormatDescription:`
  is not in the header. The only route to an instance is the track method, and the only format
  description the release has is the inherited `-[AVAssetTrack formatDescriptions]`.
- **The export session's two estimates** (`-[AVAssetExportSession estimateMaximumDurationWithCompletionHandler:]`,
  `estimateOutputFileLengthWithCompletionHandler:`): 6.1.3 does answer both questions, synchronously
  and less accurately - `-[AVAssetExportSession estimatedOutputFileLength]` and
  `+[AVAssetExportSession maximumDurationForPreset:properties:]` - and the header says why the
  asynchronous pair exists: "Note that the returned value does not take into account the source asset
  information. For a more accurate estimation, use estimateOutputFileLengthWithCompletionHandler."
  Both of these blocks also carry an `NSError` the release's own answer has no way to report, so a
  forward would answer a different number under this name and report no failure.
- **Three flags and one array with no knob behind them** (`AVCaptureSession.connections`,
  `AVCaptureVideoDataOutput.automaticallyConfiguresOutputBufferDimensions`,
  `.deliversPreviewSizedOutputBuffers`, `AVCaptureDeviceInput.videoMinFrameDurationOverride`): each
  configures something the release does in exactly one fixed way. 6.1.3's AVCaptureSession keeps its
  connections in the private `-_liveConnections` and exposes only `-addConnection:` and
  `-removeConnection:`; its AVCaptureVideoDataOutput delivers buffers in `videoSettings` and nothing
  resizes them; and the frame-duration cap would need the device's `activeVideoMinFrameDuration`,
  which is 7.0's, not this release's.
- **One read-only flag the release already answers from a superclass, and one absent in 16.0 too**:
  `AVMutableCompositionTrack.enabled` is `INHERITED` (`-[AVAssetTrack isEnabled]`, read-only, no
  setter anywhere in 19 own selectors), and `AVPlayer.eligibleForHDRPlayback` needs an HDR display
  path that neither band end has.

## Reproducing

```
$ # the removed class-scoped row read, arguments: --inventory 6.1.3 12.0 16.0 -- rows13.tsv
$ xmake l tools/cache-index/first-rung.lua --self-test
$ strings -a ~/.charon/dyld/6.1.3/dyld_shared_cache_armv7 | grep -cxF SELECTOR
```

The first-rung index's own self-test answers 8/8 here, with `_NSFileSize` at 3.0 as its positive
control and a nonsense name at `NONE` as its negative one. It is quoted here as the index's health,
not as evidence for any of these rows: a member row asks about one class, and a first rung answers
about every class at once.
