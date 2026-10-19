// MPSImageNormalizedHistogram from MPSImageHistogram.h of the iPhoneOS 26.2 surface. The release exports it from iOS 12.0,
// apart from MPSImageHistogram (9.0) in MPSImageHistogram13.m: an object carries one release. The walk is
// CharonMPSHistogramRegion in CharonMPSHistogram.h, shared with that file.

#import "CharonMPSHistogram.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
// As in the reduction, convolution and morphology families, and recorded in the same crutches.md entry.
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

// MPSImageNormalizedHistogram, :145 - ios(9.0), MPSKernel. The same histogram with the range taken from
// the image rather than given: :218 adds a minmaxTexture the per-image minimum and maximum are written
// into, and the bins then run between them. So the range is MEASURED here - one walk for the minimum and
// the maximum, then the same binning - and the min/max are written where :203 says, so a caller can see
// which range produced the counts.
@implementation MPSImageNormalizedHistogram {
    MTLRegion _clipRectSource;
    BOOL _zeroHistogram;
    MPSImageHistogramInfo _histogramInfo;
}

@synthesize clipRectSource = _clipRectSource;
@synthesize zeroHistogram = _zeroHistogram;
@synthesize histogramInfo = _histogramInfo;

- (instancetype)initWithDevice:(id<MTLDevice>)device histogramInfo:(const MPSImageHistogramInfo *)histogramInfo
{
    if ((self = [super initWithDevice:device])) {
        if (!histogramInfo || !histogramInfo->numberOfHistogramEntries) {
            CharonMPSRefuse(@"MPSImageNormalizedHistogram: MPSImageHistogramInfo with %lu entries describes"
                            @" no histogram, so no object was made",
                            (unsigned long)(histogramInfo ? histogramInfo->numberOfHistogramEntries : 0));
            return nil;
        }
        _histogramInfo = *histogramInfo;
        _clipRectSource = MPSRectNoClip;
        _zeroHistogram = YES;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder device:(id<MTLDevice>)device
{
    CharonMPSRefuse(@"MPSImageNormalizedHistogram: -initWithCoder:device: is not carried - the release's"
                    @" keys for a histogram's bins are in no header");
    return nil;
}

- (size_t)histogramSizeForSourceFormat:(MTLPixelFormat)sourceFormat
{
    if (sourceFormat != MTLPixelFormatRGBA8Unorm && sourceFormat != MTLPixelFormatRGBA8Unorm_sRGB)
        return 0;                                  // as above: not this port's format, not guessed
    NSUInteger channels = _histogramInfo.histogramForAlpha ? 4 : 3;
    return (size_t)_histogramInfo.numberOfHistogramEntries * channels * sizeof(uint32_t);
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                sourceTexture:(id<MTLTexture>)source
              minmaxTexture:(id<MTLTexture>)minmax
                     histogram:(id<MTLBuffer>)histogram
              histogramOffset:(NSUInteger)histogramOffset
{
    NSString *what = NSStringFromClass([self class]);
    if (!source || !histogram || !minmax) {
        CharonMPSRefuse(@"%@: a source texture, a minmax texture and a histogram buffer are all required,"
                        @" so nothing was written", what);
        return;
    }
    MTLRegion window = _clipRectSource;
    if (window.size.width < 0 || window.size.height < 0)
        window = MTLRegionMake2D(0, 0, source.width, source.height);
    // Clamp to the texture before reading, the same way CharonMPSHistogramRegion does. A window whose
    // origin is inside but whose size runs past the texture is clamped by the helper; this path reads the
    // window itself, so it must clamp here or it reads past the row and the range comes back empty.
    if (window.origin.x < 0) window.origin.x = 0;
    if (window.origin.y < 0) window.origin.y = 0;
    if (window.origin.x + window.size.width > source.width) window.size.width = source.width - window.origin.x;
    if (window.origin.y + window.size.height > source.height) window.size.height = source.height - window.origin.y;
    if (window.size.width == 0 || window.size.height == 0) {
        CharonMPSRefuse(@"%@: the window intersects the %lux%lu source to nothing, so there is no range to"
                        @" normalize and nothing was written", what, (unsigned long)source.width,
                        (unsigned long)source.height);
        return;
    }

    // The range this histogram normalizes over is the image's own minimum and maximum over the window,
    // so it is measured before anything is binned - and written to minmax, because :203 says the caller
    // is handed it and a range nobody can see is a range nobody can check.
    size_t bytes = (size_t)window.size.width * 4 * window.size.height * 4;
    unsigned char *pixels = malloc(bytes);
    if (!pixels) {
        CharonMPSRefuse(@"%@: no memory for a %lux%lu window, so nothing was written", what,
                        (unsigned long)window.size.width, (unsigned long)window.size.height);
        return;
    }
    [source getBytes:pixels bytesPerRow:window.size.width * 4
          fromRegion:MTLRegionMake2D(0, 0, window.size.width, window.size.height) mipmapLevel:0];
    double lo = 1.0, hi = 0.0;
    for (size_t i = 0; i < bytes; i += 4) {
        for (NSUInteger c = 0; c < 4; c++) {
            double v = (double)pixels[i + c] / 255.0;
            if (v < lo) lo = v;
            if (v > hi) hi = v;
        }
    }
    free(pixels);
    if (!(hi > lo)) {
        CharonMPSRefuse(@"%@: the window's own range is empty (%g..%g), so there is nothing to normalize"
                        @" and nothing was written", what, lo, hi);
        return;
    }
    // A texture has no -length; MTLTextureGetBytesPerPixel is how its row is measured, and a one-pixel
    // RGBA8 texture is eight bytes, which is the two floats :203 asks to be handed back.
    if ([minmax width] < 1 || [minmax height] < 1) {
        CharonMPSRefuse(@"%@: a minmax texture of %lux%lu has no room for a minimum and a maximum, so"
                        @" nothing was written", what, (unsigned long)[minmax width],
                        (unsigned long)[minmax height]);
        return;
    }
    // MTLTextureGetBytesPerPixel is not on this surface, and a texture does not report its length, so the
    // room is measured the way this package has measured everything else: from the format the caller gave
    // the encoder. The minmax texture the case builds is RGBA8 - one pixel is four bytes - and a format
    // this port does not carry is refused above rather than assumed to be roomy enough.
    if (minmax.pixelFormat != MTLPixelFormatRGBA8Unorm && minmax.pixelFormat != MTLPixelFormatRGBA8Unorm_sRGB) {
        CharonMPSRefuse(@"%@: a minmax texture of pixel format %lu is not one this port carries, so nothing"
                        @" was written", what, (unsigned long)minmax.pixelFormat);
        return;
    }
    if ([minmax width] < 1 || [minmax height] < 1) {
        CharonMPSRefuse(@"%@: a minmax texture of %lux%lu pixels has no pixel to put a minimum and a"
                        @" maximum in, so nothing was written", what, (unsigned long)[minmax width],
                        (unsigned long)[minmax height]);
        return;
    }
    // The minimum and the maximum go into the R and the G of ONE RGBA8 pixel - four bytes for two
    // unorm8 values. An earlier version of this check demanded room for two FLOATS, which the header
    // never asks for and which a 1x1 unorm8 texture cannot hold, so it refused the very case :203
    // describes. The values are quantised to unorm8, which is what an RGBA8 minmax texture IS: a caller
    // that needs float precision hands in a float texture, and this refuses that rather than pretending.
    // The min/max land in the R and G of one RGBA8 pixel, so the write is FOUR bytes with a bytesPerRow
    // of four. Writing two floats with a bytesPerRow of eight is a write past the row, which is the
    // "Region width OOB" the driver asserted on - our own write, not the source read.
    unsigned char minmaxOut[4] = {(unsigned char)(lo * 255.0), (unsigned char)(hi * 255.0), 0, 255};
    [minmax replaceRegion:MTLRegionMake2D(0, 0, 1, 1) mipmapLevel:0
               withBytes:minmaxOut bytesPerRow:4];

    NSUInteger channels = _histogramInfo.histogramForAlpha ? 4 : 3;
    size_t need = [self histogramSizeForSourceFormat:source.pixelFormat];
    unsigned char *base = (unsigned char *)[histogram contents];
    if (histogramOffset > [histogram length] || need > [histogram length] - histogramOffset) {
        CharonMPSRefuse(@"%@: %lu bytes at offset %lu will not fit a buffer of %lu, so nothing was written",
                        what, (unsigned long)need, (unsigned long)histogramOffset,
                        (unsigned long)[histogram length]);
        return;
    }
    uint32_t *bins = (uint32_t *)(base + histogramOffset);
    if (_zeroHistogram)
        memset(bins, 0, need);
    MPSImageHistogramInfo measured = _histogramInfo;
    measured.minPixelValue = (vector_float4){(float)lo, (float)lo, (float)lo, (float)lo};
    measured.maxPixelValue = (vector_float4){(float)hi, (float)hi, (float)hi, (float)hi};
    CharonMPSHistogramRegion(source, window, measured, (vector_float4){0.0f, 0.0f, 0.0f, 0.0f}, bins,
                             channels, _histogramInfo.histogramForAlpha, what);
}

@end
