#import "RevenantMPSHistogram.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

@implementation MPSImageHistogram {
    MTLRegion _clipRectSource;
    BOOL _zeroHistogram;
    vector_float4 _minPixelThresholdValue;
    MPSImageHistogramInfo _histogramInfo;
}

@synthesize clipRectSource = _clipRectSource;
@synthesize zeroHistogram = _zeroHistogram;
@synthesize minPixelThresholdValue = _minPixelThresholdValue;
@synthesize histogramInfo = _histogramInfo;

- (instancetype)initWithDevice:(id<MTLDevice>)device histogramInfo:(const MPSImageHistogramInfo *)histogramInfo
{
    if ((self = [super initWithDevice:device])) {
        if (!histogramInfo || !histogramInfo->numberOfHistogramEntries) {
            RevenantMPSRefuse(@"MPSImageHistogram: MPSImageHistogramInfo with %lu entries describes no"
                            @" histogram, so no object was made",
                            (unsigned long)(histogramInfo ? histogramInfo->numberOfHistogramEntries : 0));
            return nil;
        }
        _histogramInfo = *histogramInfo;
        _clipRectSource = MPSRectNoClip;
        _zeroHistogram = YES;
        _minPixelThresholdValue = (vector_float4){0.0f, 0.0f, 0.0f, 0.0f};
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder device:(id<MTLDevice>)device
{
    RevenantMPSRefuse(@"MPSImageHistogram: -initWithCoder:device: is not carried - the release's keys for a"
                    @" histogram's bins and range are in no header, so a decoder cannot rebuild them"
                    @" honestly");
    return nil;
}

- (size_t)histogramSizeForSourceFormat:(MTLPixelFormat)sourceFormat
{
    if (sourceFormat != MTLPixelFormatRGBA8Unorm && sourceFormat != MTLPixelFormatRGBA8Unorm_sRGB) {
        RevenantMPSRefuse(@"MPSImageHistogram: -histogramSizeForSourceFormat: is asked about pixel format %lu,"
                        @" which this port does not carry, so the size is not guessed", (unsigned long)sourceFormat);
        return 0;
    }
    NSUInteger channels = 4;
    if (!_histogramInfo.histogramForAlpha)
        channels = 3;
    return (size_t)_histogramInfo.numberOfHistogramEntries * channels * sizeof(uint32_t);
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                sourceTexture:(id<MTLTexture>)source
                     histogram:(id<MTLBuffer>)histogram
                histogramOffset:(NSUInteger)histogramOffset
{
    NSString *what = NSStringFromClass([self class]);
    if (!source || !histogram) {
        RevenantMPSRefuse(@"%@: a source texture and a histogram buffer are both required, so nothing was"
                        @" written", what);
        return;
    }
    NSUInteger channels = _histogramInfo.histogramForAlpha ? 4 : 3;
    size_t need = [self histogramSizeForSourceFormat:source.pixelFormat];
    unsigned char *base = (unsigned char *)[histogram contents];
    if (histogramOffset > [histogram length] || need > [histogram length] - histogramOffset) {
        RevenantMPSRefuse(@"%@: %lu bytes at offset %lu will not fit a buffer of %lu, so nothing was written",
                        what, (unsigned long)need, (unsigned long)histogramOffset,
                        (unsigned long)[histogram length]);
        return;
    }
    uint32_t *bins = (uint32_t *)(base + histogramOffset);
    if (_zeroHistogram)
        memset(bins, 0, need);
    MTLRegion window = _clipRectSource;
    if (window.size.width < 0 || window.size.height < 0) {
        window = MTLRegionMake2D(0, 0, source.width, source.height);
    }
    RevenantMPSHistogramRegion(source, window, _histogramInfo, _minPixelThresholdValue, bins, channels,
                             _histogramInfo.histogramForAlpha, what);
}

@end
