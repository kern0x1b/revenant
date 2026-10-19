// The one histogram walk MPSImageHistogram13.m and MPSImageNormalizedHistogram12.m share: two objects because the
// release introduces MPSImageHistogram in iOS 9.0 and MPSImageNormalizedHistogram in iOS 12.0, and an object carries
// one release.
#pragma once
#import "CharonMPS.h"
#import "CharonMPSImage.h"

// One histogram over one window. `out` is the caller's buffer, already the right size - this is told, not
// allocated, because the header's :118 histogramOffset is a byte offset into a buffer the CALLER owns.
static inline void CharonMPSHistogramRegion(id<MTLTexture> source, MTLRegion read, MPSImageHistogramInfo info,
                                     vector_float4 threshold, uint32_t *out, NSUInteger channels,
                                     BOOL histogramForAlpha, NSString *what)
{
    NSUInteger bins = info.numberOfHistogramEntries;
    if (!bins) {
        CharonMPSRefuse(@"%@: %lu histogram entries is no histogram, so nothing was written", what,
                        (unsigned long)bins);
        return;
    }
    double lo = info.minPixelValue.x, hi = info.maxPixelValue.x;
    if (!(hi > lo)) {
        CharonMPSRefuse(@"%@: the range %g..%g is empty, so nothing was written", what, lo, hi);
        return;
    }
    // The read is the clipRectSource window, already intersected with the image by the caller. The bytes
    // come straight out of the texture, because :115's encode takes a texture and not an MPSImage.
    MTLRegion inside = read;
    if (inside.origin.x < 0) inside.origin.x = 0;
    if (inside.origin.y < 0) inside.origin.y = 0;
    if (inside.origin.x + inside.size.width > source.width) inside.size.width = source.width - inside.origin.x;
    if (inside.origin.y + inside.size.height > source.height) inside.size.height = source.height - inside.origin.y;
    if (inside.size.width == 0 || inside.size.height == 0) {
        CharonMPSRefuse(@"%@: the window intersects the %lux%lu source to nothing, so nothing was written",
                        what, (unsigned long)source.width, (unsigned long)source.height);
        return;
    }
    size_t bytes = (size_t)inside.size.width * 4 * inside.size.height * 4;   // RGBA8, the case's format
    unsigned char *pixels = malloc(bytes);
    if (!pixels) {
        CharonMPSRefuse(@"%@: no memory for a %lux%lu window, so nothing was written", what,
                        (unsigned long)inside.size.width, (unsigned long)inside.size.height);
        return;
    }
    [source getBytes:pixels bytesPerRow:inside.size.width * 4
          fromRegion:MTLRegionMake2D(0, 0, inside.size.width, inside.size.height) mipmapLevel:0];

    for (NSUInteger y = 0; y < inside.size.height; y++) {
        for (NSUInteger x = 0; x < inside.size.width; x++) {
            const unsigned char *p = pixels + (y * inside.size.width + x) * 4;
            for (NSUInteger c = 0; c < channels; c++) {
                if (c == 3 && !histogramForAlpha)
                    continue;                        // :208, RGBA with histogramForAlpha false stores RGB only
                double value = (double)p[c] / 255.0;  // the case's source is unorm8
                // :59 - the entry is incremented only if the pixel is at or over the threshold.
                if (value < (double)threshold[c])
                    continue;
                if (value < lo || value > hi)         // minPixelValue / maxPixelValue, :61-66
                    continue;
                // The bin: numberOfHistogramEntries buckets over [minPixelValue, maxPixelValue], and the
                // top of the range is a real bin rather than one past the end.
                NSUInteger bin = (NSUInteger)((value - lo) / (hi - lo) * (double)bins);
                if (bin >= bins)
                    bin = bins - 1;
                out[c * bins + bin] += 1;            // :206-215, channel-major
            }
        }
    }
    free(pixels);
}
