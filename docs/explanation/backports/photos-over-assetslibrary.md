# Photos over AssetsLibrary: Telegram's use and where the backport stands

The backport exists: `frameworks/Backports/src/Photos` maps PhotoKit to AssetsLibrary, and
`docs/reference/backports/Photos/README.md` describes its design. This page checks that design against Telegram
13.0.0. It proposes no change, and it says what the source files show, not what a device run would show.

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
| PHChange, changeDetails(for:) | 5, 26 | PHChange8.m | Native diff: insertions, removals and changes are implemented. Moves are not (G1). |
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

- G1, moves (T13 in `backports-gaps.md`): `hasMoves` is NO and `enumerateMovesWithBlock:` is empty (PHChange8.m:235–240).
  Telegram reads moves at `LegacyComponents/Sources/TGMediaAssetFetchResultChange.m:42–47`, so a reorder is reported as
  a removal and an insertion, or not at all. Fix: detect moves from the identifier order in PHChange8.m.
- G2, smart-album subtypes: PHCollection8.m handles only the user library and Videos (lines 75, 102–111, 144, 168).
  `TGMediaAssetGroup.m` switches on Favorites and Screenshots (lines 140, 155, 192, 249). AssetsLibrary has no
  favorites or screenshots, so the backport can only return an empty collection or an error. That is a decision to make,
  not a fix to make.
- G3, PhotosUI: `MediaPickerScreen.swift:14` imports `PhotosUI`, which is not in `src/Photos`. Whether the armv7
  build resolves it is not yet known; the output of Bazel pass 35 settles it.
- G4, identifier stability: the mapping must give the same identifier across launches and reinstalls, or persisted
  `localIdentifier` keys break. The header supports the mapping but says nothing about stability. Check on a device.
- G5, prompting: `requestAuthorization` reads the status (PHPhotoLibrary.m:35–38). Whether a prompt appears on a device is
  not verified; the README's runtime test fails on the emulator before that point.

## Not implemented

Nothing here is implemented. G1 and G2 need a decision or a change in `src/Photos`; G3 and G4 need the pass 35 output and a
device run.
