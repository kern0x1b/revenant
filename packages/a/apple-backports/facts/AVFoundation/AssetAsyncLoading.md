# The asynchronous loading API of iOS 15, on the asset classes the port carries

`packages/a/apple-backports/AVFoundation/AVAssetAsyncLoading15.m`, 18 methods on five classes:
`-[AVAsset loadTracksWithMediaType:completionHandler:]`, `loadTrackWithTrackID:completionHandler:`,
`loadTracksWithMediaCharacteristic:completionHandler:`, `findUnusedTrackIDWithCompletionHandler:`,
`loadMetadataForFormat:completionHandler:`, `loadMediaSelectionGroupForMediaCharacteristic:completionHandler:`,
`loadChapterMetadataGroupsBestMatchingPreferredLanguages:completionHandler:`,
`loadChapterMetadataGroupsWithTitleLocale:containingItemsWithCommonKeys:completionHandler:`,
`-[AVAssetTrack loadMetadataForFormat:completionHandler:]`,
`loadSamplePresentationTimeForTrackTime:completionHandler:`, `loadSegmentForTrackTime:completionHandler:`,
`-[AVComposition loadTrackWithTrackID:completionHandler:]`,
`loadTracksWithMediaCharacteristic:completionHandler:`, `loadTracksWithMediaType:completionHandler:`, the
same three again on `-[AVMutableComposition ...]`, and
`-[AVURLAsset findCompatibleTrackForCompositionTrack:completionHandler:]`.

## The cause, and why this is one object

15.0 split each synchronous accessor into a `load...` that takes a completion handler and does its work
off the calling thread. The accessors themselves stayed. This release never had the split and already
has every accessor the split is built from, so one method here is: the release's own accessor, its
answer handed to the caller's block.

That is also why this is one `.m` for release 15 and not one per class. The eighteen methods are one
API arriving in one release, and each depends on an accessor whose own first rung differs
(`tracksWithMediaType:` at 4.0, `chapterMetadataGroupsWithTitleLocale:containingItemsWithCommonKeys:` at
4.3, `mediaSelectionGroupForMediaCharacteristic:` at 5.0, `chapterMetadataGroupsBestMatchingPreferredLanguages:`
at 6.0) - so a split by substrate would have put four releases in one file, which `release-split.lua`
and `band()` both refuse. `minimum` on every row is `6.0`, which is the band floor for the package and
not a claim about the accessor.

## The substrate, measured on both band ends

Every accessor below was read class-scoped: `xmake l tools/corpus/objc-inventory.lua <cache>` and the
selector looked up on the class that declares it, not as a name somewhere in the image. The 6.1.3 and
4.3 armv7 caches are the two ends this package deploys on.

| the accessor the method calls | first rung | 6.1.3 | 4.3 |
| --- | --- | --- | --- |
| `-[AVAsset tracksWithMediaType:]` | 4.0 | yes | yes |
| `-[AVAsset trackWithTrackID:]` | 4.0 | yes | yes |
| `-[AVAsset tracksWithMediaCharacteristic:]` | 4.0 | yes | yes |
| `-[AVAsset unusedTrackID]` | 4.0 | yes | yes |
| `-[AVAsset metadataForFormat:]` | 4.0 | yes | yes |
| `-[AVAsset compatibleTrackForCompositionTrack:]` | 4.0 | yes | yes |
| `-[AVAsset mediaSelectionGroupForMediaCharacteristic:]` | 5.0 | yes | **no** |
| `-[AVAsset chapterMetadataGroupsWithTitleLocale:containingItemsWithCommonKeys:]` | 4.3 | yes | yes |
| `-[AVAsset chapterMetadataGroupsBestMatchingPreferredLanguages:]` | 6.0 | yes | **no** |
| `-[AVAssetTrack metadataForFormat:]` | 4.0 | yes | yes |
| `-[AVAssetTrack samplePresentationTimeForTrackTime:]` | 4.0 | yes | yes |
| `-[AVAssetTrack segmentForTrackTime:]` | 4.0 | yes | yes |

First-rung answers come from `xmake l tools/cache-index/first-rung.lua NAME` over the held ladder, and a
selector is spelled **with its colons**: `tracksWithMediaType:` reads 4.0 and the bare
`tracksWithMediaType` reads NONE, because a colon is part of the name and the index is exact. A lookup
that drops it looks like an absence and is not one.

The two `no` cells at 4.3 are why the two methods that need them are still carried for the 6.x band and
are not claimed for 4.3: `-loadMediaSelectionGroupForMediaCharacteristic:completionHandler:` and
`-loadChapterMetadataGroupsBestMatchingPreferredLanguages:completionHandler:` are `minimum` 6.0, and
6.1.3 carries both accessors. The registry row's `minimum` is the placement record
(`backports.lua:2024` `minimums()` reads `entry.minimum` and never `entry.status`), so it is what keeps
these two out of the 4.3 band.

