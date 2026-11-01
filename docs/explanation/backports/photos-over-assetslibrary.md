# Photos over AssetsLibrary: Telegram's use and where the backport stands

The backport exists: `frameworks/Backports/src/Photos` maps PhotoKit to AssetsLibrary, and
`docs/reference/backports/Photos/README.md` describes its design. This page checks that design against Telegram
13.0.0. It says what the source files show, not what a device run would show, and it records each gap's status.

Method: word counts over the reference checkout (`~/Git/reference/Telegram-iOS-release-13.0.0`, Swift, Objective-C
and headers). A word count includes comments and identifiers, so it measures reach, not calls. Each class was then
matched to its file in `src/Photos`.

## What Telegram uses

| Symbol | Words | Backport file | How it maps |
| --- | --- | --- | --- |
| PHAsset | 104 | PHAsset8.m | 1:1 over ALAsset. Identity is `ALAssetPropertyAssetURL`; media type and creation date are ALAsset properties. |
| PHAssetCollection | 53 | PHCollection8.m | ALAssetsGroup by type. Saved photos is the user library. The Videos smart album filters by type. Other smart albums are not handled (G2). |
| PHImageManager | 40 | PHImageManager8.m | Native over ALAssetRepresentation: `aspectRatioThumbnail`, `fullScreenImage`, `fullResolutionImage`. Aspect-fill cropping is drawn natively (`revenant_image`). |
| PHFetchResult | 36 | PHFetchResult8.m | Native: a snapshot of the group, with the predicate, sort and fetch limit applied. |
| PHFetchOptions | 12 | PHFetchOptions8.m | Native, as above. |
| PHImageRequestOptions, PHVideoRequestOptions, PHImageRequestID, PHImageManagerMaximumSize | 28, 14, 15, 15 | PHImageManager8.m | Native request bookkeeping. `cancelImageRequest` stops a request that has not been delivered. |
| PHCachingImageManager | 5 | PHImageManager8.m | Native prefetch through the same request path, with a 12 MiB LRU cache (RevenantPhotosImageCache.m). |
| PHPhotoLibrary, PHAuthorizationStatus | 27, 8 | PHPhotoLibrary.m | 1:1 over `ALAssetsLibrary authorizationStatus` (PHPhotoLibrary.m:12, 30–38). `.limited` is never produced. |
| PHPhotoLibraryChangeObserver | 2 | PHPhotoLibraryChangeObserver8.m | `ALAssetsLibraryChangedNotification`, turned into a native diff. |
| PHChange, changeDetails(for:) | 5, 26 | PHChange8.m | Native diff: insertions, removals, changes and moves are implemented (G1). |
| PHAssetResource, PHAssetResourceManager | 13, 2 | PHAssetResource9.m, PHAssetResourceManager9.m | Bytes from the default representation. `locallyAvailable` reports whether that representation exists. |
| PHAssetCreationRequest (`placeholderForCreatedAsset`) | 6 | PHAssetCreationRequest9.m | The write APIs are 1:1. The placeholder is resolved after the write completes, which is native. |
| PHAssetChangeRequest, PHAssetCollectionChangeRequest | 6, 3 | PHAssetChangeRequest8.m, PHAssetCollectionChangeRequest8.m | Album add is 1:1 with `ALAssetsGroup addAsset:` (header line 75). Deletion, favorites and hidden state are refused with a change error. |
| PHLivePhoto, PHLivePhotoRequestOptions | 3, 6 | PHImageManager8.m, PHAssetResource9.m | Refused with `PHPhotosErrorRequestNotSupportedForAsset`: Live Photo needs iOS 9.1. |
| PHPickerViewController, PHPickerResult, PHPickerConfiguration | 4, 3, 2 | PHPickerViewController14.m, PHPickerViewController16.m, PHPickerResult14.m, PHPickerConfiguration14.m | The iOS 14+ picker classes are in the backport. The one Telegram site read (MediaPickerScreen.swift:3968) sits behind `#available(iOS 14.0, *)`. |

Every class in this table has a backport file. The check is by file, not by member: a member missing from a file
would not show here.

## What maps one to one

- Authorization: `ALAssetsLibrary authorizationStatus` has the same four states as the old PHAuthorizationStatus
  (`ALAuthorizationStatus` is deprecated at iOS 6, so it exists on iOS 6; the SDK header says so).
