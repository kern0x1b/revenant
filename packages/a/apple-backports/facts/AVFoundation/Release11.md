# AVFoundation: what the 11.0/11.1/11.2 rows of the absent sweep measure

The 35 rows this file is about are the `absent_AVFoundation.json` entries whose `introduced` is
11.0, 11.1 or 11.2. Every one of them was written from the SDK's own availability attribute
("SDK 16.4, AVFoundation") and nothing else. This file is the measurement behind them, and it is
what four of the rows (the two zoom-range properties and the two intrinsics-delivery properties)
are implemented from.

Nothing here is a copy of Apple's code: the rulebook's own note is that no public source exists for
AVFoundation (`coordination/corpus/sources.md`), so every claim below is either read out of a held
cache or out of a document the tree already carries.

## What was checked, and the control in each run

**First held rung of each name** - `tools/cache-index/first-rung.lua`, the merged name index over
the 50 held rungs:

    $ xmake l tools/cache-index/first-rung.lua < <the 35 names, one per line>
    _NSFileSize                                     3.0      <- the control
    NSCharonW07ControlNameThatNoReleaseCarries      NONE    <- the negative control
    _OBJC_CLASS_$_AVAggregateAssetDownloadTask       11.0
    _OBJC_CLASS_$_AVAssetDownloadStorageManagementPolicy 11.0
    _OBJC_CLASS_$_AVAssetDownloadStorageManager      11.0
    _OBJC_CLASS_$_AVCameraCalibrationData            11.0
    _OBJC_CLASS_$_AVCaptureDepthDataOutput           11.0
    _OBJC_CLASS_$_AVCapturePhoto                     11.0
    _OBJC_CLASS_$_AVCaptureSystemPressureState       12.0
    _OBJC_CLASS_$_AVDepthData                        11.0
    _OBJC_CLASS_$_AVMutableAssetDownloadStorageManagementPolicy 11.0
    _OBJC_CLASS_$_AVRouteDetector                    11.0
    _OBJC_CLASS_$_AVSampleBufferAudioRenderer        11.0
    _OBJC_CLASS_$_AVSampleBufferRenderSynchronizer   11.0
    availableVideoCodecTypesForAssetWriterWithOutputFileType:  11.0
    recommendedVideoSettingsForVideoCodecType:assetWriterOutputFileType: 11.0
    allMediaSelections                               11.0
    decodable                                        11.0
    mediaDataLocation                                11.0
    cameraIntrinsicMatrixDeliveryEnabled             11.0
    cameraIntrinsicMatrixDeliverySupported           11.0
    activeDepthDataFormat                            11.0
    dualCameraSwitchOverVideoZoomFactor              11.0
    maxAvailableVideoZoomFactor                      11.0
    minAvailableVideoZoomFactor                      10.0.1
    systemPressureState                              12.0
    supportedDepthDataFormats                        11.0
    unsupportedCaptureOutputClasses                  11.0
    videoMaxZoomFactorForDepthDataDelivery           11.0
    videoMinZoomFactorForDepthDataDelivery           11.0
    sourceTrackIDForFrameTiming                      10.0.1
    availableHDRModes                                12.0
    preferredMaximumResolution                       11.0
    videoApertureMode                                10.0.1

A rung here is the OLDEST held release carrying the NAME, and for a selector that says nothing about
its owner: `minAvailableVideoZoomFactor`, `sourceTrackIDForFrameTiming` and `videoApertureMode` read
10.0.1 while the registry's own `introduced` is 11.0, and the ladder's hole (no 13.0, 14.0 or 15.0
held) is why `AVCaptureSystemPressureState`, `systemPressureState` and `availableHDRModes` read 12.0
though the registry says 11.1, 11.1 and 11.2. The two class-scoped runs below are what settles the
owner.

**Both host ends, class-scoped, in one differential** - the driver's own reader over the armv7
caches, and the control is in the same dump:

    $ CHARON_ROOT=<worktree> xmake l tools/corpus/objc-inventory.lua \
        ~/.charon/dyld/6.1.3/dyld_shared_cache_armv7 > objc-6.1.3.tsv
    $ CHARON_ROOT=<worktree> xmake l tools/corpus/objc-inventory.lua \
        ~/.charon/dyld/4.3/dyld_shared_cache_armv7 > objc-4.3.tsv

