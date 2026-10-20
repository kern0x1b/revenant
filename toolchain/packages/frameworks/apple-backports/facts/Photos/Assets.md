# Assets, collections and fetch results of Photos, iOS 8.0

Photos of iOS 8 reads the photo library through `PHAsset`, `PHAssetCollection`,
`PHCollectionList` and their `PHFetchResult`s. iOS 6 has no Photos database, but it has the
library itself behind `ALAssetsLibrary`, and the classes are carried over that: what
`ALAssetsLibrary` can answer is answered, and what only the database of iOS 8 knows is
not made up.

## How it is read

The library of the release answers on the thread that asked, and to a thread that keeps a
run loop. A fetch is synchronous in Photos, so it is made by a thread of the package that keeps
one, and the caller waits for it. The main thread is never handed a library block to wait
on. Until the application is authorized a fetch answers with an empty result and does not show
the prompt of the release, as Photos does; `+[PHPhotoLibrary requestAuthorization:]` shows it.

## What an asset is

- `localIdentifier` is the address of the asset in the library (`assets-library://asset/...`); the
  identifiers of iOS 8 are opaque and this one is as opaque to an application. An asset just
  created by a change is known by the placeholder's identifier until the change is done, and then by
  this one; both fetch it. See `Changes.md`.
- `mediaType` is image or video from `ALAssetPropertyType`; `pixelWidth`, `pixelHeight`, `creationDate`,
  `location` and `duration` are the properties of the asset and its default representation.
- `hasAdjustments` is true when the asset is the edited version of another one (`originalAsset`).
- `sourceType` is user library for the camera roll, iTunes synced for the synced library, and cloud shared for the photo stream.
- `isFavorite`, `isHidden`, bursts and `representsBurst` are what iOS 6 has none of, so they are NO,
  nil and 0. `mediaSubtypes` is 0: the release does not tell a panorama, a screenshot or a
  slow-motion video from an image or a video. `modificationDate` is nil: the release keeps no such date.
  `canPerformEditOperation:` is NO for every operation, as a change of an asset in the library is refused.

## Fetching

`+fetchAssetsWithOptions:`, `+fetchAssetsWithMediaType:options:`, `+fetchAssetsInAssetCollection:options:` and
`+fetchAssetsWithLocalIdentifiers:options:` return the assets in order of date, then apply the options: the predicate
(an `NSPredicate` on the `PHAsset`, by key-value coding), the sort descriptors and `fetchLimit`. The sources are those of
`includeAssetSourceTypes`, the user library and the synced library when it is 0. `includeHiddenAssets` changes nothing,
as nothing is hidden. `+fetchKeyAssetsInAssetCollection:options:` is absent.

The collections are the albums of the release: regular albums, synced events and faces, the synced library and the
photo stream as albums, and as smart albums the camera roll (user library) and the videos, plus the empty favorites, hidden and bursts, which the
release cannot have. Panoramas, recently added, screenshots, self portraits, time-lapses and the other smart albums of iOS 8 are
not made, as the release cannot tell which assets belong to them, and moments are not made. A collection list is never found:
iOS 6 has no folders of albums. The transient collections are absent.

## PHFetchResult

A fetch result is the objects of the fetch at the moment of the fetch; it does not follow the library after it.
It has the `NSArray`-like calls of the header and fast enumeration, and `-countOfAssetsWithMediaType:`.

Source: the header of iOS 16.4 for the classes and their declarations; the host's Photos for the defaults of `PHFetchOptions` (a change detail request on by default) and the empty
result for an identifier that is not found; an iPad 2 running 6.1.3 for what `ALAssetsLibrary` returns.