- Identity: `ALAssetPropertyAssetURL` is the iOS 6 counterpart of `localIdentifier`. The header's deprecation note
  points at this mapping. Telegram persists `localIdentifier` as a resource key and fetches it again with
  `fetchAssets(withLocalIdentifiers:)` (LocalMediaResources `FetchPhotoLibraryImageResource.swift:107, 241`), so the
  round trip must hold.
- Album edits: `addAsset:` on `ALAssetsGroup` (the header marks it deprecated at 5, so it exists on iOS 6).
- Writes: `writeImageDataToSavedPhotosAlbum:metadata:completionBlock:` and `writeVideoAtPathToSavedPhotosAlbum:completionBlock:`.
- Representations: `aspectRatioThumbnail`, `fullScreenImage`, `fullResolutionImage` and `getBytes:fromOffset:length:error:`.

## What needs a native implementation

- Image size selection: the smallest representation that meets the requested size, then a native render when a crop
  or an exact size is asked for.
- Fetch results: a snapshot that is filtered, sorted and limited by the backport, because AssetsLibrary only filters
  by photos, videos or all.
- Change details: a diff of identifier snapshots. `ALAssetsLibraryChangedNotification` reports updated assets, and
  inserted or deleted assets only as an invalidated group (header line 137), so the diff does the rest.
- Placeholders: `placeholderForCreatedAsset` returns an object before its identifier exists, and the identifier is
  filled in when the write completes.
- Image cache: a native 12 MiB LRU, cleared on memory warnings.

## Gaps against Telegram's use

- G1, moves (T13 in `backports-gaps.md`): implemented. `PHChange8.m:166–181` finds the longest increasing
  subsequence of the surviving items' before indexes (`RevenantPhotoMoves.c`). Each surviving item outside it is a move,
  and `hasMoves` and `enumerateMovesWithBlock:` (`PHChange8.m:235–244`) report it as (from, to). The helper is host-tested
  by `frameworks/Backports/tests/Photos/photo_moves_test.m` (2005 checks, 0 failures). Telegram reads moves at
  `LegacyComponents/Sources/TGMediaAssetFetchResultChange.m:42–47`. The glue has not run against a library on a device.
- G2, smart-album subtypes: decided, not derived. The backport returns the user library and Videos only (`PHCollection8.m`,
  lines 75, 102–111, 144, 166–168). `TGMediaAssetGroup.m` switches on Favorites and Screenshots (lines 140, 155, 192, 249).
  AssetsLibrary cannot supply either: `ALAssetsGroupType` has six group types (Library, Album, Event, Faces, SavedPhotos,
  PhotoStream) and no favorite or screenshot member, `ALAssetsGroup` has no property for either, and the AssetsLibrary
  headers in the iPhoneOS 26.2 SDK contain neither word. A fetch for those subtypes returns an empty result, not a
  stand-in collection (`revenant_collectionsWithType:subtype:`). An empty album that is present would be a fake unless a
  device without favorites returns one. That has not been checked on the iPhone 4S, and the iOS 6 SDK headers were not
  found locally, so the enum comes from the 26.2 SDK, which marks it deprecated from iOS 4.
- G3, PhotosUI: open. `MediaPickerScreen.swift:14` imports `PhotosUI`, which is not in `src/Photos`. Bazel pass 35 did not
  reach `MediaPickerUI`: `TelegramCore` failed first on `Reachability.swift` (`NWPathMonitor`, from the uninstalled
  `revenant@network` package), so this stays open until a pass compiles `MediaPickerUI` with that package installed.
- G4, identifier stability: the mapping must give the same identifier across launches and reinstalls, or persisted
  `localIdentifier` keys break. The header supports the mapping but says nothing about stability. Check on a device.
- G5, prompting: `requestAuthorization` reads the status (PHPhotoLibrary.m:35–38). Whether a prompt appears on a device is
  not verified; the README's runtime test fails on the emulator before that point.

## Status

G1 is implemented and host-tested. G2 is decided: no collection for Favorites or Screenshots, because
AssetsLibrary has neither. G3 is open until a Bazel pass compiles `MediaPickerUI`. G4 and G5 need a device run. This
survey changes no Photos code.
