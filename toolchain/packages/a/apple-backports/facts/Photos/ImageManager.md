# The image manager of Photos, iOS 8.0

`PHImageManager` asks an asset for an image, for its data or for a video. iOS 6 has all of it in the
`ALAssetRepresentation` of the asset: a thumbnail, a full-screen image, the full-resolution image and the
bytes. The manager chooses among them, as the release makes the asset available, and draws from them
what was asked.

## An image

`-requestImageForAsset:targetSize:contentMode:options:resultHandler:` takes the smallest of the thumbnail, the full-screen
image and the full-resolution image that is at least as large as what is drawn, orients it, and draws it to the size the
content mode asks for: fitted inside the target size or filling it, never larger than the asset unless the resize mode is
exact. `PHImageManagerMaximumSize` gives the full-resolution image. The exact resize mode with the fill mode, or with a
`normalizedCropRect`, gives an image of exactly the target size, cropped; the exact mode with the fit mode gives the
fitted size, as the aspect ratio has to hold.

The handler is called once, with an image that is not degraded: the opportunistic delivery of iOS 8 may call it more
than once and needs to call it only once. An asynchronous request is answered on the main thread, a synchronous one
(`synchronous` set) on the calling thread. `info` has the request identifier and
`PHImageResultIsInCloudKey` NO, `PHImageResultIsDegradedKey` NO, and `PHImageErrorKey` when the image could not
be read. `-cancelImageRequest:` before the answer makes the handler be called with no image and
`PHImageCancelledKey` YES.

## Data and video

`-requestImageDataForAsset:options:resultHandler:` gives the bytes of the default representation with its
uniform type identifier and orientation; `-requestImageDataAndOrientationForAsset:options:resultHandler:` the same
with the orientation of ImageIO. `-requestAVAssetForVideo:options:resultHandler:`,
`-requestPlayerItemForVideo:options:resultHandler:` and `-requestExportSessionForVideo:options:exportPreset:resultHandler:`
build an `AVURLAsset` on the address of the video, an item of it and an export session of it, with no audio mix. A request for
an asset that is not a video answers no object and an error.

The options that need iCloud, the progress handler, the version (there is one version of an asset), the delivery mode and the video delivery mode
change nothing here. Live photos are absent. `PHCachingImageManager` starts and stops caching as a hint and keeps no cache; the images it gives
are those of the manager.

Source: the header of iOS 16.4; `tools/corpus/cache-value.lua` over the arm64e cache of 16.0 for the
constants, read out of the device's own `Photos.framework`: `PHImageManagerMaximumSize` is -1 by -1 and
each of the five keys is a string equal to its own name (the same run, and the same tool, that read the
eight keys of the families this port does not carry -- `facts/Photos/Constants.md`); the defaults of the
options; an iPad 2 running 6.1.3.
