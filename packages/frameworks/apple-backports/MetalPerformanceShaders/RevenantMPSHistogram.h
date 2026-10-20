#pragma once
#import "RevenantMPS.h"
#import "RevenantMPSImage.h"

static inline void RevenantMPSHistogramRegion(id<MTLTexture> source, MTLRegion read, MPSImageHistogramInfo info,
                                     vector_float4 threshold, uint32_t *out, NSUInteger channels,
                                     BOOL histogramForAlpha, NSString *what)
{
    NSUInteger bins = info.numberOfHistogramEntries;
    if (!bins) {
        RevenantMPSRefuse(@"%@: %lu histogram entries is no histogram, so nothing was written", what,
                        (unsigned long)bins);
        return;
    }
    double lo = info.minPixelValue.x, hi = info.maxPixelValue.x;
    if (!(hi > lo)) {
        RevenantMPSRefuse(@"%@: the range %g..%g is empty, so nothing was written", what, lo, hi);
        return;
    }
    MTLRegion inside = read;
    if (inside.origin.x < 0) inside.origin.x = 0;
    if (inside.origin.y < 0) inside.origin.y = 0;
    if (inside.origin.x + inside.size.width > source.width) inside.size.width = source.width - inside.origin.x;
    if (inside.origin.y + inside.size.height > source.height) inside.size.height = source.height - inside.origin.y;
    if (inside.size.width == 0 || inside.size.height == 0) {
        RevenantMPSRefuse(@"%@: the window intersects the %lux%lu source to nothing, so nothing was written",
                        what, (unsigned long)source.width, (unsigned long)source.height);
        return;
    }
    size_t bytes = (size_t)inside.size.width * 4 * inside.size.height * 4;
    unsigned char *pixels = malloc(bytes);
    if (!pixels) {
        RevenantMPSRefuse(@"%@: no memory for a %lux%lu window, so nothing was written", what,
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
                    continue;
                double value = (double)p[c] / 255.0;
                if (value < (double)threshold[c])
                    continue;
                if (value < lo || value > hi)
                    continue;
                NSUInteger bin = (NSUInteger)((value - lo) / (hi - lo) * (double)bins);
                if (bin >= bins)
                    bin = bins - 1;
                out[c * bins + bin] += 1;
            }
        }
    }
    free(pixels);
}
