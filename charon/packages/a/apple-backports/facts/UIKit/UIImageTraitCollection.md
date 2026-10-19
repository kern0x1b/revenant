# UIImage.traitCollection, iOS 8

Introduced in iOS 8.0: the traits an image was made for, which an image in an asset catalogue is chosen by.

Source: the host's own UIKit under Mac Catalyst (`host/imagetraits/run.sh`): the image of a bitmap context at scales 1, 2 and 3, an image made by
`imageWithCGImage:scale:orientation:` and a resizable image answer a trait collection that has the display scale of the image and nothing else - no idiom
(unspecified), no size classes, no style; two images of one scale answer equal collections. `device/imagetraits.m` holds iOS 6 to them.

The port answers `+traitCollectionWithDisplayScale:` of the image's `scale`. The image's own catalogue variants - the idiom, the size class, the dark
variant of an image in an asset catalogue - are not there to report on iOS 6, which reads no compiled catalogue for images.
