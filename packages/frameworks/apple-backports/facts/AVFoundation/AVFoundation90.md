# iOS 9's AVFoundation rows on 6.1.3: the 27 that `absent_AVFoundation.json` places at 9.0 and 9.3

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
    $HOME/Git/projects/ios/coordination/corpus/queue/SLICE-AVFoundation-absent_AVFoundation-9.tsv \
    6.1.3=.agent-work/runs/wav/inv-6.1.3.tsv 4.3=.agent-work/runs/wav/inv-4.3.tsv \
    7.0=.agent-work/runs/wav/inv-7.0.tsv
```

Its three controls, on all three releases, from the first nine lines of that run's output:
`-[AVPlayerItem duration]` CARRIED, `-[AVPlayerItem aSelectorNoFrameworkHas]` ABSENT,
`-[AVCompositionTrack mediaType]` INHERITED - all three as wanted on 6.1.3, on 4.3 and on 7.0.

Every row of the slice reads ABSENT or NO CLASS or NO PROTOCOL on 6.1.3, so none of the 27 is the
release's own.

## What this slice carries

Two rows, and they are one pair: `AVComposition.URLAssetInitializationOptions` and
`+[AVMutableComposition compositionWithURLAssetInitializationOptions:]`.

The options dictionary is what `AVComposition.h` documents for `+[AVURLAsset URLAssetWithURL:options:]`,
and 6.1.3 has that factory: `AVURLAsset` carries `-initWithURL:options:` among its 37 own instance
methods and `+URLAssetWithURL:options:` among its 7 own class methods. What the release's `AVComposition`
does not carry is a place to remember them - 6 own instance methods, `-naturalSize`, `-duration`,
`-tracks`, `-trackGroups`, `-copyWithZone:` and `-dealloc` among them, and none of them for this - so
the port keeps the dictionary on the composition and the factory sets it.

## The 25 absent rows, in five families

**The two CIFilter composition factories.** `-customVideoCompositorClass` is
`API_AVAILABLE(ios(7.0))` (`AVVideoComposition.h:89`), so the compositor these two hand a filter
handler to has no entry point on this release; 6.1.3's `AVVideoComposition` carries 26 own instance
methods and 3 own class methods, and none of the three names a class that renders a frame. The 16.0
pair in this registry file is blocked on the same thing and is written up there.

**Fragmentation (3 rows).** `AVAsset.canContainFragments` and `AVAsset.containsFragments` need a
fragment table; 6.1.3's `AVAsset` carries 65 own instance methods whose only members that speak of
container composition are `-isComposable` and `-referenceRestrictions`, and neither reads a fragment
table. `AVComposition.URLAssetInitializationOptions`'s neighbour `AVAsset.preferredMediaSelection`
needs an `AVMediaSelection`, and 6.1.3 has none: its family is `AVMediaSelectionGroup`,
`AVMediaSelectionOption`, `AVMediaSelectionTrackOption`, `AVMediaSelectionTrackGroup`,
`AVMediaSelectionKeyValueGroup`, `AVMediaSelectionKeyValueOption` and the two `...Internal` classes -
eight, and `AVMediaSelection` is not one of them. `AVPlayerItem.currentMediaSelection` is blocked on
the same missing class.

**HLS offlining (3 rows).** `AVAssetDownloadTask`, `AVAssetDownloadURLSession` and
`AVAssetDownloadDelegate`: first-rung answers NONE for the class names, for `_AVAssetDownloadDelegate`
and for `_NSURLSession`, which is what a download URL session would be built on. `AVAsset.compatibleWithAirPlayVideo`
is the same shape from the other side - it asks whether an asset is fit for AirPlay video, and 6.1.3's
`AVAsset` has no member that would answer it while `AVPlayer` has its own, `-allowsAirPlayVideo`, which
is a different class asking about the player. `AVRouteDetector` is the awkward one in this family and
is written up in its own row: 6.1.3's `AVAudioSession` *does* carry
`-overrideOutputAudioPort:error:` among its 64 own instance methods, so a caller can choose a route,
and what this release has no member for is the report of which route the user chose.

**Content keys and metadata (4 rows).** `-[AVAssetResourceLoadingRequest
persistentContentKeyFromKeyVendorResponse:options:error:]` - 6.1.3's `AVAssetResourceLoadingRequest`
carries 11 own instance methods and its content-key member is the private
`-streamingContentKeyRequestDataForApp:contentIdentifier:options:error:`, which *asks* the system for a
request rather than turning a vendor response into a key.
`AVAssetResourceLoader.preloadsEligibleContentKeys` - the loader carries 13 own instance methods
(`-asset`, `-delegate`, `-setDelegate:queue:` and the rest) and no preload flag, and the protocol it
would preload for, `AVAsynchronousKeyValueLoading`, declares no member for it.
`AVAsynchronousCIImageFilteringRequest` - CoreImage *is* on this release, and that is the awkward one:
the request's option key is what is missing. `first-rung` answers **NONE** for
`_AVAsynchronousCIImageFilteringRequestKeyFilterChain`, so the filter chain the request is built from
has no name on this release and the port would have to export it, which is not a row of this slice.
`AVCaptureMetadataInput` - 6.1.3's `AVCaptureSession` carries 84 own instance methods whose input
classes are the ones `-inputWithClass:` can find, and there is no metadata input among them.

**The 9.3 media data collectors (5 rows).** `AVPlayerItemMediaDataCollector`,
`AVPlayerItemMetadataCollector`, `-[AVPlayerItem addMediaDataCollector:]`,
`-[AVPlayerItem removeMediaDataCollector:]` and `AVPlayerItem.mediaDataCollectors`. First-rung answers
NONE for `_AVPlayerItemMediaDataCollector`, and the deleted class-scoped row reader answers NO CLASS on
6.1.3, 4.3 and 7.0. The member rows are absent for the same reason and no further: this release has no
collector to collect.

## The three that look like forwards and are not

- `AVPlayerLayer.pixelBufferAttributes` - 6.1.3's `AVPlayerLayer` carries 37 own instance methods
  (`-player`, `-setPlayer:`, `-videoGravity`, `-isReadyForDisplay`, `-videoRect` among them) and no
  pixel-buffer member; on this release the pixel buffer an output wants is asked of the item's output,
  `-[AVPlayerItemVideoOutput initWithPixelBufferAttributes:]`.
- `AVCaptureStillImageOutput.lensStabilizationDuringBracketedCaptureEnabled` and
  `.lensStabilizationDuringBracketedCaptureSupported` - 6.1.3's `AVCaptureStillImageOutput` carries 33
  own instance methods (`-captureStillImageAsynchronouslyFromConnection:completionHandler:`,
  `-isHDRCaptureEnabled`, `-isRawCaptureEnabled`, `-isEV0CaptureEnabled` and the rest) and neither lens
  member; its bracketing-free capture is the release's own and this release has no lens-stabilization
  vocabulary on any class.
- `-[AVCaptureMovieFileOutput recordsVideoOrientationAndMirroringChangesAsMetadataTrackForConnection:]`
  and its setter - 6.1.3's `AVCaptureMovieFileOutput` carries 25 own instance methods and neither
  member. Storing the flag would be a value with no reader, which is the same reason the 12.0
  track-association pair is absent rather than carried: the orientation on this release is a connection
  property, `-[AVCaptureConnection setVideoOrientation:]`, and the recorder applies it itself.

## What was not verified here

No band build and no 6.1.3 gate was run; the only build this worktree may run is the light guard, which
is green. The object was compiled on its own with the shared `llvm` package's clang at
`-target armv7-apple-ios6.0 -isysroot` the 16.4 SDK with the flags `modules/apple/backports.lua`'s
`compile_arguments` uses. Whether a band links it is not verified.