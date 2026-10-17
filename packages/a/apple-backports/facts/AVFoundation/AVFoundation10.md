# The release-10 absent rows of `absent_AVFoundation.json`, read class by class

> **Correction (2026-10-03).** Of "the three that land" below, `-playImmediatelyAtRate:` and
> `-[AVPlayerItemVideoOutput initWithOutputSettings:]` were already carried by `AVFoundation100.m`
> (facts/AVFoundation/AVFoundation100.md), so `AVFoundation10.m` defined both a second time. They are
> `AVFoundation100.m`'s alone now, and `AVFoundation10.m` carries `-[AVPlayer timeControlStatus]` only.
> The stricter key handling this page describes for `-initWithOutputSettings:` (raising on an empty
> dictionary, a codec key or an unknown key) is therefore not what runs; `AVFoundation100.m` maps the
> four pixel-buffer keys and ignores the rest.

The 36 rows of `absent_AVFoundation.json` whose `introduced` is 10.0, 10.2 or 10.3. Every one of them is
a member of a class the release carries, or a class or protocol the release does not carry at all, so the
question each row asks is not "does a name exist anywhere" but "does THIS class have THIS member at the
release the port runs on". Three of the 36 answer YES and are implemented in `AVFoundation10.m`; the
other 33 are `absent` with the measurement below; one is a queue entry, named at the end.

## The two rungs, and the reader that certifies them

Both band ends were read as whole caches with the ladder's own architecture choice
(`dyld.held_ladder({"armv7","armv7s"})`), which picks armv7 for both:

```
CHARON_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.charon/dyld/6.1.3/dyld_shared_cache_armv7
CHARON_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.charon/dyld/4.3/dyld_shared_cache_armv7
```

Both through `coordination/heavy.sh`. Output, and the control that makes a zero mean something:

| release | cache | classes | protocols | selectors read |
| --- | --- | --- | --- | --- |
| 6.1.3 armv7 | `dyld_shared_cache_armv7` | 11378 | 1171 | 188523 |
| 4.3 armv7 | `dyld_shared_cache_armv7` | 7187 | 564 | 112851 |

**The control, and a reader that failed it.** A first pass at this page's own table returned zero for
EVERY name, including `isFocusModeSupported:` and `availableVideoCodecTypes`, both of which are visibly
present in the same two dumps. The table had compared a bare name against selector strings that carry
their `-` or `+`. A census in which no rung finds anything is a broken reader, not an absence, and a row
may not be written from it; the table below is the second pass, and its positive controls are the
measurements themselves:

| probe | 6.1.3 owners | 4.3 owners |
| --- | --- | --- |
| `play` | 21 classes, `AVPlayer` among them | 14 classes, `AVPlayer` among them |
| `setRate:` | 9 classes, `AVPlayer` among them | 5 classes, `AVPlayer` among them |
| `isPlaybackLikelyToKeepUp` | `AVPlayerItem` | `AVPlayerItem` |
| `isFocusModeSupported:` | `AVCaptureDevice`, `AVCaptureFigVideoDevice` | same two |
| `availableVideoCodecTypes` | `AVCaptureVideoDataOutput` | `AVCaptureVideoDataOutput` |
| `initWithPixelBufferAttributes:` | `AVPlayerItemVideoOutput` | (class absent) |

A nonsense name is the negative control of the other ladder: `ZZZNonexistentAVFControlName` reads NONE,
and so do the four selectors the SDK declares but no held release exports
(`lockingFocusWithCustomLensPositionSupported`, `lockingWhiteBalanceWithCustomDeviceGainsSupported`, and
both `AVAssetCacheIsPlayAllAssetsOfflineKey` spellings).

The version each name was published in is the registry's own source, not the caches:

```
grep -F -m3 NAME coordination/corpus/sdk-26.2-surface.tsv
```

which is 145301 rows and carries `introduced` for every row below. The first held rung that carries a
NAME is a different question and a different tool:

```
xmake l tools/cache-index/first-rung.lua NAME...
```

which answers PRESENCE over the held set (dense to 12.0, then a hole at 13.0, 14.0 and 15.0, so a 13.0
name answers 16.0). Every `first-rung 10.x` figure quoted below is that answer.

## What a selector's rung does not say

Measured twice in this family, and both times it moved a row:

- **`availableVideoCodecTypes` reads 4.3, and it is not the row's.** The row is
  `AVCaptureMovieFileOutput.availableVideoCodecTypes`. The 4.3 owner is `AVCaptureVideoDataOutput`, and
  so is the 6.1.3 owner - the movie file output carries no codec query of its own on either end. A
  first-rung answer alone would have written this row down as answerable.
- **`overallDurationHint` reads 9.0, and it is not the row's either.** 6.1.3's `AVAsset` carries no such
  member; the name belongs to another class in a 9.x cache. The SDK declares the row at 10.2, and the
  class-scoped read is what settles it.
- **`colorPrimaries` reads 6.0.** No class on 6.1.3 carries `colorPrimaries`, `colorTransferFunction` or
  `colorYCbCrMatrix` at all (0 of 11378), so the 6.0 rung is a class that has since lost them, not an
  owner either release still has.