| | 6.1.3 (armv7) | 4.3 (armv7) |
| --- | --- | --- |
| classes | 11378 | 7187 |
| protocols | 1171 | 564 |
| **control** `AVCaptureDevice` | present, 100 instance + 5 class selectors, image `/System/Library/Frameworks/AVFoundation.framework/AVFoundation` | present, 66 instance + 5 class selectors, same image |

That control is what makes the zeros mean something: the AVFoundation image was read, and the class
the whole family hangs off came back with its selectors. Of the 35 rows, **none** of the 12 classes,
neither of the 2 protocols, and not one of the 21 selectors is carried by either end - every
`ABSENT on owner` line in that run names an owner class that exists (except `AVCaptureDeviceFormat`'s
four rows, whose owner class does not exist at 4.3 at all).

**The census, prefix-scoped, with its own control** - `tools/corpus/cache-census.lua`:

    $ xmake l tools/corpus/cache-census.lua AVSampleBuffer 6.1.3 4.3
    6.1.3  images 524, classes 11378, of which AVSampleBuffer* 3
           (AVSampleBufferDisplayLayer AVSampleBufferDisplayLayerContentLayer
            AVSampleBufferDisplayLayerInternal); protocols 1171, of which AVSampleBuffer* 0
    4.3    images 354, classes 7187, of which AVSampleBuffer* 0; protocols 564, 0
    control: 3 name(s) beginning AVSampleBuffer found in this run, so a zero on another rung is the
             release's and not the reader's

    $ xmake l tools/corpus/cache-census.lua AVDepth 6.1.3 4.3
    6.1.3  of which AVDepth* 0    4.3  of which AVDepth* 0
    CONTROL FAILED: no rung read carried a name beginning AVDepth, so this run cannot show that the
                    reader finds one; an absence from it is not evidence

    $ xmake l tools/corpus/cache-census.lua AVRouteDetector 6.1.3 4.3
    CONTROL FAILED (the same sentence, for that prefix)

Recorded because it is the tool doing its job: the two prefixes no held 6.x or 4.3 rung carries
cannot be certified by a census on those two rungs, so the depth and route rows are carried by the
`objc-inventory.lua` run above - which reads the whole cache rather than a prefix - and not by the
census. A row is never written from a run that printed CONTROL FAILED.

**A reader-independent cross-check** - the raw strings of the 6.1.3 cache, `strings -a` piped to
`grep -xE`, which agrees with the reader on the one class the whole `AVAsset` story turns on:

    $ strings -a ~/.charon/dyld/6.1.3/dyld_shared_cache_armv7 | grep -xE \
        'AVMutableAsset|AVMediaSelection|AVAsset|AVCaptureDevice|AVAssetWriterInput|AVMutableComposition|CharonW07NothingHere|AVPlayerItem|AVCaptureDeviceFormat'
    3 AVAsset              1 AVPlayerItem     1 AVMutableComposition
    1 AVCaptureDeviceFormat  1 AVCaptureDevice  1 AVAssetWriterInput

`AVMutableAsset` and `AVMediaSelection` are not in that output and neither is the nonsense control.
Both ends and the raw bytes agree: **iOS 6.1.3 has no `AVMediaSelection` and no `AVMutableAsset`**,
and the one download class it does carry is the private `AVAssetDownloadSession` (with
`AVAssetDownloadSessionInternal`), not a storage manager.

## The depth family, and the one support probe of it the port does answer

Eleven of the rows are the TrueDepth capture stack of 11.0 and 11.1, and they close with text
because the substrate is not in either host end and cannot be built out of what is there:

- `AVCaptureDepthDataOutput`, `AVCaptureDepthDataOutputDelegate`, `AVDepthData`,
  `AVCameraCalibrationData`: the release has no depth capture output, no depth data object, no
  calibration data. 6.1.3's `AVCaptureVideoDataOutput` carries `availableVideoCVPixelFormatTypes`,
  `availableVideoCodecTypes` and `vettedVideoSettingsForSettingsDictionary:` - a list of pixel
  formats and codecs for a camera, none of which is a depth format. Nothing on the release can
  produce a depth sample, so there is nothing for a delegate to be a delegate of.
