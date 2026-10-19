# Two filter keys of iOS 7 and the SVG type of iOS 8

iOS 7.0 added `kCIInputAngleKey` and `kCIInputRadiusKey` to the names a `CIFilter` takes its input under, and iOS 8.0 added
`kUTTypeScalableVectorGraphics` to the uniform type identifiers.

Source: CoreImage of the arm64 shared cache of iOS 12.0 - `_kCIInputAngleKey` at `0x1b07f6398` and `_kCIInputRadiusKey` at
`0x1b07f6390`, each a constant string, `inputAngle` and `inputRadius`; MobileCoreServices of the same cache -
`_kUTTypeScalableVectorGraphics` at `0x1b61b6380`, the string `public.svg-image`; an iPad 2 and the iOS 6.0 emulator, asked with
`dlsym` for each name, for what iOS 6 exports.

## What it is

Three constant strings. The keys are the ones the filters that have an angle or a radius, the blurs, the twirls and the
rotations, take their values under; the identifier names the format of an SVG image.

## Where iOS 6 differs

iOS 6 exports `kCIInputImageKey` and none of the three names. They are carried with the values above, so that an application that
reads them loads. The filters of iOS 6 read their radius and angle under these strings: on the devices the Gaussian blur lists `inputRadius`
and the straighten filter `inputAngle` among its input keys, which `tests/backports/device/graphicsnames.m` asks. Whether the type
database of the release knows `public.svg-image` was not asked, so `UTTypeConformsTo` and the extension of a file are the
answers of the release, which knows nothing of the identifier unless the release declares it.