## The three that land, and what the release gives them

| row | release carries | on 4.3 |
| --- | --- | --- |
| `-[AVPlayer playImmediatelyAtRate:]` | `rate`, `setRate:`, `play`, `pause`, `prerollAtRate:completionHandler:` and no stalling gate at all | same, so the object is carried from 6.0 and 4.3 reads its absence |
| `AVPlayer.timeControlStatus` | `currentItem`, `rate`, and `AVPlayerItem`'s `isPlaybackLikelyToKeepUp` and `isPlaybackBufferEmpty` | same |
| `-[AVPlayerItemVideoOutput initWithOutputSettings:]` | `initWithPixelBufferAttributes:` on `AVPlayerItemVideoOutput` | **the class is absent on 4.3** |

The third is why this object's `minimum` is 6.0 and not lower: 4.3 has no `AVPlayerItemVideoOutput` to
carry the initializer on, while the other two would place at 4.3. The registry's placement record is the
`minimum` of the rows the object carries, and all three rows read 6.0.

**The gate cannot see this object.** All three are category methods, so `nm -gU` over the object defines
no API symbol and `tools/release-split.lua` checks zero symbols and reports it clean vacuously -
`tools/release-split.lua`'s own header names this blind spot and says a clean run does not cover any
category file. What the class-scoped ladder says instead: `playImmediatelyAtRate:`,
`timeControlStatus` and `initWithOutputSettings:` first export at **10.0.1** (first-rung.lua), so all
three belong to one release and one object, which is the property the script is there to protect.

## The 33 that stay absent, and what each is measured against

Every claim below is a member list read from the 6.1.3 armv7 cache. The 4.3 column names the differences
that matter for placement.

### AVAsset and AVAssetCache