- `AVCaptureDeviceFormat.supportedDepthDataFormats`, `videoMinZoomFactorForDepthDataDelivery`,
  `videoMaxZoomFactorForDepthDataDelivery`, `AVCaptureDevice.activeDepthDataFormat`: the release's
  `AVCaptureDeviceFormat` is a class of 6.0 and its own surface is 11 instance and 3 class selectors
  (measured at 6.1.3) - `formatDescription`, `mediaType`, `videoSupportedFrameRateRanges`,
  `supportedStabilizationMethod`, `supportsLowLightBoost`, `isBinned`/`hasBinned`, `isEqual:`,
  `initWithDictionary:mediaType:mediaSubType:` and the three class methods. It has no notion of a
  second format, and a delivery range over one is a range over a format that does not exist.
- `AVCaptureDeviceFormat.unsupportedCaptureOutputClasses`, `AVCaptureConnection`'s
  `cameraIntrinsicMatrixDeliveryEnabled` and `cameraIntrinsicMatrixDeliverySupported`,
  `AVCaptureDevice.dualCameraSwitchOverVideoZoomFactor`: the release has no intrinsics anywhere. No
  line of either dump names a class or a protocol containing `Intrinsic` (0 of 11378 and 0 of 7187),
  and 6.1.3's `AVCaptureConnection` is a class of 6.0 whose own surface is 56 instance and 3 class
  selectors: scale and crop, frame duration and its bounds, orientation, mirroring, retained buffer
  count, audio channels and levels, active and enabled, and the stabilization switch. There is no
  matrix to deliver, no camera calibrated enough to have one, and no second camera to switch over to.
- `AVCaptureDevice.systemPressureState` and the class `AVCaptureSystemPressureState` (11.1): the
  release's `NSProcessInfo` carries 33 selectors, none of them thermal or a pressure state - they
  are process counting, host and user, uptime, physical memory, the environment, the arguments, and
  the app-switching save/restore switches. A camera's system pressure state is read from a thermal
  monitor that release has no API for at all.

**The exception, and why it is the exception.** The brief's policy for the capture layer is that
"hardware the device lacks answers as Apple documents (`isSupported` NO, the documented error)"
(`AVFoundationOwed.md`, "the capture and session layer, last"), and the tree already carries one row
of exactly that shape for 6.x - `AVCaptureSession.usesApplicationAudioSession`, `implemented`, whose
effect is "NO, what 6.1.3 does; setting YES cannot be honoured, the property keeps answering NO and
the log says so once". So `cameraIntrinsicMatrixDeliverySupported` is **implemented** and answers NO,
and `cameraIntrinsicMatrixDeliveryEnabled` answers NO with a setter that says once that it cannot be
honoured. A caller that gates on the support probe is told the truth instead of raising; the rows
that need a real depth sample stay `absent`, because there the port would have to invent the sample.

## The zoom range, which the port can answer from the release's own limit

`AVCaptureDevice.maxAvailableVideoZoomFactor` and `minAvailableVideoZoomFactor` are `implemented`
over `AVCaptureDeviceFormat.videoMaxZoomFactor`, which this port already carries at 7.0
(`registry/AVFoundation/ios7zoom.json`, `AVCaptureDevice+VideoZoom7.m`) and which is itself the
release's own limit for its scale and crop: `max(1, min(width, height) * 0.0625)` of the format's
dimensions, read out of the format description 6.1.3 really has. The maximum is that value for the
device's active format; 6.1.3 has an active format only inside a running session, and there the
answer is 1 outside one, which is the same range the port's own zoom setter checks
(`AVCaptureDevice+VideoZoom7.m`, `charon_check_zoom`).

The minimum is 1, and this is a measured constant rather than a guess: the port's own zoom cannot go
below 1 - `setVideoZoomFactor:` raises `NSRangeException` for a smaller factor, as 7.0 does - and
6.1.3 has no wide-angle format to go below 1 with, since the format's own limit is the scale-and-crop
limit above and nothing else. `usesApplicationAudioSession` is the same shape: a negotiated
capability the release cannot have, carried as the truthful constant.

## The asset, writer and player families

