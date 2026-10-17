# iOS 8's AVFoundation on a release that arrived before it: the 64 rows, read three ways

The 64 rows of `absent_AVFoundation.json` that `API_AVAILABLE(ios(8.0))` puts at 8.0. Every one of them is
a member of a class the release already carries, or of a class the release does not have at all, so each
row's question is "does THIS class have THIS member on the release the port runs on".

## The queue file for this slice has no rows in it

`coordination/corpus/queue/avfoundation-8_0.tsv` is 73 lines: 70 of them the rulebook header and three
blank. Its row list is empty, so "73 rows" is the file's line count and the slice is the registry's own —
`introduced` 8.0 and `status` absent, in `absent_AVFoundation.json` — which is **64 rows** over 20 owners
(38 property, 21 method, 5 class). Nothing here was taken from the queue file's row list, because it has
none; the row list came out of the file this band owns.

## Three readers, and what each answers

| reader | the question | command |
| --- | --- | --- |
| the deleted class-scoped row reader | does **OWNER** carry the member, own table or through a superclass | `xmake l tools/corpus/objc-inventory.lua <cache>` then the tool |
| `objc.lua`'s `known_selectors` file | is the **name** in the release's whole selector set at all | `~/.charon/dyld/6.1.3/selectors_armv7.txt`, 113 981 names |
| `tools/cache-index/first-rung.lua` | which **held release** first carries the name | `first-rung.lua NAME` |

All three ran over these 64 rows. The class-scoped reader is the one the registry's own
`carried_by_release` asks, so it decides; the other two are the check that it is not alone in its answer.

## The ladder, with all three controls answered per release

| release | CARRIED | INHERITED | ABSENT | NO CLASS | NO PROTOCOL |
| --- | --- | --- | --- | --- | --- |
| **6.1.3 armv7** (the floor) | **0** | **0** | **55** | **9** | 0 |
| 8.0 armv7 | 63 | 0 | 0 | 1 | 0 |
| 8.0 armv7s | 63 | 0 | 0 | 1 | 0 |
| 12.0 arm64 (the far end) | 64 | 0 | 0 | 0 | 0 |

**The brief's expectation was wrong and the measurement says so: 6.1.3 carries none of the 64.** Not "not
many" — none. 55 sit on a class that is there and does not have the member, and 9 name a class or protocol
the release has never heard of. So no row can be `ignored` (the release carries none, at either band end),
and `absent` is the honest end unless a row has a substrate to be built on. Each row below names the
substrate it does or does not have.

