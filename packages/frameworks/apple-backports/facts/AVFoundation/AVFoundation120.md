# iOS 12's AVFoundation rows on 6.1.3: the 16 that `absent_AVFoundation.json` places at 12.0

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
    $HOME/Git/projects/ios/coordination/corpus/queue/SLICE-AVFoundation-absent_AVFoundation-12.tsv \
    6.1.3=.agent-work/runs/wav/inv-6.1.3.tsv 4.3=.agent-work/runs/wav/inv-4.3.tsv \
    7.0=.agent-work/runs/wav/inv-7.0.tsv
```

Its three controls, on all three releases, from the first nine lines of that run's output:
`-[AVPlayerItem duration]` CARRIED, `-[AVPlayerItem aSelectorNoFrameworkHas]` ABSENT,
`-[AVCompositionTrack mediaType]` INHERITED - all three as wanted on 6.1.3, on 4.3 and on 7.0.

Every row of the slice reads ABSENT or NO CLASS or NO PROTOCOL on 6.1.3, so none of the 16 is the
release's own.

## What this slice carries

One row, and it is `inert`: `AVPlayer.preventsDisplaySleepDuringVideoPlayback`. 6.1.3's `AVPlayer`
carries 140 own instance methods and 19 own class methods and no sleep member of any kind - its
playback vocabulary is `-rate`, `-setRate:`, `-play`, `-pause`, `-currentItem` and the
external-playback pair, and none of them touches the idle timer. The port stores and returns the
value, which is the whole of the row, and an unset player answers `AVPlayer.h:860`'s default: **YES**
on iOS.

## The 15 absent rows, in four families

**Fragmented-movie minding (5 rows).** `AVFragmentedAsset`, `AVFragmentedAssetTrack`,
`AVFragmentedAssetMinder`, `AVFragmentMinding.associatedWithFragmentMinder` and `AVFragmentedAsset`'
siblings stand on a fragment table, and 6.1.3's `AVAsset` carries 65 own instance methods whose only
members that speak of container composition are `-isComposable` and `-referenceRestrictions`. There is
no fragment minder to be associated with.

**The loading request's requestor (2 rows).** `AVAssetResourceLoadingRequestor` and
`AVAssetResourceLoadingRequest.requestor` need each other, and 6.1.3's `AVAssetResourceLoadingRequest`
carries 11 own instance methods - `-finishLoadingWithError:`, `-finishLoadingWithResponse:data:redirect:`,
`-request`, `-streamingContentKeyRequestDataForApp:contentIdentifier:options:error:` and their
companions - and no member that says who asked.

**Depth, exposure bounds and the portrait matte (4 rows).**
`AVPortraitEffectsMatte`, `AVCaptureDeviceFormat.portraitEffectsMatteStillImageDeliverySupported`
(4.3 reads NO CLASS as well), `AVCaptureDevice.activeDepthDataMinFrameDuration` and
`AVCaptureDevice.activeMaxExposureDuration`. `AVCaptureDeviceFormat`'s 11 own instance methods are
`-formatDescription`, `-mediaType`, `-videoSupportedFrameRateRanges`, `-isBinned`,
`-supportedStabilizationMethod`, `-supportsLowLightBoost` and their few companions, and none is a
depth or a matte. `activeMaxExposureDuration` deserves its own line: 6.1.3's `AVCaptureDevice` does
carry `-exposureDuration` and `-setExposureDuration:`, but those are the duration in use, and nothing on
the release states a bound the device would accept.

**Capture-input and settings members (4 rows).** `-[AVCaptureMovieFileOutput
supportedOutputSettingsKeysForConnection:]` - 6.1.3's `AVCaptureMovieFileOutput` carries 25 own
instance methods and no settings-keys member at all, and the only class of the family that carries one
is `AVCaptureVideoDataOutput`, whose `+supportedVideoSettingsKeys` is a class method of its own;
`AVCaptureDeviceInput.unifiedAutoExposureDefaultsEnabled` - 6.1.3's `AVCaptureDeviceInput` carries 15 own
instance methods (`-device`, `-ports`, `-setDevice:`, `-initWithDevice:error:` among them) and the
exposure vocabulary is on the device;
`AVCapturePhotoFileDataRepresentationCustomizer`, a protocol, is not among the 16 AV-named protocols in
the 6.1.3 armv7 cache and neither is it on 4.3 or on 7.0; and
`-[AVMutableCompositionTrack addTrackAssociationToTrack:type:]` with its
`removeTrackAssociationToTrack:type:` is written up in its own row, because it is the one row of this
slice that looks like the easiest forward in the whole queue and is not.

## Why the track-association pair is absent and not implemented

`AVTrackAssociationType` is a real enumeration on this release: first-rung answers **6.0** for
`_AVTrackAssociationTypeTimecode`, so the `type:` argument has a value to carry. What it does not have
is the other half of the pair. 6.1.3's `AVMutableCompositionTrack` carries 19 own instance methods and
no association member, its superclass `AVCompositionTrack` carries 6, and the reader for an
association - `-[AVAssetTrack associatedTracksOfType:]` - is 7.0: the deleted class-scoped row reader
reads it INHERITED at 7.0 and ABSENT at 6.1.3, which is the row
`-[AVAssetTrack associatedTracksOfType:]` in this same registry file already says. A pair that stores
what it is given and can never read it back is a value with no reader, which is the thing this file is
not allowed to ship.

## What was not verified here

No band build and no 6.1.3 gate was run; the only build this worktree may run is the light guard, which
is green. The object was compiled on its own with the shared `llvm` package's clang at
`-target armv7-apple-ios6.0 -isysroot` the 16.4 SDK with the flags `modules/apple/backports.lua`'s
`compile_arguments` uses. Whether a band links it is not verified.