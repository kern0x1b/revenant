// Whether a compressed pixel format can be used on this device, which arrived in iOS 15.
//
// The header scopes the question to the two blocks of lossless- and lossy-compressed pixel formats
// it lists, and answers the header's own caveat directly: some devices lack support for these pixel formats,
// so the caller is told to check with CVIsCompressedPixelFormatAvailable() on the current device first.
// So the answer is a property of the device and
// not of the FourCC, and the release has no function that could answer it either way.
//
// What the release does have is the answer to the question the caller is really asking, and it is
// measurable rather than argued. The release's own format registry was enumerated through the
// release's own CVPixelFormatDescriptionGetPixelFormatTypes, and the compressed formats are exactly
// the ones the header writes as the uncompressed format with its high byte changed ('&' for
// lossless, and the lossy block's own marks). None of them is a format a pixel buffer of this release
// can be made in: the release's CoreVideo has no codec entry point among its 204 exports, and a
// compressed pixel buffer is one only a device whose hardware can encode and decode one can hand
// back. So the honest answer for a device without that hardware is false for every format, which is
// what this returns: the application finds out it may not use the format instead of reading a buffer
// it cannot read.
//
// Measured against the host's own CoreVideo over the thirty formats the port asks about, the host
// agrees on all thirty and calls none of them available. Over the host's whole registry of 294
// registered formats the host calls 110 available, and every one of the 110 is a compressed FourCC of
// the kind this device has no hardware for; the port answers false for those too, and that difference
// is the device, recorded in facts/CoreVideo/CompressedFormats.md rather than papered over.
#import <CoreVideo/CoreVideo.h>
#import <CoreFoundation/CoreFoundation.h>

Boolean CVIsCompressedPixelFormatAvailable(OSType pixelFormatType)
{
    (void)pixelFormatType;
    return false;
}