- `AVAggregateAssetDownloadTask`, `AVAssetDownloadStorageManager`,
  `AVAssetDownloadStorageManagementPolicy`, `AVMutableAssetDownloadStorageManagementPolicy`: the
  substrate is `NSURLSession`, and the reader finds no class of that name in either dump (0 of
  11378, 0 of 7187) and the raw strings of 6.1.3 have no such selector either. The release's
  download is the private `AVAssetDownloadSession`, whose storage the application owns by URL. A
  storage manager is a policy over sessions that do not exist here.
- `AVAsset.allMediaSelections`: the row is an array of `AVMediaSelection`, and
  **iOS 6.1.3 has no `AVMediaSelection` class** - both dumps and the raw strings agree. The release
  has `AVMediaSelectionGroup`, `AVMediaSelectionOption`, `AVMediaSelectionTrackOption` and
  `AVMediaSelectionKeyValueOption` and `-[AVAsset mediaSelectionGroupForMediaCharacteristic:]`,
  but a group is options; the selection itself, and any list of them, arrived later.
- `AVAssetTrack.decodable`: 6.1.3's `AVAssetTrack` carries 54 selectors, of which the ones
  about whether the track can be used are `-isPlayable`, `-hasMediaCharacteristic:`,
  `-hasMediaCharacteristics:`, `-isEnabled`, `-isSelfContained` and `-isExcludedFromAutoselection…`.
  None of them is about decoding into samples, and `decodable` is not `isPlayable` renamed: a track
  can be playable through a path that is not decodable, and the two rows are kept apart here as they
  are in the SDK. A caller that needs the release's reading has `-isPlayable`.
- `AVAssetWriterInput.mediaDataLocation`: 6.1.3's `AVAssetWriterInput` carries 57 selectors
  (`expectsMediaDataInRealTime`, `sourceFormatHint`, `naturalSize`, `transform`, `mediaTimeScale`,
  `metadata`, `extendedLanguageTag`, `languageCode`, `marksOutputTrackAsEnabled`, the track
  associations, and the writer's own private `_trackID`). Where a sample's data lands inside the
  output file is a thing that writer has; its writer appends what the application gives it and
  nothing else.
- `-[AVCaptureVideoDataOutput availableVideoCodecTypesForAssetWriterWithOutputFileType:]` and
  `-[AVCaptureVideoDataOutput recommendedVideoSettingsForVideoCodecType:assetWriterOutputFileType:]`:
  both ask the **writer**, for a **file type**, and 6.1.3's writer cannot answer either.
  `AVAssetWriter`'s entire class surface is `assetWriterWithURL:fileType:error:`, `-initialize`,
  `-automaticallyNotifiesObserversForKey:`, the two `keyPathsForValuesAffecting…`, and
  `_errorForOSStatus:`; an instance carries `outputFileType` and `availableMediaTypes` and no map
  from a file type to codecs. `AVAssetWriterInput` carries no codec list and no per-codec settings at
  all (its class methods are the two `assetWriterInputWithMediaType:outputSettings:` factories,
  `-initialize` and the key paths). The output's own `availableVideoCodecTypes` and
  `vettedVideoSettingsForSettingsDictionary:` are the capture side and answer a different question:
  what this camera can produce, not what this writer can take.
- `AVVideoComposition.sourceTrackIDForFrameTiming` and its
  `AVMutableVideoComposition` spelling: 6.1.3's composition is `frameDuration`, `renderSize`,
  `renderScale`, `instructions`, `animationTool`, `compositor` and one private accessor,
  `_auxiliaryTrackID`, which names the track the compositor takes its auxiliary (letterboxed) area
  from. That is not the track that drives frame timing, and the release names no other. A caller that
  wants a track to time frames from is the one naming the track, in
  `AVMutableCompositionTrack` and in each instruction.
- `AVPlayer.availableHDRModes`, `AVPlayerItem.preferredMaximumResolution`,
  `AVPlayerItem.videoApertureMode`: 6.1.3's `AVPlayer` has no HDR surface (its 159 selectors are
  the player graph, the layer, rate, volume, AirPlay, seeking, preroll and the access log) and its
  `AVPlayerItem` has no resolution negotiation and no aperture mode; the only sizing it carries is
  the private `_presentationSize` and the private setters that take a composition's render size. A
  maximum resolution would be honoured by rendering smaller, which is the video composition's
  `renderSize`; an aperture mode is the HDR path, which this release has none of.
