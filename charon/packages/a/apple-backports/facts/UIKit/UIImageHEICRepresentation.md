# `UIImageHEICRepresentation()`, iOS 17

`UIImageHEICRepresentation(UIKit/UIImageHEICRepresentation17.m)` asks for an image's HEIC
representation. The function is not in the 6.1.3 cache, so no release of the port's architecture
carries it; what decides the answer is the release's own ImageIO, and that is measured on the 6.1.3
cache directly.

## What the release can write

iOS 6.1.3's ImageIO exports `CGImageDestinationCopyTypeIdentifiers` and
`CGImageDestinationCreateWithData` - both read out of the release's own symbol table through
`tools/corpus/cache-value.lua`, which names ImageIO.framework as the image that exports each. So the
release can say what it writes.

The strings the release's cache holds are the types it knows. Measured with a byte search of
`$HOME/.charon/dyld/6.1.3/dyld_shared_cache_armv7`:

| string | occurrences in the 6.1.3 cache |
| --- | --- |
| `public.jpeg` | 15 |
| `public.png` | 15 |
| `public.tiff` | 6 |
| `com.compuserve.gif` | 4 |
| `public.heic` | 0 |
| `public.heif` | 0 |
| `kUTTypeHEIC` | 0 |
| `kUTTypeHEIF` | 0 |
| `com.apple.heic` | 0 |
| `image/heic` | 0 |

The four types it names are the four it writes; not one of the six spellings of HEIC or HEIF is
anywhere in the release. An ImageIO destination created for a type the release does not know is
NULL, and this is the return that follows from that.

## The implementation

A real encode through the release's own ImageIO, not a stub: the image's `CGImage` goes into a
`CGImageDestination` created for the HEIC type by its uniform type identifier, and the data is
finalized. On every release this object is kept for - iOS 6 to 10.3.6, the bands below 11.0, since
from 11.0 on the release exports the function and the object is reexported instead - the
destination cannot be created and the answer is nil.

The header's contract is nil for an image that cannot be represented in HEIC
(`UIImage.h:374`, `NSData * __nullable`). A release that cannot write HEIC cannot represent anything
in it, so nil is what the release's own behaviour would be, not a placeholder for a behaviour that
was left out.

An image with no `CGImage` behind it (a `CIImage`-only image, as `UIImage` has carried since iOS
5) has nothing for ImageIO to encode and answers nil for the same reason.
