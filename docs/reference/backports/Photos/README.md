# Photos on iOS 6

PhotosBackports maps the PhotoKit asset and image APIs used by Telegram 13.0.0 to AssetsLibrary.

Authorization uses ALAssetsLibrary.authorizationStatus; library changes use ALAssetsLibraryChangedNotification.
Asset and collection fetches map saved photos, iTunes imports, albums, events, faces, and Photo Stream groups to
PHAsset, PHAssetCollection, and PHFetchResult. PHFetchOptions applies its predicate, sort descriptors, and fetch
limit to the fetched objects.

Image requests select the smallest available representation that meets the requested pixel size: aspectRatioThumbnail,
then fullScreenImage, then fullResolutionImage when the request exceeds the screen representation or asks for the
maximum size. A finite thumbnail request does not touch fullResolutionImage when a smaller representation is adequate.
requestImageData reads the selected asset representation in chunks. PHCachingImageManager prefetches through the same
request path and shares a 12 MiB least-recently-used decoded-image cache with PHImageManager; memory warnings clear it.

PHAssetResource exposes the default AssetsLibrary representation and reports whether that representation exists through
the locallyAvailable key used by Telegram. An iCloud-only Photo Stream asset cannot be downloaded by AssetsLibrary on
iOS 6. Image, image-data, video, and resource-data requests return an error when the local representation is absent.
The Photos change APIs refuse unsupported edits with a change error, including asset deletion, favorites, hidden state,
and asset metadata changes that AssetsLibrary cannot perform. Resource creation accepts one primary photo or video;
adjustment data and Live Photo pairings are unavailable.

requestLivePhotoForAsset fails with PHPhotosErrorRequestNotSupportedForAsset: a Live Photo needs iOS 9.1. cancelImageRequest
stops delivery of a request that has not yet been delivered, and the result carries PHImageCancelledKey.

The host tests cover representation selection and the cache's byte limit, eviction order, oversized objects and recency
on a hit. The iPhone 4S runtime test creates and fetches a photo, checks its local-availability result, requests a
thumbnail, and verifies a change observer can refetch its result. It is not run by CI. On the emulator it fails at the
first step: the guest never contacts assetsd, so AssetsLibrary grants no access and the test reports that. Its
thumbnail timing is not measured until that is fixed.
