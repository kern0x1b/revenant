# iOS 7's AVFoundation on a release that arrived before it: the 79 rows, read class by class

The 79 rows of `absent_AVFoundation.json` that `API_AVAILABLE(ios(7.0))` puts at 7.0. Every one of them
is a member of a class the release already carries, or of a class the release does not have at all, so
the question each row asks is not "does a name exist anywhere" but "does THIS class have THIS member on
the release the port runs on".

## The ladder, and the two questions a name cannot answer

Measured over five releases, each one read as `objc-inventory.lua` dumps through
the deleted class-scoped row reader, with the ladder's own architecture choice
(`dyld.held_ladder({"armv7","armv7s"})`): 4.3 armv7, 6.0 armv7, 6.1.3 armv7, 7.0 armv7 and 7.0 armv7s as a
cross-check, 7.1 armv7.

A selector's first rung says nothing about its owner, measured twice on 2026-09-30: `fileSystemRepresentation`
reads 3.0 (another class's selector of that name) while `-[NSURL fileSystemRepresentation]` is 7.0, and
`init` reads 3.0, which is NSObject's. So each row was looked up in its OWNER's class line.

Two more traps in the same shape, both hit while measuring this file:

- **The own table is not the class.** `-[AVCompositionTrack associatedTracksOfType:]` is `ABSENT` on
  6.1.3 and `INHERITED` on 7.0 — AVCompositionTrack answers it from AVAssetTrack. An own-table-only read
  would have written the 7.0 rung down as absent too.
- **A name of the row's can belong to another class in the port itself.** `extendedLanguageTag` is one of
  the rows (on `AVMediaSelectionOption`) and the port's own `AVMetadataItem` declares
  `-extendedLanguageTag` in `AVMetadataItem+Identifiers8.m`. Grepping the tree for the name finds the
  wrong class and would have flipped a row to `implemented`.

| release | CARRIED | INHERITED | ABSENT | NO CLASS | NO PROTOCOL |
| --- | --- | --- | --- | --- | --- |
| 4.3 armv7 | 0 | 0 | 56 | 21 | 2 |
| 6.0 armv7 | 0 | 0 | 68 | 9 | 2 |
| **6.1.3 armv7** | **0** | **0** | **68** | **9** | **2** |
| 7.0 armv7 | 77 | 2 | 0 | 0 | 0 |
| 7.0 armv7s | 77 | 2 | 0 | 0 | 0 |
| 7.1 armv7 | 77 | 2 | 0 | 0 | 0 |

**What the cache said that the headers did not.** Nothing here contradicts `introduced: 7.0`: at 7.0 every
one of the 79 is on its owner, and at 6.1.3 not one is. The header annotation is confirmed for all 79 by a
read that could have refuted it. Two things the headers alone would have got wrong:

- `AVMutableAudioMixInputParameters.audioTimePitchAlgorithm` and `-[AVCompositionTrack
  associatedTracksOfType:]` are **not** on the class the row names even at 7.0; both arrive through
  `AVAudioMixInputParameters` and `AVAssetTrack`. The row's `introduced` is right and the class the row
  names is the one that would have been searched for nothing.
- The 4.3 band shows 21 `NO CLASS` against 9 at 6.0: seven of the nine owner classes arrive with iOS 6
  itself, which is why the rows carry `minimum: 6.0` and not 4.3.

## The host, asked once

`tools/host-has-row.m` over the same 79 rows, this Mac's own AVFoundation loaded,
through `coordination/heavy.sh`:

    #SUMMARY input_lines=80 parsed=79 has=71 lacks=8 malformed=0 unparsed=1

The `unparsed=1` is the queue file's trailing blank line, and the tool refused to certify the run rather
than report totals that did not cover its input. All four of its controls answered correctly
(`-[NSURLSessionTask cancel]` HAS, `-[NSURLSessionTask revenantProbeNoSuchSelector]` LACKS,
`NSAttributedString` HAS, `NSRevenantProbeNoSuchClass` LACKS).

The eight `LACKS` are not eight absences, and reading them as such would be the third shape of the same
trap:

| row | why the host does not answer |
| --- | --- |
| `AVCaptureDevice.autoFocusRangeRestrictionSupported` | `API_UNAVAILABLE(macos, tvos)` at `AVCaptureDevice.h:1107` |
| `AVCaptureDevice.smoothAutoFocusSupported` | `API_UNAVAILABLE(macos, tvos)` at `AVCaptureDevice.h:1127` |
| `AVCaptureDeviceFormat.videoBinned` | `API_UNAVAILABLE(macos)` at `AVCaptureDevice.h:2590` |
| `AVCaptureStillImageOutput.stillImageStabilizationSupported` | `API_UNAVAILABLE(macos)` at `AVCaptureStillImageOutput.h:79` |
| `AVCaptureStillImageOutput.stillImageStabilizationActive` | `API_UNAVAILABLE(macos)` at `AVCaptureStillImageOutput.h:99` |
| `-[AVAssetResourceLoaderDelegate resourceLoader:didCancelLoadingRequest:]` | the row's owner is a **protocol**, and the probe asks `NSClassFromString` (`tools/host-has-row.m:63`), which no protocol answers |
| `-[AVPlayerItemLegibleOutputPushDelegate legibleOutput:didOutputAttributedStrings:nativeSampleBuffers:forItemTime:]` | the same |
| `AVAssetResourceLoadingRequest.cancelled` | the property's getter is `isCancelled` (`AVAssetResourceLoader.h:216`) and the probe's property branch asks the property's own name and `set…:` only (`tools/host-has-row.m:82-88`) |

So **no row of the 79 is a capability the host lacks.** Five are Apple's own annotation, three are the
probe's shape. The last one is a defect in a shared tool, reported and not patched here:
`tools/host-has-row.m`'s property branch does not try the `is` spelling, which
`tests/backports/host/mediaplayeritem/` documented for MPMediaItem and which is now measured a third time.

And one row runs the other way: the iOS SDK marks `videoFieldOfView` `API_UNAVAILABLE(macos)` at
`AVCaptureDevice.h:2580`, and the macOS runtime answers it anyway, so the annotation is about the
documented availability and not about what the framework's own binary carries.

## What each owner carries at 6.1.3 where 7.0 has the row

Own instance selectors, read from each release's own class line. This is the substrate a port would build
on, and it is what the rows now name.

| class | 6.1.3 | 7.0 | at 6.1.3, where 7.0's member is not |
| --- | --- | --- | --- |
| `AVCaptureDevice` | 100 | 134 | `-focusMode`, `-setFocusMode:`, `-isFocusModeSupported:`, `-lockForConfiguration:`, `-focusPointOfInterest` — no focus **range**, no smooth focus |
| `AVCaptureDeviceFormat` | 11 | 39 | `-isBinned`, `-hasBinned`, `-formatDescription`, `-supportedStabilizationMethod`, `-videoSupportedFrameRateRanges` |
| `AVCaptureSession` | 84 | 91 | 7.0 adds `-masterClock`, `-_determineMasterClock`, `-_setMasterClock:`; 6.1.3 has no clock member at all |
| `AVCaptureInputPort` | 11 | 14 | `-input`, `-mediaType`, `-formatDescription`, `-isEnabled`, `-setEnabled:`, `-setOwner:` — no clock |
| `AVCaptureMetadataOutput` | 13 | 18 | 7.0 adds `-rectOfInterest`, `-setRectOfInterest:`; 6.1.3 has `-metadataObjectTypes`, `-availableMetadataObjectTypes`, `-metadataObjectsDelegate` |
| `AVCaptureOutput` | 26 | 29 | `-updateMetadataTransformForCaptureOptions:`, `-transformedMetadataObjectForMetadataObject:connection:` — the metadata transform is kept, the public rect conversion is not |
| `AVCaptureVideoPreviewLayer` | 54 | 58 | 7.0 adds the two rect conversions; 6.1.3 has `-pointForCaptureDevicePointOfInterest:`, `-captureDevicePointOfInterestForPoint:`, `-rectForCaptureDeviceFaceRect:` |
| `AVPlayerItemAccessLogEvent` | 20 | 32 | 6.1.3 keeps only the aggregates: `indicatedBitrate`, `observedBitrate`, `numberOfBytesTransferred`, `numberOfSegmentsDownloaded`, `segmentsDownloadedDuration`, `numberOfStalls`, `numberOfMediaRequests`, `numberOfServerAddressChanges`, `durationWatched`, and `initWithDictionary:` |
| `AVVideoCompositionLayerInstruction` | 21 | 27 | `-getOpacityRampForTime:startOpacity:endOpacity:timeRange:` and its transform twin are there; the crop ramp and `-setCropRectangle:atTime:` are 7.0's, and 6.1.3 has no crop member to store one in |
| `AVMediaSelectionOption` | 24 | 30 | `-locale`, `-optionID`, `-_title`, `-propertyList`, `-dictionary`, `-metadataForFormat:`; 7.0 adds `displayName`, `displayNameWithLocale:`, `extendedLanguageTag` |

`CMClockGetHostTimeClock` is carried from 6.0 (`tools/cache-index/first-rung.lua`, with `_NSFileSize`
answering 3.0 as the index's own control), so the clock type is on the floor; what 6.1.3 lacks is any way
to reach one from the capture stack.

## The one row the release does answer, under another name

`AVCaptureDeviceFormat.videoBinned` is the only one of the 79 the port carries, and it is carried
because the release has the answer and only spells it differently. This was the row the table above
could not settle: `-isBinned` and `-isVideoBinned` are both "is this format binned", and reading
the table cannot say whether Apple renamed one method or added a second question. Reading the two
bodies settles it.

Both bodies are the same three steps. Each loads the ivar at offset 4 of the receiver, each sends
`-objectForKey:` on the object it loaded, each turns the answer into a `BOOL`. The only difference is
the key, and the key is a plain string in each image's own `__cstring`:

| release | `__cstring` of the AVFoundation image, filtered on `Binned` |
| --- | --- |
| 6.1.3 armv7 | `0x30351d96 "Binned"`, `0x3035222b "LiveSourceOptions.Binned"` -- and **0** strings naming `videoBinned` |
| 7.0 armv7 | `0x2c3c257f "videoBinned"`, `0x2c3c258b "Tc,R,N,GisVideoBinned"`, `0x2c3c2b59 "LiveSourceOptions.Binned"` |

The zero is the control: the same 6.1.3 run that finds 0 strings naming `videoBinned` finds 16
naming `olume` and 2 naming `Binned`, so the reader was looking and the name is not there.
`first-rung.lua` agrees on the two selectors, `isBinned` at 6.0 and `isVideoBinned` at 7.0, and
`"LiveSourceOptions.Binned"` is the session-level key both sides carry and is not this property.

So `-[AVCaptureDeviceFormat isVideoBinned]` is `-[self isBinned]`, and that is what
`AVCaptureDeviceFormat+Binning7.m` writes. The selector is `isVideoBinned` and not `videoBinned`
because the header declares `getter=isVideoBinned` at `AVCaptureDevice.h:2590`, and the property is
`readonly`, so there is no setter to define. The port forwards; it does not read the dictionary
itself and does not compute a second answer.

## Why the object is inert from 7.0 up, which is what makes the forward safe

The row's `minimum` is 6.0, so the object is carried from 6.0 up -- and it is compiled into both
bands, `build/objects` and `build/objects-7.0`, each holding
`-[AVCaptureDeviceFormat(RevenantBinnedVideo) isVideoBinned]` and its
`__OBJC_$_CATEGORY_AVCaptureDeviceFormat_$_RevenantBinnedVideo` metadata. A category's methods are not
symbols and are never dropped from the rung up, so being carried at 7.0 is not in doubt. What is in
doubt is whether a category method **replaces** the release's own, because 7.0 has
`-isVideoBinned` and does **not** have `-isBinned`:

| release | `-isBinned` | `-isVideoBinned` |
| --- | --- | --- |
| 6.1.3 armv7 | present, IMP 0x30330259 | absent |
| 7.0 armv7 | **absent** | present, IMP 0x2c3943b5 |

If the port's copy replaced the release's, every 7.0-and-later caller of `isVideoBinned` would reach
`[self isBinned]` on a release that has no such method. It does not replace it, and the reason is in
`packages/a/apple-backports/attach.c`: `revenant_collect` adds a category's method only when
`!revenant_implements(cls, selector)`, and `revenant_implements` walks the class and its superclasses.
So at 6.1.3, where nothing implements `isVideoBinned`, the port's method is installed and forwards
to the release's `-isBinned`; at 7.0 and above, where the release implements `isVideoBinned`, the
port's method is not installed at all and the release's own body runs, reading the `videoBinned` key
it was written for. One object, correct on both ends, and the guard is the library's, not a check
this object performs.

This is also why the AGENTS.md trap about `+load` does not apply here, and why
`AVPlayerMediaSelectionCriteria7Members.m` can sit beside `AVPlayerMediaSelectionCriteria7.m` for
members that arrived a release later: a category is kept from the rung up and installs itself only
where the release is short.

Neither `release-split` nor `nm` can see any of this. `release-split` reported
`clean, every object file's symbols first-appear in one release (104 files, 824 symbols, 50 releases
checked)`, and the object exports no symbol to be mixed; the selector itself was checked against the
caches with a control, where `first-rung.lua` answers `isVideoBinned` 7.0 and `isBinned` 6.0 and its
own control `_NSFileSize` answers 3.0, and a raw selector-string search of the two armv7 caches
answers 1 for `isVideoBinned` at 7.0 and **0** at 6.1.3.

### The bodies, as read

`code_map` over each cache for the IMP, then a THUMB disassembly with every literal-pool load
resolved, because the cache has slid its pointers and a raw walk of a `method_t` list reads a
`class_ro_t`'s method list as if nothing had moved -- the deleted mach32 reader's own
`ro + 20` read returns "entries of 940877676 bytes" on this cache, which is the reason the two
bodies were read through `apple.objc`'s slide-resolving reader instead.

    -[AVCaptureDeviceFormat isVideoBinned]  7.0 armv7   IMP 0x2c3943b5 (THUMB)
    -[AVCaptureDeviceFormat isBinned]       6.1.3 armv7 IMP 0x30330259 (THUMB)

    # 7.0, -[AVCaptureDeviceFormat isVideoBinned]
    ldr  r2, [r0, r2]      ; the ivar at offset 4          (pool 0x3815d844 holds 4)
    ldr  r0, [r0, r3]      ; the object it holds
    ldr  r1, [r1]          ; pool 0x38150e6c -> selector objectForKey:
    ldr  r0, [r0, r3]      ; the dictionary
    blx  ...               ; -[dict objectForKey: "videoBinned"]
    ldr  r1, [r1]          ; the second pool word
    blx  ...               ; the answer to a BOOL

## Reproducing

    REVENANT_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.revenant/dyld/6.1.3/dyld_shared_cache_armv7 \
        > 6.1.3.armv7.inventory.tsv
    REVENANT_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.revenant/dyld/7.0/dyld_shared_cache_armv7 \
        > 7.0.armv7.inventory.tsv
    # the removed class-scoped row read, arguments: --inventory 6.1.3 7.0 \
        -- $HOME/Git/projects/ios/coordination/corpus/queue/avfoundation-7_0.tsv

The tool prints three controls per release and writes no row if any of them is wrong, because `ABSENT` is
what a reader that read nothing produces.
## The two ends of the port's floor, read together (2026-10-01, band w02-avf-r7)

The run above compares 6.1.3 with 7.0, which settles what the header annotation means. What a row's
`status` needs is the other question: does any band end carry the substrate? `backports.lua:2578` holds a
band against the FIRST and LAST release of its range, and the port's floor is 4.3 on one side and 6.1.3
on the other, so both ends were read in one run, from the two `objc-inventory.lua` dumps those two
caches produce:

    REVENANT_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.revenant/dyld/4.3/dyld_shared_cache_armv7 \
        > 4.3.armv7.inventory.tsv
    REVENANT_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.revenant/dyld/6.1.3/dyld_shared_cache_armv7 \
        > 6.1.3.armv7.inventory.tsv
    # the removed class-scoped row read, arguments: \
        $HOME/Git/projects/ios/coordination/corpus/queue/SLICE-AVFoundation-absent_AVFoundation-7.tsv \
        4.3=4.3.armv7.inventory.tsv 6.1.3=6.1.3.armv7.inventory.tsv

Its output, the control lines and the tallies verbatim and nothing else:

    # 79 rows x 2 releases: 4.3, 6.1.3
    # control 4.3          -[AVPlayerItem duration]                           method  want CARRIED   got CARRIED
    # control 4.3          -[AVPlayerItem aSelectorNoFrameworkHas]            method  want ABSENT    got ABSENT
    # control 4.3          -[AVCompositionTrack mediaType]                    method  want INHERITED got INHERITED
    # control 6.1.3        -[AVPlayerItem duration]                           method  want CARRIED   got CARRIED
    # control 6.1.3        -[AVPlayerItem aSelectorNoFrameworkHas]            method  want ABSENT    got ABSENT
    # control 6.1.3        -[AVCompositionTrack mediaType]                    method  want INHERITED got INHERITED
    # --- per release ---
    # 4.3          {'ABSENT': 56, 'NO CLASS': 21, 'NO PROTOCOL': 2}
    # 6.1.3        {'ABSENT': 68, 'NO CLASS': 9, 'NO PROTOCOL': 2}

**Zero CARRIED and zero INHERITED at either end, for all 79.** Three controls answer per release and all
six are right, including the one that fails when the reader is blind: a nonsense selector is ABSENT while a
real one is CARRIED and an inherited one is INHERITED. So no row of this file can be `implemented`, and
the object that would implement one would export a symbol no band end ever reaches — the outcome
`AVFoundation70.md`'s sibling for UIKit 16.0 measured on the same day.

The 21 `NO CLASS` at 4.3 against 9 at 6.1.3 are the twelve owner classes that arrive with iOS 6 itself,
which is what these rows' `minimum: 6.0` records. The nine absent at 6.1.3 too:

    AVAssetResourceLoadingContentInformationRequest   AVPlayerItemLegibleOutput
    AVAssetResourceLoadingDataRequest                  AVPlayerItemLegibleOutputPushDelegate
    AVAsynchronousVideoCompositionRequest              AVPlayerMediaSelectionCriteria
    AVOutputSettingsAssistant                          AVVideoCompositing
    AVVideoCompositionRenderContext                    AVAssetResourceLoaderDelegate

Eight of the nine are absent at BOTH ends, so no band of the port's ladder has them. `AVAssetResourceLoaderDelegate`
is the exception and the shape matters: it is a PROTOCOL, and the deleted class-scoped row reader answers `NO CLASS`
for it because it looks the name up among classes and the release has no class by that name. 6.1.3 has no
such protocol either - it is one of the two `NO PROTOCOL` verdicts below.

## What each owner DOES carry at 6.1.3, for the rows that are not buildable

A row that says only "it arrived in iOS 7" is a queue entry. These are the release's own members, read
from each class's own line, and they are what a caller has instead.

- **`AVVideoCompositionLayerInstruction` carries opacity and transform and nothing else.** All 21 own
  instance methods at 6.1.3, with `-setTrackID:`/`-trackID`, `-getOpacityRampForTime:startOpacity:endOpacity:timeRange:`,
  `-getTransformRampForTime:startTransform:endTransform:timeRange:` and their setters, plus
  `-dictionaryRepresentationWithTimeRange:` and the NSCoding pair. There is no crop member of any kind to
  store a rectangle in, so `setCropRectangle:atTime:` and its ramp twin are 7.0's and
  `getCropRectangleRampForTime:...` has nothing on this release to read out of.
- **`AVMutableVideoComposition.customVideoCompositorClass` and its twin**: 6.1.3 has `-compositor` and
  `-setCompositor:` on `AVVideoComposition` and on the mutable subclass - it has a compositor object - but
  the object it takes is Apple's own `AVVideoCompositingVideoCompositor`, and `AVVideoCompositing`, the
  PROTOCOL a caller implements to be one, is one of the two `NO PROTOCOL` verdicts. So the release has
  where a compositor goes and no way to name a class for it, and `AVAsynchronousVideoCompositionRequest`
  and `AVVideoCompositionRenderContext` - the two objects such a compositor is handed - are `NO CLASS` at
  both ends. That is why the whole custom-compositing family is absent and not merely unimplemented.
- **`AVVideoCompositionInstruction` is a CLASS on both band ends, and carries 18 own instance methods**:
  `-timeRange`/`-setTimeRange:`, `-layerInstructions`/`-setLayerInstructions:`,
  `-backgroundColor`/`-setBackgroundColor:`, `-enablePostProcessing`/`-setEnablePostProcessing:`,
  `-dictionaryRepresentation`, `-init`, `-copyWithZone:`, `-mutableCopyWithZone:`, `-encodeWithCoder:`,
  `-initWithCoder:`, `-description`, `-dealloc`, `-finalize`, `-_setValuesFromDictionary:`. At 4.3 the 18
  are the same 18. So the NAME is on the floor at both ends and it is not a protocol there: 7.0 turned the
  class into a protocol, and of the five members that protocol requires, this release's class answers
  `-timeRange` and `-enablePostProcessing` by name and has no `-passthroughTrackID`, no
  `-requiredSourceTrackIDs` and no `-containsTweening`.
- **`AVPlayer` keeps its volume private.** All 140 own instance methods at 6.1.3 include `-_volume`,
  `-_setVolume:`, `-_setWantsVolumeChangesWhenPausedOrInactive:` and not one of `-volume`, `-setVolume:`,
  `-muted` or `-setMuted:`. The same 140 include `-masterClock`/`-setMasterClock:` - which is
  `AVPlayer`'s clock and not `AVCaptureSession`'s, the difference the `AVCaptureSession.masterClock` row
  has to make and `first-rung.lua` alone cannot.
- **`AVAssetTrack` answers `-preferredVolume` and has no `-minFrameDuration`.** 52 own instance methods at
  6.1.3: `-nominalFrameRate`, `-naturalTimeScale`, `-estimatedDataRate`, `-preferredVolume`,
  `-extendedLanguageTag`, `-loadValuesAsynchronouslyForKeys:completionHandler:`,
  `-statusOfValueForKey:error:`, `-trackID`, `-segments`, `-samplePresentationTimeForTrackTime:`. And
  `-extendedLanguageTag` is here, on a track, while `AVMediaSelectionOption.extendedLanguageTag` - a row
  of this file - has no such member on the same release: the name belongs to another class, which is the
  trap the ladder's `first rung` cannot see. Track association is on the WRITER at this release and not on
  the track: `AVAssetWriterInput` carries `-addTrackAssociationWithTrackOfInput:type:` and
  `-canAddTrackAssociationWithTrackOfInput:type:` (52 own methods at 6.1.3), while `AVAssetTrack` and
  `AVCompositionTrack` carry no association member at all - `AVCompositionTrack` has 6 own methods, all of
  them `-segments`, `-description`, `-dealloc`, `-finalize` and two private initialisers.
- **`AVAssetResourceLoadingRequest` exists at 6.1.3 and its 11 own methods are the LOADER's side.**
  `-finishLoadingWithResponse:data:redirect:`, `-finishLoadingWithError:`, `-finished`, `-request`,
  `-serializableRepresentation`, `-streamingContentKeyRequestDataForApp:contentIdentifier:options:error:`,
  `-initWithResourceLoader:requestDictionary:`. There is no `-finishLoading`, no `-cancelled`, no
  `-response`, `-redirect`, `-dataRequest` or `-contentInformationRequest`, and the protocol a caller
  implements to be asked is `NO PROTOCOL` at both ends - so on this release the object that fills a request
  in does not exist and the two request objects it would fill are `NO CLASS` at both ends too.
- **`AVPlayerItemAccessLogEvent` carries 20 own members and they are all aggregates**:
  `-indicatedBitrate`, `-observedBitrate`, `-numberOfBytesTransferred`, `-numberOfSegmentsDownloaded`,
  `-segmentsDownloadedDuration`, `-numberOfMediaRequests`, `-numberOfServerAddressChanges`,
  `-numberOfStalls`, `-numberOfDroppedVideoFrames`, `-durationWatched`, `-URI`, `-serverAddress`,
  `-playbackSessionID`, `-playbackStartDate`, `-playbackStartOffset`, `-initWithDictionary:`, `-init`,
  `-copyWithZone:`, `-dealloc`, `-finalize`. Not one of the nine per-segment detail rows of this file is
  among them, so there is no member to read and no member to store one in.
- **`AVMediaSelectionOption` at 6.1.3 (24 own methods) has `-locale`, `-optionID`, `-_title`,
  `-propertyList`, `-dictionary`, `-group`, `-associatedMediaSelectionOptionInMediaSelectionGroup:`,
  `-hasMediaCharacteristic:`, `-mediaSubTypes`, `-metadataForFormat:` and no `-displayName`, no
  `-displayNameWithLocale:` and no `-extendedLanguageTag`.** It is `NO CLASS` at 4.3, which is one of the
  twelve owner classes iOS 6 brought.
- **`AVCaptureVideoDataOutput` keeps its settings and not the recommendation.** 26 own methods at 6.1.3
  include `-videoSettings`/`-setVideoSettings:`, `-availableVideoCodecTypes`,
  `-availableVideoCVPixelFormatTypes`, `-vettedVideoSettingsForSettingsDictionary:` and
  `-minFrameDuration`/`-setMinFrameDuration:` - so the dictionary this call would recommend is reachable
  on the release - and no `recommendedVideoSettingsForAssetWriterWithOutputFileType:`.
  `AVCaptureAudioDataOutput` has 13 own methods and not one of them is a setting: `-sampleBufferDelegate`,
  `-setSampleBufferDelegate:queue:`, `-sampleBufferCallbackQueue`, `-connectionMediaTypes` and the graph
  hooks. There is nothing on it to recommend audio settings out of.
- **`AVCaptureStillImageOutput` has 33 own methods at 6.1.3 and no stabilisation member of any kind.**
  `-isHDRCaptureSupported`, `-isRawCaptureSupported`, `-setSuspendsVideoProcessingDuringStillImageCapture:`
  and `-suspendsVideoProcessingDuringStillImageCapture` are there; the two `is...Stabilization...` members
  and the switch that drives them are 7.0's.
- **`AVPlayerItemTrack` has 18 own methods at 6.1.3 - `-assetTrack`, `-trackID`, `-isEnabled`,
  `-setEnabled:`, `-fallbackTrack` and the private Fig plumbing - and no frame rate.**
  `-nominalFrameRate` is on the `AVAssetTrack` it wraps, not on the track the player hands a caller.
- **`AVAssetExportSession` has 54 own methods at 6.1.3**: `-audioMix`/`-setAudioMix:`,
  `-videoComposition`/`-setVideoComposition:`, `-metadata`/`-setMetadata:`, `-timeRange`/`-setTimeRange:`,
  `-determineCompatibleFileTypesWithCompletionHandler:`, `-setShouldOptimizeForNetworkUse:`,
  `-usesHardwareVideoEncoderIfAvailable`. No `-audioTimePitchAlgorithm`, no `-customVideoCompositor`, no
  `-metadataItemFilter` - and the port DOES define `AVMetadataItemFilter` itself, in
  `AVMetadataItemFilter.m`, so what is missing is the member that would attach it to an export.
- **The reader outputs**: `AVAssetReaderTrackOutput` has 12 own methods, `AVAssetReaderAudioMixOutput` 16
  and `AVAssetReaderVideoCompositionOutput` 14, and none of the three has an audio-time-pitch or custom
  compositor member - each carries its media type, its settings and its tracks, which is the whole of
  `AVAssetReaderOutput` on this release.
- **`AVAudioMixInputParameters` has 17 own methods at 6.1.3 and its whole surface is volume**:
  `-setVolume:atTime:`, `-setVolumeRampFromStartVolume:toEndVolume:timeRange:`,
  `-getVolumeRampForTime:startVolume:endVolume:timeRange:`, `-trackID`/`-setTrackID:`,
  `-audioTapProcessor`/`-setAudioTapProcessor:`. There is no rate and no pitch control to pitch.