6.1.3's `AVAssetCache` carries, in full: `URL`, `allKeys`, `currentSize`, `maxEntrySize`, `maxSize`,
`sizeOfEntryForKey:`, `removeEntryForKey:`, `setMaxEntrySize:`, `setMaxSize:`, `initWithURL:` and
`+assetCacheWithURL:`. There is no offline playback machinery on it at all - no `isPlayAllAssetsOffline`,
no `canPlayAsset:`, no `loadAssetAsynchronouslyForURL:options:completionHandler:` - and no media
selection, so `mediaSelectionOptionsInMediaSelectionGroup:` has no group in the cache to answer from,
although `AVAsset` itself does answer `mediaSelectionGroupForMediaCharacteristic:` (measured, 6.1.3 only;
4.3's AVAsset does not). `AVAsset` carries `duration`, `isPlayable`, `tracks`,
`availableMediaCharacteristicsWithMediaSelectionOptions:` and a readonly duration, and nothing that takes
a duration hint.

### AVPlayer and AVPlayerItem

- `automaticallyWaitsToMinimizeStalling`: there is no switch. 6.1.3's `AVPlayer` exposes its rate
  through `rate`/`setRate:`/`play`/`pause`/`prerollAtRate:completionHandler:` and its buffering through
  the item's `isPlaybackLikelyToKeepUp`, and a setter could only store a value nothing reads.
- `reasonForWaitingToPlay`: the release has no stalling state to report, and the three values the
  property returns are `NSString` constants - `AVPlayerWaitingToMinimizeStallsReason`,
  `AVPlayerWaitingWithNoItemToPlayReason`, `AVPlayerWaitingWhileEvaluatingBufferingRateReason` - that NO
  held release exports (first-rung NONE for each `_`-prefixed symbol). A caller that names one of them
  cannot link them, so there is nothing to return that a caller can compare against.
- `preferredForwardBufferDuration`: 6.1.3's `AVPlayerItem` carries `limitReadAhead`/`setLimitReadAhead:`
  and the older `bufferingTargetMaximum`/`setBufferingTargetMaximum:` (0 owners on 4.3). Neither is
  declared by any header this tree compiles against - the 16.4 header asks for
  `preferredForwardBufferDuration` and has no word for either - so forwarding to them would be a private
  call into the release. `limitReadAhead` is what a caller has instead, and it is named in the row.
- `AVPlayerItemAccessLogEvent`: 6.1.3's carries `indicatedBitrate`, `observedBitrate`, `numberOfStalls`,
  `numberOfBytesTransferred`, `numberOfSegmentsDownloaded`, `numberOfDroppedVideoFrames`,
  `numberOfMediaRequests`, `numberOfServerAddressChanges`, `segmentsDownloadedDuration`, `durationWatched`,
  `playbackSessionID`, `playbackStartDate`, `playbackStartOffset`, `serverAddress` and `URI`. It carries
  no `segments` - there is no `AVPlayerItemAccessLogEventSegment` class on 6.1.3 (0 of 11378) - and no
  audio/video split of the transferred bytes. So there is no segment list to average over and no per-track
  byte count to average, which is the whole content of `averageAudioBitrate`, `averageVideoBitrate` and
  `indicatedAverageBitrate`. The release's own `observedBitrate` and `indicatedBitrate` are single
  figures, not averages over anything.

### AVVideoComposition and AVMutableVideoComposition

6.1.3's `AVVideoComposition` carries `frameDuration`, `renderSize`, `renderScale`, `animationTool`,
`instructions`, `compositor`, their setters, and `isValidForAsset:timeRange:validationDelegate:`. The
mutable subclass adds only `setFrameDuration:`, `setRenderSize:`, `setRenderScale:`, `setAnimationTool:`
and `setInstructions:`. No colour atom is carried, and the compositor the release builds from that
composition reads none, so a colour tag stored on either object would be answered back to the caller and
never applied to a single pixel - which is a stub, and a stub is not a landing state. The 6.0 rung's
`colorPrimaries` is not an owner (see above), and `_CMFormatDescriptionKey_ColorPrimaries` reads NONE.

### AVCaptureDevice, AVCaptureDeviceFormat, AVCaptureSession, AVCaptureMovieFileOutput

- There is **no `AVCaptureColorSpace` class** on 6.1.3 (0 of 11378), and so no colour space for
  `activeColorSpace`, `supportedColorSpaces` or
  `automaticallyConfiguresCaptureDeviceForWideColor` to name. 6.1.3's `AVCaptureSession` has exactly one
  automatic-configuration member, `automaticallyConfiguresApplicationAudioSession`, which is a different
  thing.
- `AVCaptureDevice` has **no lens-position lock and no device-gain lock**: no
  `lockFocusWithCustomLensPosition:`, no `setFocusModeLockedWithLensPosition:completionHandler:`, no
  `lockWhiteBalanceWithDeviceWhiteBalanceGains:`, no
  `setWhiteBalanceModeLockedWithDeviceWhiteBalanceGains:completionHandler:` (0 owners on both ends). It
  does have `isFocusModeSupported:` and `isWhiteBalanceModeSupported:`, which answer the older question
  about the locked mode - a different question, and answering this row from it would be a plausible wrong
  number. Both `locking...Supported` names read NONE across the whole held ladder.
- `AVCaptureMovieFileOutput` carries neither per-connection settings nor `movieFileOutputSettings`
  (0 owners on both ends); its only public recording entry point is
  `startRecordingToOutputFileURL:recordingDelegate:`, which takes no settings. `outputSettingsForConnection:`
  first exports at 7.0. `availableVideoCodecTypes` is `AVCaptureVideoDataOutput`'s (above).

### AVCapturePhotoBracketSettings and AVCapturePhotoCaptureDelegate

6.1.3 carries no `AVCapturePhoto*` class and no `AVCapturePhoto*` protocol under any name (0 of 11378
classes, 0 of 1171 protocols) - the genuine gap the port's own `AVCapturePhotoOutput` was written into.
A bracket's content is a set of exposure settings, and 6.1.3's `AVCaptureDevice` carries neither
`supportedExposureDurationRanges` nor `lockExposureForCustomDuration:customISO:completionHandler:`, so the
set a bracket needs has nothing to be computed from. The protocol: the port's own facts page
(`facts/AVFoundation/AVCapturePhotoOutput.md`, "Open") records that it deliberately delivers the pre-11
`...didFinishProcessingPhotoSampleBuffer:...` callback and does not implement the `AVCapturePhoto` one
that would make `AVCapturePhotoCaptureDelegate` a protocol the port carries.

### The content-key family

`AVContentKeyRecipient`, `AVContentKeySession`, `AVContentKeySessionDelegate`, `AVContentKeyRequest`,
`AVContentKeyResponse` and `AVPersistableContentKeyRequest`: 0 of 11378 classes and 0 of 1171 protocols
on 6.1.3, and the same on 4.3. A content key session is the SPC/CKC exchange with Apple's key server plus
CKC parsing and per-asset key delivery, and no band end carries any of it - 6.1.3's `AVURLAsset` has no
content-key member either, which is what `mayRequireContentKeysForMediaDataProcessing` would report, and
it does have `AVAssetResourceLoader`, which is only the transport a custom scheme's requests arrive on.
`AVContentKeySessionDelegate` first exports at 12.0, not 10.3.

## The one row this batch did not touch

`AVPlayerLooper` is a queue entry, and its row's reason is left as it stands because the honest answer
cannot be written from this slice. The substrate is present and measured: 6.1.3 carries `AVQueuePlayer`
with `items`, `insertItem:afterItem:`, `removeAllItems` and `initWithItems:`, and
`_AVPlayerItemDidPlayToEndTimeNotification` first exports at **4.0**, so a looper is buildable here. But
`check_registry` reads `found.members` from `carried_api()`, which counts every selector of every class
the port's binaries declare and filters only names beginning with `Charon` - so a port-defined
`AVPlayerLooper` brings `-initWithPlayer:queueItems:`, `player`, `queueItems` and `disableLooping` with it,
each of which needs a registry row of its own. Those four rows are not in this batch's slice, and the
slice's rule is that rows outside it are not edited. So the class lands with a batch that owns its four
member rows, and this page is where that queue entry is recorded.
