# iOS 16's AVFoundation rows on 6.1.3: the 36 that `absent_AVFoundation.json` places at 16.0 and 16.4

Read class by class, with the reader certified on every release it was run against. Nine of the 36 are
carried; one of those nine is stored and not applied, which is what `inert` is; the other 27 are `absent`
with the release-side measurement in each row.

## The reader, and its control on every release

the deleted class-scoped row reader asks one question per row: does the OWNER CLASS answer that member
on that release. A name's first rung cannot answer it, because the ladder measures presence of a name
rather than of a member - `fileSystemRepresentation` reads 3.0 from another class's selector of that
name, and `init` reads 3.0, which is NSObject's.

```
CHARON_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.charon/dyld/6.1.3/dyld_shared_cache_armv7 \
    > .agent-work/runs/wav/inv-6.1.3.tsv                      # 12549 lines
CHARON_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.charon/dyld/4.3/dyld_shared_cache_armv7 \
    > .agent-work/runs/wav/inv-4.3.tsv                         #  7751 lines
CHARON_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.charon/dyld/7.0/dyld_shared_cache_armv7 \
    > .agent-work/runs/wav/inv-7.0.tsv                          # 16492 lines
# the removed class-scoped row read, arguments: \
    $HOME/Git/projects/ios/coordination/corpus/queue/SLICE-AVFoundation-absent_AVFoundation-16.tsv \
    6.1.3=.agent-work/runs/wav/inv-6.1.3.tsv 4.3=.agent-work/runs/wav/inv-4.3.tsv \
    7.0=.agent-work/runs/wav/inv-7.0.tsv
```

Its three controls, on all three releases, from the first nine lines of that run's output:

```
# control 6.1.3  -[AVPlayerItem duration]                    method  want CARRIED   got CARRIED
# control 6.1.3  -[AVPlayerItem aSelectorNoFrameworkHas]     method  want ABSENT    got ABSENT
# control 6.1.3  -[AVCompositionTrack mediaType]             method  want INHERITED got INHERITED
# control 4.3    ... the same three, all three as wanted
# control 7.0    ... the same three, all three as wanted
```

**Every one of the 36 rows reads ABSENT or NO CLASS on 6.1.3.** So none of them is the release's own,
and `check_registry`'s `held` arm cannot fire on any of them at any status.

## The 6.1.3 class tables the nine forwards were read out of

| class on 6.1.3 armv7 | own instance | own class | what the row needs |
| --- | --- | --- | --- |
| `AVAssetImageGenerator` | 31 | 1 | `-generateCGImagesAsynchronouslyForTimes:completionHandler:` |
| `AVMutableComposition` | 14 | 1 | `-insertTimeRange:ofAsset:atTime:error:` |
| `AVVideoComposition` | 26 | 3 | `+videoCompositionWithPropertiesOfAsset:`, `+videoCompositionWithPropertiesOfAsset:videoGravity:`, `-isValidForAsset:timeRange:validationDelegate:` |
| `AVMutableVideoComposition` | 12 | 3 | `+videoCompositionWithPropertiesOfAsset:`, `+videoCompositionWithPropertiesOfAsset:videoGravity:` |
| `NSValue` | carries neither | - | `+valueWithCMVideoDimensions:`, `-CMVideoDimensionsValue` are the port's own |
| `AVPlayer` | 140 | 19 | `-rate`, `-setRate:`, `-setRate:time:atHostTime:`, `-play` and nothing that separates the rate playing now from the rate a `-play` would use |

Each of those five members is declared by the 16.4 SDK as iOS 4.0, iOS 5.0 or iOS 6.0 API, so the port
calls a documented member the release already has rather than a private one:
`AVComposition.h:220` (`insertTimeRange:ofAsset:atTime:error:`, ios(4.0)),
`AVAssetImageGenerator.h:193`, `AVVideoComposition.h:64` and `:285` (both ios(6.0)),
`AVVideoComposition.h:968` (`isValidForAsset:timeRange:validationDelegate:`, ios(5.0)).

## The prototype-instruction factory, which is the only forward that is not a one-liner

`videoCompositionWithPropertiesOfAsset:prototypeInstruction:completionHandler:` takes an
`id<AVVideoCompositionInstruction>`, and that protocol is `API_AVAILABLE(ios(7.0))`
(`AVVideoCompositing.h:380`). 6.1.3 has no such protocol: of the 16 AV-named protocols in its armv7
cache - `AVAssetWriterFigAssetWriterNotificationHandlerDelegate`, `AVAssetWriterFinishWritingHelperDelegate`,
`AVAsynchronousKeyValueLoading`, `AVAudioPlayerDelegate`, `AVAudioSessionDelegate`,
`AVAudioSessionDelegateMediaPlayerOnly`, `AVCaptureFileOutputPauseResumeDelegate`,
`AVCaptureFileOutputRecordingDelegate`, `AVCaptureVideoDataOutputSampleBufferDelegate`,
`AVConferenceDelegate`, `AVDecodedAudioSettingsForFig`, `AVDecodedVideoSettingsForFig`,
`AVOutputSettingsValidation`, `AVRecorderImpl`, `AVReencodedAudioSettingsForFig` and
`AVReencodedVideoSettingsForFig` - the composition instruction protocol is not one of them. What 6.1.3
accepts into `-setInstructions:` is an instance of the `AVVideoCompositionInstruction` class, which
carries `-mutableCopyWithZone:`, `-setTimeRange:` and `-setLayerInstructions:`. So the port builds the
composition of the asset's own properties and puts a mutable copy of the prototype into it with the
asset's duration as its time range; a prototype of any other shape cannot be honoured, and the row
says so.

