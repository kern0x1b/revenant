# iOS 14's AVFoundation rows on 6.1.3: the 29 that `absent_AVFoundation.json` places at 14.0 and 14.5

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
    $HOME/Git/projects/ios/coordination/corpus/queue/SLICE-AVFoundation-absent_AVFoundation-14.tsv \
    6.1.3=.agent-work/runs/wav/inv-6.1.3.tsv 4.3=.agent-work/runs/wav/inv-4.3.tsv \
    7.0=.agent-work/runs/wav/inv-7.0.tsv
```

Its three controls, on all three releases, from the first nine lines of that run's output:
`-[AVPlayerItem duration]` CARRIED, `-[AVPlayerItem aSelectorNoFrameworkHas]` ABSENT,
`-[AVCompositionTrack mediaType]` INHERITED - all three as wanted on 6.1.3, on 4.3 and on 7.0.

Every row of the slice reads ABSENT or NO CLASS or NO PROTOCOL on 6.1.3, so none of the 29 is the
release's own.

## What this slice carries, and why it is one row

`AVAssetWriter.preferredOutputSegmentInterval`, and only that. `AVAssetWriter.h:601` says its default is
`kCMTimeInvalid` "which means that the receiver will choose an appropriate default value", and
`AVAssetWriter.h:692` says a positive numeric value is what makes the writer emit a segment every
interval. 6.1.3's `AVAssetWriter` carries `-movieFragmentInterval` and `-setMovieFragmentInterval:`
among its 35 own instance methods, and that is the release's only segment-duration member -
`-startSessionAtSourceTime:` and `-endSessionAtSourceTime:` are the session boundaries and the interval
is what divides them. So the port applies a positive numeric value there and leaves `kCMTimeInvalid`
and `kCMTimeIndefinite` alone, the second because the method that would consume it, `-flushSegment`, is
14.0's and this release has no segments to flush. `kCMTimeInvalid` reads **4.0** in
`first-rung.lua`, so the symbol the default needs is one the release has.

**There is no object for the 14.5 half of this slice.** Every one of its eleven rows is blocked on
substrate no band end carries: seven on centre-stage hardware and its vocabulary, two on the
FairPlay content-key classes, one on `AVAssetVariant` and one on the display layer's external
protection state. Proving that absence at both ends with a certified control is the whole of that
half, and `absent` is the honest end for it - there is no object in this slice's slice to write, and
building one anyway would have shipped a symbol nothing exports.

## The segmented writer, and why its five members are all absent

`-[AVAssetWriter flushSegment]`, `-[AVAssetWriter initWithContentType:]`, `AVAssetWriter.delegate`,
`AVAssetWriter.initialSegmentStartTime`, `AVAssetWriter.outputFileTypeProfile`,
`AVAssetWriter.producesCombinableFragments` and `AVAssetWriterDelegate` are one feature: a writer that
emits segments and hands them to a delegate. 6.1.3's `AVAssetWriter` carries 35 own instance methods -
`-addInput:`, `-canAddInput:`, `-startWriting`, `-finishWriting`, `-finishWritingWithCompletionHandler:`,
`-endSessionAtSourceTime:`, `-startSessionAtSourceTime:`, `-movieFragmentInterval`, `-movieTimeScale`,
`-metadata`, `-outputFileType`, `-outputURL` and the rest - and no delegate, no segment report and no
fragment sequence number. Two of these have their own reason worth writing down:

- `-initWithContentType:` takes a `UTType` and this release's own
  `+[AVAssetWriter assetWriterWithURL:fileType:error:]` takes a four-character `AVFileType`
  (`AVFileTypeMPEG4` and `AVFileTypeQuickTimeMovie` both read **4.0**). The UniformTypeIdentifiers
  vocabulary this row's argument is made of does not exist here: first-rung answers **16.0** for
  `_UTTypeMPEG4Movie` and for `_UTTypeQuickTimeMovie`, so there is not even a name to map from.
- `AVAssetWriterDelegate` is a protocol, and it is not among the 16 AV-named protocols in the 6.1.3
  armv7 cache, nor on 4.3, nor on 7.0.

## The centre-stage rows, and the two 4.3 NO CLASS answers

`AVCaptureDevice.centerStageActive`, `.centerStageControlMode`, `.centerStageEnabled`,
`AVCaptureDeviceFormat.centerStageSupported`, `.videoFrameRateRangeForCenterStage`,
`.videoMaxZoomFactorForCenterStage`, `.videoMinZoomFactorForCenterStage`,
`AVCaptureDeviceFormat` reads NO CLASS on 4.3, and `AVSampleBufferDisplayLayer` reads NO CLASS on 4.3
too, because 4.3's armv7 cache has neither. On 6.1.3, `AVCaptureDevice`'s 100 own instance methods and
`AVCaptureDeviceFormat`'s 11 carry no centre-stage member and no zoom member of any kind, and
`AVSampleBufferDisplayLayer`'s 20 own instance methods are `-enqueueSampleBuffer:`, `-flush`,
`-flushAndRemoveImage`, `-isReadyForMoreMediaData`, `-requestMediaDataWhenReadyOnQueue:usingBlock:`,
`-stopRequestingMediaData`, `-controlTimebase`, `-setControlTimebase:` and `-videoGravity` among them -
neither an external-protection state nor a "must be flushed to resume" state.

## The rest

`AVCaptureDevice.manufacturer` - 6.1.3's `AVCaptureDevice` has `-localizedName`, `-modelID`,
`-uniqueID`, `-position`, `-deviceType` and `-formats`, and no member that names the maker;
`-modelID` is a model identifier and not a manufacturer. `AVCaptureDevice.suspended` - no member of the
release reports that, and the one interruption member is on the session, `-isInterrupted`.
`AVPlayerItem.startsOnFirstEligibleVariant` and `AVPlayerItem.variantPreferences` - the variant
vocabulary, first-rung answers **NONE** for `_AVAssetVariant`, is not on this release at all.
`AVPlayerItem.appliesPerFrameHDRDisplayMetadata` and `AVPlayerItem.allowedAudioSpatializationFormats` -
6.1.3's `AVPlayerItem` carries 237 own instance methods and no HDR-metadata member and no spatialization
member; `-[AVCaptureDevice isHDRSupported]` is on the capture side and is a different class.

## What was not verified here

No band build and no 6.1.3 gate was run; the only build this worktree may run is the light guard, which
is green. The object was compiled on its own with the shared `llvm` package's clang at
`-target armv7-apple-ios6.0 -isysroot` the 16.4 SDK with the flags `modules/apple/backports.lua`'s
`compile_arguments` uses. Whether a band links it is not verified.