# UIGraphicsImageRenderer

Introduced in iOS 10.0. Draws into a bitmap and answers a `UIImage`, PNG or JPEG.

Source: UIKit of the armv7s cache of iOS 10.3.4.

| member | behaviour |
|---|---|
| `-init` | `-initWithSize:` with `CGSizeZero`. |
| `-initWithSize:` | `-initWithSize:format:` with `[UIGraphicsImageRendererFormat defaultFormat]`. |
| `-initWithSize:format:` | `[super initWithBounds:format:]` with the size as a rectangle at the origin. |
| `-initWithBounds:` | `-initWithBounds:format:` with the image format's default. |
| `-allowsImageOutput` | `YES`. |
| `+rendererContextClass` | `UIGraphicsImageRendererContext`. |
| `-pushContext:` / `-popContext:` | always push and pop, the flag the base class consults is not read. |

## The bitmap

`+contextWithFormat:` makes the context, and every one of these is a fact off the
binary rather than a reasonable guess:

| what | value |
|---|---|
| width, height | `ceilf(scale * bounds.size.width)` and the same for the height, as `size_t`. A width or a height of 0 gives **no context at all**, and `NULL` is returned. |
| bits per component | 8 |
| bytes per row | `CGBitmapGetAlignedBytesPerRow(width * 4)` - private to CoreGraphics, exported by every release from 3.1.3 to 10.3.4 |
| colour space | `CGColorSpaceCreateWithName(kCGColorSpaceSRGB)`, made once and kept forever |
| bitmap info | `0x2002` = `kCGBitmapByteOrder32Little \| kCGImageAlphaPremultipliedFirst`, or `0x2006` = `... \| kCGImageAlphaNoneSkipFirst` when the format is opaque |

**The colour space is sRGB, not device RGB.** `CGColorSpaceCreateDeviceRGB` is
what anyone would write here and it is wrong in a way that shows: an image out of
a device RGB context carries no colour profile, so its PNG is 12 bytes shorter
than the one UIKit makes and its JPEG likewise. With sRGB every byte of both
matches. The differential test holds this.

**Where the release cannot make sRGB, device RGB.** On an iPhone4,1 running
6.1.3, `CGColorSpaceCreateWithName(kCGColorSpaceSRGB)` answers `NULL`: the
constant is exported, but CoreGraphics makes no space of it and a context asked
for with none is refused (`unsupported parameter combination ... 0-component
color space`). There the renderer draws in `CGColorSpaceCreateDeviceRGB()`,
which is what the release's own UIKit draws an image context in
(`UIGraphicsBeginImageContextWithOptions` of 6.0, `0x32ce23ec`). The pixels are
the same; the PNG and JPEG carry no colour profile, as every image UIKit itself
makes on that release does.

`+prepareCGContext:withRendererContext:` then, in order:
`CGContextClearRect` over the whole bitmap, `CGContextTranslateCTM(0, height)`,
`CGContextScaleCTM(scale, -scale)` - which flips the y axis - and
`CGContextTranslateCTM(-bounds.origin.x, -bounds.origin.y)`.

## An empty answer, never nil

When the context cannot be made - a renderer of no size - the drawing block does
**not** run: `-runDrawingActions:completionActions:format:error:` (`0x205e03f6`)
answers NO with `NSCocoaErrorDomain` 0, `Could not create CGContextRef`, before
either block, and the newest UIKit does the same. The three drawing methods then
answer an **empty object rather than nil**:

- `-imageWithActions:` answers `[[UIImage alloc] init]`, a `UIImage` of size zero;
- `-PNGDataWithActions:` and `-JPEGDataWithCompressionQuality:actions:` answer
  `[[NSData alloc] init]`, of length zero.

This is worth stating plainly because the documentation reads as though nil were
possible: an application that guards with `if (image)` walks straight on and
fails later, on its own code, with an image of no size. Charon answers the same
empty objects.
