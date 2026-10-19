# UIImage imageByPreparingForDisplay, iOS 15

Source: the SDK 16.4 header of `UIImage.h`, which documents the method as decoding the image's
compressed data ahead of time and handing back a new `UIImage` backed by that decode, so that
later drawing does not pay for decompression; and iOS 6.1.3's own `CGBitmapContextCreate` /
`CGContextDrawImage`, which already do exactly that decode-into-a-bitmap step for any other
purpose a caller asks for it.

## What the port does

Draws the receiver's `CGImage` once into a freshly allocated 8-bit-per-channel ARGB bitmap
context, then reads a new `CGImage` back out of that context with `CGBitmapContextCreateImage`.
Core Graphics has no choice but to fully decode the source image to satisfy the draw, so the
image handed back is backed by raw, already-decoded pixels: drawing it again does not touch the
original compressed source. The new `UIImage` carries the receiver's scale, orientation,
`capInsets`, `alignmentRectInsets`, `renderingMode` and Charon's own baseline association
forward, the same way `UIImage+iOS13.m`'s `charon_image_copy` does for other image-returning
methods in this port. Multi-frame (`images.count > 0`) images are returned unchanged: forcing a
decode of every frame is not this method's contract on the real release either (the header does
not promise it touches animation), and re-encoding an animated image's frame sequence through a
single bitmap context would drop the animation.

## What was reasoned, not measured

No device or emulator run backs this file. The claim that `CGContextDrawImage` forces a full
decode of a compressed source (JPEG/PNG-backed `CGImage`) rather than deferring it again is
Core Graphics' documented behaviour, not something this band watched happen on the 4S or the
iPad 2 - there is no user-visible difference to check for (the API is a performance hint, and its
contract does not promise or forbid any particular before/after timing an external observer
could measure without an internal decode counter). `respondsToSelector:` was not run either.

## The asynchronous form and the thumbnail, iOS 15

`UIKit/UIImage+iOS15.m`:

- `-prepareForDisplayWithCompletionHandler:` runs `imageByPreparingForDisplay` on a global queue and hands its result to the handler
  there. The header does not name the queue the system calls back on; a background one is what the port picked. A nil handler does
  nothing rather than crash.
- `-imageByPreparingThumbnailOfSize:` draws the image, orientation applied, into a bitmap context of exactly the size asked at scale 1,
  so the thumbnail's `size` in points is its size in pixels and its scale is 1; a fractional size is rounded up and a size that is not
  positive answers nil, as does an image with neither a `CGImage` nor a `CIImage`. The image is stretched to fill the size: the port
  does not keep the aspect ratio. Scale 1 and the stretch are what the port chose, following how the method is commonly described as
  behaving; neither was measured against the system, and the header says only "a new thumbnail image at the specified size".
- `-prepareThumbnailOfSize:completionHandler:` is the thumbnail on a global queue, as the display preparation is.

Ladder by `objc.inventory` (`.agent-work/plan-and-analysis/b1314-flips/ladder-image.log`, an invented selector as the negative control): all
three are not in `UIImage`'s methods in 6.1.3 or 12.0 and are in 16.0 and 18.0, with `imageByPreparingForDisplay`; there is no 13-15
cache, so `introduced` stays the header's 15.0. Run on a device: the last section.

## On a device, iOS 6.1.3

On an iPad 2 of iOS 6.1.3 (2026-09-23), a process of the band's own (`.agent-work/runs/b1314-live/main.m`, output `run4-all.txt` beside it) loaded the gate's `libUIKitBackports.dylib` and checked the thumbnail (10 by 10 pixels at scale 1, nil for a size that is not positive) and both asynchronous forms, called off the main thread with an image of the right width; all as described.