- `AVRouteDetector`: the release does report route changes - `AVAudioSession` carries the
  notifications - but the detector's answer is a classification of what is on the other end, from a
  model. 6.1.3 has no class, selector or string carrying `AVRouteDetector` (the census on that
  prefix printed CONTROL FAILED, and neither dump has the class either). A caller that wants to know
  the route is on the notification; a caller that wants to know whether it is a car is asking a
  question no code in this tree can answer on 6.1.3.
- `AVSampleBufferAudioRenderer`, `AVSampleBufferRenderSynchronizer` and the protocol
  `AVQueuedSampleBufferRendering`: the only `AVSampleBuffer*` names either end carries are the
  display layer's three classes (the census's control above), and neither class is on 6.1.3 at all.
  The release's own way to push buffers at a rate is `AVAudioEngine` with `AVAudioPlayerNode` and
  `AVAudioPCMBuffer`, which this port already carries. **The last sentence of the earlier reading of
  this bullet was wrong**: "no 6.x buffer path has" a renderer a `CMSampleBuffer` can be timed
  against is not true - `AudioToolbox` on 6.1.3 armv7 exports `_AudioQueueNewOutput`,
  `_AudioQueueAllocateBuffer`, `_AudioQueueEnqueueBuffer` and `_AudioQueueFlush`, `CoreMedia`
  exports `_CMTimebaseCreateWithMasterClock`, `_CMTimebaseSetTime` and `_CMTimebaseGetTime`
  (the plain `_CMTimebaseCreate` is **not** one of them - it is 0 in this release's CoreMedia),
  and
  `_CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer` is there to get the audio out of a
  sample buffer.
  **And the split that followed was wrong too**: `AudioQueueBuffer` carrying no time field is not
  what decides it, because the time is not carried on the buffer - it is the tenth argument of
  `_AudioQueueEnqueueBufferWithParameters`, which 6.1.3's `AudioToolbox` exports among its 43
  `AudioQueue` symbols (`AudioQueue.h:1189`, and its note at :1181 that the sample time is relative to
  the time the queue started). So neither class is a wall and both are carried: the port's own
  `AVFoundation/AVSampleBufferRenderSynchronizer11.m`, `AVFoundation/AVSampleBufferAudioRenderer11.m`,
  `AVFoundation/AVSampleBufferRenderSynchronizer12.m` and `AVFoundation/AVSampleBufferRenderSynchronizer14.m`,
  one release each. [`SampleBufferRender11.md`](SampleBufferRender11.md) has the numbers, the two-step
  that builds the clock, the eleven mutations of the differential that holds them against this
  machine's own two classes, and the two claims of the earlier reading of this bullet that were wrong:
  the 11.0 API *is* declared in this Mac's SDK for every member it has, so the class there is the
  oracle and not a different thing (51 own instance methods, 39 for the synchronizer), and the release's
  own `AVSampleBufferDisplayLayer` needs no backport because 6.1.3 carries it.
- `AVCapturePhoto`: 6.1.3 captures a still through `AVCaptureStillImageOutput` and delivers a
  `CMSampleBufferRef` (`captureStillImageAsynchronouslyFromConnection:completionHandler:`,
  `availableImageDataCodecTypes`, `imageDataFormatType`, `previewImageSize`). There is no photo
  object in either end, and a class row cannot be carried over a sample buffer. What the port does
  instead is written down in
  [AVCapturePhotoOutput.md](AVCapturePhotoOutput.md), "Open": the port's own `AVCapturePhotoOutput`
  builds the still's previews, thumbnail and Exif itself and hands the still over through the
  10.0 `captureOutput:didFinishProcessingPhotoSampleBuffer:…` callback, refusing a delegate that has
  only the 11.0 one. The `AVCapturePhoto` object and `captureOutput:didFinishProcessingPhoto:error:`
  are the work that row names and the port has not done; this file does not count a port that has
  not written a class as an absence of the release, and the row says which is which.

## What the object for the four implemented rows is, and how it was checked

Two files, and every API either of them defines arrived in 11.0, so neither spans two releases and
neither carries a class the release already has (`AVCaptureDevice` and `AVCaptureConnection` are
classes of 6.0, present at both band ends):

- `AVFoundation/AVCaptureDevice+VideoZoomRange11.m`, a category on `AVCaptureDevice` defining
  `-maxAvailableVideoZoomFactor` and `-minAvailableVideoZoomFactor`. Both numbers come out of the
  port's own 7.0 property, so the section above is the whole derivation; nothing is stored and no
  release method is hooked.
- `AVFoundation/AVCaptureConnection+CameraIntrinsics11.m`, a category on `AVCaptureConnection`
  defining `-isCameraIntrinsicMatrixDeliverySupported`, `-isCameraIntrinsicMatrixDeliveryEnabled`
  and `-setCameraIntrinsicMatrixDeliveryEnabled:`. The header declares both properties with
  `getter=is...` (`AVCaptureSession.h:985` and `:995`, the properties being declared on
  `AVCaptureConnection`), so those three are the selectors an application compiled against the real
  SDK sends, and the property name itself is not a selector. The refusal of the flag is said once
  through `../CharonSayOnce.h`, the seam the rest of the port uses for it.

**The rows keep their place in `absent_AVFoundation.json`.** That file has carried `implemented`
rows for a while - `-setExposureTargetBias:completionHandler:` among them - so these four were
edited where they are rather than moved into a file named after their release: a row moved out of a
shared file is a conflict this change did not cause.

**What was checked here, and what the check could not see.** Both files compile clean for the 6.0
armv7 target against SDK 16.4 with `-Wall -Wextra -fobjc-arc -fobjc-runtime=ios-6.0`: zero errors
and zero warnings, with no `#pragma clang diagnostic ignored` in either, which is why neither needs
one. The four selector names were then read out of the images' own bytes rather than from their
metadata:

    $ for r in 6.1.3 4.3; do for s in maxAvailableVideoZoomFactor minAvailableVideoZoomFactor \
        cameraIntrinsicMatrixDeliverySupported cameraIntrinsicMatrixDeliveryEnabled \
        setCameraIntrinsicMatrixDeliveryEnabled focusMode videoScaleAndCropFactor; do
        printf '%s %s %s\n' $r $s "$(strings -a ~/.charon/dyld/$r/dyld_shared_cache_armv7 | grep -cxF $s)"; done; done
    6.1.3 maxAvailableVideoZoomFactor 0            4.3 maxAvailableVideoZoomFactor 0
    6.1.3 minAvailableVideoZoomFactor 0            4.3 minAvailableVideoZoomFactor 0
    6.1.3 cameraIntrinsicMatrixDeliverySupported 0  4.3 cameraIntrinsicMatrixDeliverySupported 0
    6.1.3 cameraIntrinsicMatrixDeliveryEnabled 0    4.3 cameraIntrinsicMatrixDeliveryEnabled 0
    6.1.3 setCameraIntrinsicMatrixDeliveryEnabled 0 4.3 setCameraIntrinsicMatrixDeliveryEnabled 0
    6.1.3 focusMode 3                              4.3 focusMode 2
    6.1.3 videoScaleAndCropFactor 2                4.3 videoScaleAndCropFactor 1

The last two lines are the control: the same reader, the same command, a hit where a name is known
to be there. `lockForConfiguration` and `isVideoStabilizationSupported` read 0 at 4.3, which is what
4.3 predating them should look like, and neither is used as a control here.

What this does not see: `tools/release-split.lua` over these two objects would print "clean" with
`0 symbols`, and the 0 is the tool's own documented blind spot - a category's methods export no
symbol - so a clean line would say nothing about these files. The measurement that does see them is
the byte table above, plus the compile, plus the four rows' own `source` lines.

## What this does not close

- Nothing here is measured on a device. Every claim is read out of the armv7 caches of 6.1.3 and
  4.3, which are the two ends the package deploys on, and out of the registry's own `introduced`.
- `minAvailableVideoZoomFactor`, `sourceTrackIDForFrameTiming` and `videoApertureMode` read a
  first rung of 10.0.1 by name; the class-scoped runs are what place them on their owners, and the
  registry's 11.0 stands because the SDK's availability says 11.0.
- The four `implemented` rows are implemented over the release's own limit and the brief's
  documented-NO policy. They do not add a camera capability: a device that lacks the hardware still
  answers NO, and the rows say so.