### The control on every run

`xmake l tools/corpus/cache-census.lua AV 6.1.3 4.3` printed, in one run, `images 524, of which naming
AV 16 / classes 11378, of which AV* 301` at 6.1.3 and `images 354, of which naming AV 15 / classes 7187,
of which AV* 231` at 4.3, and closed with
`control: 558 name(s) beginning AV found in this run, so a zero on another rung is the release's and not
the reader's`. A reader that found nothing at either end would have been reported as CONTROL FAILED
rather than as an absence, and no row above is written from such a run.

## Inheritance is the substrate for six of the eighteen

`AVComposition` and `AVURLAsset` are subclasses of `AVAsset` on both band ends
(`objc-inventory.lua` prints the superclass column: `AVComposition → AVAsset`,
`AVMutableComposition → AVComposition`, `AVURLAsset → AVAsset`), and the accessors are declared on
`AVAsset` only. So the six `AVComposition`, `AVMutableComposition` and `AVURLAsset` methods call a
selector the receiver inherits, and dispatch on the receiver's own class: a subclass that overrides
`tracksWithMediaType:` is the one that answers.

The three `-[AVMutableComposition ...]` methods are **declared again** rather than left to inherit from
the `-[AVComposition ...]` category above, and this is the one trap in the file: Objective-C does not
carry a superclass's category methods down. A mutable composition built through
`+[AVMutableComposition composition]` would not answer `loadTracksWithMediaType:completionHandler:`
without them.

## What a caller gets, exactly

- the value is the release's own, from its own accessor - never a placeholder;
- the handler is called **exactly once**, on the main queue, with a nil error. Not with an error
  because the synchronous accessors have no failure of their own to report: `tracksWithMediaType:`
  returns what the asset has, and there is no separate error to hand back. A caller that switches on
  the error will never see one, which is a real difference from 15.0 and is what the rows say;
- the block is **copied before the accessor is called** and the copy is what the main-queue block
  captures. The caller's block is released when the method returns, so calling it after that is a
  use-after-free in the middle of playback;
- **not carried**: `-loadAssociatedTracksOfType:completionHandler:` (its accessor
  `-associatedTracksOfType:` first appears at 7.0, which no band end of this package builds), and the
  cancellation half of the 15.0 contract - there is nothing here to cancel, and `-cancelLoading` is not
  in this slice.

## Why the call goes through `objc_msgSend`, and the two casts that are not the same shape

Each method sends the accessor's real selector through `objc_msgSend` with
`sel_registerName("tracksWithMediaType:")`, not a typed message. The SDK this package compiles against
declares these accessors and not the 15.0 `load...` spelling of them, so a typed message would not
compile and a hand-declared interface would be a second, divergent copy of a signature. The selector
sent is the one the release answers; the header is not asked to agree about it.

**Two of the eighteen are cast to a different function type, and getting that wrong is undefined
behaviour rather than a compile error:**

| accessor | return type | cast used |
| --- | --- | --- |
| `-unusedTrackID` | `CMPersistentTrackID` — a 32-bit integer | `CMPersistentTrackID (*)(id, SEL)` |
| `-samplePresentationTimeForTrackTime:` | `CMTime` — a 24-byte struct | `CMTime (*)(id, SEL, CMTime)` |
| the other sixteen | an object | `id (*)(id, SEL)` |

Casting `-unusedTrackID` to the object-returning shape and reading the result as an `id` reads an
integer as a pointer; casting `-samplePresentationTimeForTrackTime:` to it reads a returned struct
through the wrong return convention entirely, and on armv7 a 24-byte struct comes back through a
hidden sret pointer, so the argument registers shift and the `CMTime` argument is misplaced too. Both
misbehave without trapping, which is why they are called out here rather than left to the reader.

`CMTime` is passed **by value** to `-segmentForTrackTime:` and to the accessor behind it, four
registers wide on armv7 - which is the same reason the accessor call names `CMTime` in its signature
rather than taking an `id`.

## Reproducing the substrate measurement

```
CHARON_ROOT="$PWD" xmake l tools/corpus/objc-inventory.lua ~/.charon/dyld/6.1.3/dyld_shared_cache_armv7 > inv.tsv
CHARON_ROOT="$PWD" xmake l tools/corpus/objc-inventory.lua ~/.charon/dyld/4.3/dyld_shared_cache_armv7   > inv43.tsv
CHARON_ROOT="$PWD" xmake l tools/corpus/cache-census.lua AV 6.1.3 4.3
xmake l tools/cache-index/first-rung.lua 'tracksWithMediaType:' 'unusedTrackID' 'segmentForTrackTime:'
```

The inventory's selector column carries the leading `-`, so a selector is looked up as
`-tracksWithMediaType:` in that file; the class-scoped answer walks the superclass chain, which is what
separates "AVAsset does not declare it" from "no release this port builds declares it".