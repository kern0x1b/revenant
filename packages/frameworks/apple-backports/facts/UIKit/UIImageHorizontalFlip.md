# The image flipped horizontally, iOS 10

Introduced in iOS 10.0: `-[UIImage imageWithHorizontallyFlippedOrientation]`.

Source: UIKit of the armv7s cache of iOS 10.3.4, read method by method, and the host's own UIKit run beside the port
(`host/imageflip`, through Mac Catalyst); the device test `imagescreen.m` holds iOS 6 to the same answers.

The release makes a copy of the image with a private initializer, `_initWithOtherImage:`, and sets the three bits of its
flags that hold the orientation to `+[UIImage _mirroredImageOrientationForOrientation:]` of the orientation it had: the
eight orientations answer `(o + 4) % 8`, so Up becomes UpMirrored, Left becomes LeftMirrored, and the mirrored ones come
back; a number above 7 is answered as it is. The pixels, the size, the scale and the CGImage are the original's.

The port does not set those bits: their place in the object is private and is not the same in every release the band
covers, and a wrong guess would write into another field. It builds the copy from what the image says in public,
the way `-imageWithRenderingMode:` does: a CGImage-backed image is remade with `+imageWithCGImage:scale:orientation:` and
the mirrored orientation, a Core Image one with `+imageWithCIImage:scale:orientation:`, an animated one with
`+animatedImageWithImages:duration:`; then the cap insets and resizing mode, the alignment insets and the rendering mode
are put back. Against the host's own UIKit on the eight orientations, a resizable image, one with alignment insets, a
template image, all of them at once, an animated image and a Core Image one, the answers agree on orientation, size,
scale, pixels, insets, resizing mode, rendering mode, frame count and duration, and the result is another image.

Where it differs: an image that holds no pixels, no frames and no Core Image data is answered as itself, and so keeps
its orientation, where the release answers a copy that says it is mirrored; nothing can be drawn from either. State the
release keeps in private and offers no way to read is not carried to the copy.