**Eight of the 64 have since been built**, and this page's reading of the ladder is what they were built
from: `AVFoundation/AVAssetWriterInputMultiPass8.m` carries the writer input's multi-pass family, the
`AVAssetWriterInputPassDescription` class and the export session's half of the same mechanism, as a
single-pass input - a shape `AVAssetWriterInput.h:477` says an input is in when `canPerformMultiplePasses`
is NO. 55 of the 64 stay `absent` (2 were already `implemented` before this, so the file now holds 10
`implemented` rows at 8.0 out of 65 - the 64 plus the class's own `-sourceTimeRanges`). What that object
answers, what Apple's own class answers for the same questions on this machine, and the one row where the
two differ are in [`WriterInputMultiPass8.md`](WriterInputMultiPass8.md).

## The three readers agreeing is the point, and here is what it caught

Of the **129 selector names** these 64 rows ask for, exactly **6** are in 6.1.3's entire 113 981-name
selector set: `error`, `metadata`, `status`, `setError:`, `setMetadata:`, `setStatus:`. All six are
generic, and every one of them belongs to a different class on the release:

| name | classes on 6.1.3 whose OWN table carries it | the row it would have got wrong |
| --- | --- | --- |
| `-status` | 104 | `AVSampleBufferDisplayLayer.status` — ABSENT |
| `-error` | 87 | `AVSampleBufferDisplayLayer.error` — ABSENT |
| `-metadata` | 32 | `AVAsset.metadata`, `AVAssetTrack.metadata` — ABSENT |

So a name-level check would have called four of these rows carried, and the gate's own
`carried_by_release` is class-scoped, so `absent` on them is what it will read as correct. This is
`fileSystemRepresentation` and `init` a third time, in the release rather than in a header.

## One row the release contradicts, and it is not the annotation being late

63 of the 64 are on their owner at 8.0. The sixty-fourth is

    -[AVPlayerItemMetadataOutputPushDelegate metadataOutput:didOutputTimedMetadataGroups:fromPlayerItemTrack:]

`AVPlayerItemMetadataOutput` **is** a class at 8.0, with 14 own instance selectors. The protocol that
declares this method is not: at 8.0 and 8.0 armv7s no class and no protocol declares that selector, and
the protocol itself first appears as a declared protocol at **12.0** (where `MPCModelGenericAVItem`
declares the same selector). The name is registered earlier — `first-rung.lua` answers 8.0 for the
selector and **11.0** for `AVPlayerItemMetadataOutputPushDelegate` — and the header says
`API_AVAILABLE(macos(10.10), ios(8.0), tvos(9.0), watchos(1.0))` at `AVPlayerItemOutput.h:552`.

So the annotation is **early**, not late, and that is the direction that must not be "corrected": the
row's `introduced` is what the SDK's availability gives, and moving it to 12.0 would tell the generator's rule to
lower the availability of a member the port carries from its own floor. The row keeps 8.0 and says here
what the release actually has.

## What each owner carries at 6.1.3 where 8.0 has the row

Own selectors, each from its own release's class line. This is the substrate, and it is what every row's
`effect` names as what a caller gets instead.

| owner | 6.1.3 | the substrate, measured |
| --- | --- | --- |
| `AVCaptureDevice` | 100 own instance, 5 own class | `-isHDRSupported`, `-exposureDuration`/`-setExposureDuration:`, `-exposureMode`/`-isExposureModeSupported:`, `-whiteBalanceMode`/`-whiteBalanceTemperature`/`-setWhiteBalanceTemperature:`, `-lockForConfiguration:`, `-autoExposureBias`. **No** ISO, no lens member, no exposure-target member, no device white balance gains. |
| `AVAssetWriterInput` | 52 own instance, 5 own class | `-requestMediaDataWhenReadyOnQueue:usingBlock:`, `-appendSampleBuffer:`, `-markAsFinished`, `-mediaType`, `-sourceFormatHint`, `-transform`. The whole multi-pass family is 8.0's. |
| `AVCaptureDeviceFormat` | 11 own instance, 3 own class | `-formatDescription`, `-videoSupportedFrameRateRanges`, `-supportedStabilizationMethod`, `-supportsLowLightBoost`, `-isBinned`, `-hasBinned`. No ISO, no exposure range, no HDR, no still-image dimensions. |
| `AVCaptureStillImageOutput` | 33 own instance, 5 own class | `-captureStillImageAsynchronouslyFromConnection:completionHandler:`, `-isRawCaptureSupported`/`-setRawCaptureEnabled:`, `-isEV0CaptureEnabled`/`-setEV0CaptureEnabled:`, `-isHDRSupported` is 8.0's here. Bracketing and high-resolution are 8.0's. |
| `AVSampleBufferDisplayLayer` | 20 own instance, 0 own class | `-enqueueSampleBuffer:`, `-flush`, `-failed`, `-readyForDisplay`, `-controlTimebaseOfLayer:`, `-videoGravity`. `status`/`error` and the private `-_setStatus:error:` are 8.0's. |
| `AVAssetTrack` | 52 own instance, 2 own class | `-hasMediaType:`, `-isPlayable`, `-nominalFrameRate`, `-naturalSize`, `-segments`, and privately `-_hasMultipleNonEmptyEdits`/`-_hasMultipleEdits`/`-_firstReferencedTrackWithReferenceType:`. `metadata` and `requiresFrameReordering` are 8.0's. |
| `AVAsset` | 65 own instance, 2 own class | `-duration`, `-tracks`, `-tracksWithMediaType:`, `-chapterMetadataGroupsWithTitleLocale:containingItemsWithCommonKeys:`. `metadata` is 8.0's. |
| `AVAssetReaderOutput` | 25 own instance, 1 own class | `-addTrack:outputSettings:`, `-removeAllTracks`, `-copyNextSampleBuffer`, `-tracks`, `-mediaType`, `-alwaysCopiesSampleData`. Random access and `markConfigurationAsFinal` are 8.0's. |
| `AVAssetExportSession` | 54 own instance, 23 own class | `-metadata`, `-determineCompatibleFileTypes`, `-exportAsynchronouslyWithCompletionHandler:`, `-estimatedOutputFileLength`. Temp directory and multi-pass are 8.0's. |
| `AVAssetWriter` | 35 own instance, 6 own class | `-addInput:`, `-startWriting`, `-finishWriting`, `-inputForMediaType:`, `-startSessionAtSourceTime:`. |
| `AVCaptureVideoPreviewLayer` | 54 own instance, 2 own class | `-session`, `-connection`, `-pointForCaptureDevicePointOfInterest:`, `-captureDevicePointOfInterestForPoint:`. The no-connection pair is 8.0's. |
| `AVMediaSelectionGroup` | 18 own instance, 6 own class | `-options`, `-allowsEmptySelection`, `-defaultOption` is 8.0's; the release's selection state lives on AVPlayerItem. |
| `AVPlayerItem` | 237 own instance, 35 own class | `-duration`, `-status`, `-tracks`, `-videoComposition`, `-audioMix`, `-forwardPlaybackEndTime`. `preferredPeakBitRate` and the bitrate family are 8.0's. |
| `AVAssetResourceLoaderDelegate` | **no protocol and no class** | the whole protocol is 8.0's; `AVAssetResourceLoader` itself is on the release but the delegate protocol is not |
| `AVPlayerItemMetadataOutput`, `AVAssetReaderOutputMetadataAdaptor`, `AVAssetReaderSampleReferenceOutput`, `AVAssetWriterInputMetadataAdaptor`, `AVAssetWriterInputPassDescription` | **no class** | 8.0's, and each is the class a whole pipeline hangs off: a timed-metadata output, a reader adaptor, a sample-reference output, a writer adaptor, and one encoding pass |

## Reproducing

    CHARON_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.charon/dyld/6.1.3/dyld_shared_cache_armv7 \
        > 6.1.3.armv7.inventory.tsv
    CHARON_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.charon/dyld/8.0/dyld_shared_cache_armv7 \
        > 8.0.armv7.inventory.tsv
    CHARON_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.charon/dyld/12.0/dyld_shared_cache_arm64 \
        > 12.0.arm64.inventory.tsv
    # the removed class-scoped row read, arguments: <rows.tsv> \
        6.1.3-armv7=6.1.3.armv7.inventory.tsv 8.0-armv7=8.0.armv7.inventory.tsv \
        8.0-armv7s=8.0.armv7s.inventory.tsv 12.0-arm64=12.0.arm64.inventory.tsv

Twelve controls, three per release; the tool writes no row unless all twelve answer.