The failure is reported in a domain of the port's own because the release has no error code for it:

```
$ printf '%s\n' _AVErrorUnknown _AVErrorOperationNotSupportedForAsset _kCMPersistentTrackID_Invalid \
    _kCMVideoCodecType_H264 _AVMediaCharacteristicIsDefault _NSURLSession _CMSampleBufferGetSampleCursor \
    _CMSampleBufferIsSampleCursorValid _AVAssetTrackGroupOutputHandlingPreserveAlternateTracks \
    _AVPlayerTimeControlStatusPlaying _AVPlayerItemStatusReadyToPlay | xmake l tools/cache-index/first-rung.lua
_AVErrorUnknown	NONE
_AVErrorOperationNotSupportedForAsset	NONE
_kCMPersistentTrackID_Invalid	NONE
_kCMVideoCodecType_H264	NONE
_AVMediaCharacteristicIsDefault	NONE
_NSURLSession	NONE
_CMSampleBufferGetSampleCursor	NONE
_CMSampleBufferIsSampleCursorValid	NONE
_AVAssetTrackGroupOutputHandlingPreserveAlternateTracks	NONE
_AVPlayerTimeControlStatusPlaying	NONE
_AVPlayerItemStatusReadyToPlay	NONE
```

`AVFoundationErrorDomain` itself reads 4.0 and is used; only the codes are missing.

## What the sample cursor family is blocked on

Four of the `absent` rows are the sample cursor (`AVSampleCursor` and the three `AVAssetTrack`
factories) and four more are what a cursor feeds (`AVSampleBufferGenerator`,
`AVSampleBufferGeneratorBatch`, `AVSampleBufferRequest`, `AVAssetTrack.canProvideSampleCursors`). A
cursor needs indexed per-sample access. 6.1.3's `AVAssetTrack` carries 52 own instance methods and the
only ones that speak of position are `-segments`, `-segmentForTrackTime:` and
`-samplePresentationTimeForTrackTime:`; none of them enumerates samples, and CoreMedia's cursor
entry points (`CMSampleBufferGetSampleCursor`, `CMSampleBufferIsSampleCursorValid`) read NONE above,
i.e. no held release exports them. There is nothing on this release for a cursor to step over, and a
property whose answer would be a constant is not an implementation.

## What the capture rows are blocked on

Ten rows are studio-light, centre-stage, continuity-camera or depth-delivery state. The definition in
each row is release-side - the member does not exist on the owner's own table on 6.1.3, which is
`ABSENT` for all of them - and the hardware is only why the release has no such member. Two of them
cannot even be asked of 4.3, whose armv7 cache has no `AVCaptureDeviceFormat` at all (`NO CLASS`):
`secondaryNativeResolutionZoomFactors`, `studioLightSupported`, `supportedMaxPhotoDimensions`,
`supportedVideoZoomFactorsForDepthDataDelivery` and `videoFrameRateRangeForStudioLight`.

## `AVPlayer.defaultRate` is inert, not absent

The release's rate vocabulary is `-rate`, `-setRate:`, `-setRate:time:atHostTime:`, `-minRateForAudioPlayback`,
`-maxRateForAudioPlayback` and `-play`, and `-play` sets the rate to 1.0 itself
(`AVPlayer.h:196`, "For releases up to iOS version 16.0 ... this is equivalent to setting the value of
rate to `1.0`"). So the value this property carries is exactly the behaviour the release already has and
no member of it reads the value: the port stores and returns it, and that is the whole of the row.
`AVPlayer.h:184` gives the default as 1.0 and `AVPlayer.h:186` says `-setRate:` skips this value
entirely, so both the stored default and the reason nothing applies it come from the header rather
than from a value composed here. The one row that would consume it, `-playImmediatelyAtRate:`, is
10.0's and rides in `AVFoundation100.m`.

## What was not verified here

No band build and no 6.1.3 gate was run: the only build this worktree is allowed is
`xmake l $HOME/Git/projects/ios/coordination/run_light_tests.lua`. The objects were compiled on their
own with the shared `llvm` package's clang at `-target armv7-apple-ios6.0 -isysroot` the 16.4 SDK with
the flags `modules/apple/backports.lua`'s `compile_arguments` uses, and every symbol they reference was
checked against 6.1.3's own cache with `first-rung.lua`. Whether a band links them is not verified.