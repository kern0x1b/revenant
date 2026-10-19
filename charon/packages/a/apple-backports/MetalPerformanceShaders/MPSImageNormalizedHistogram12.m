#import "CharonMPSHistogram.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

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
        return 0;
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
    if ([minmax width] < 1 || [minmax height] < 1) {
        CharonMPSRefuse(@"%@: a minmax texture of %lux%lu has no room for a minimum and a maximum, so"
                        @" nothing was written", what, (unsigned long)[minmax width],
                        (unsigned long)[minmax height]);
        return;
    }
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
