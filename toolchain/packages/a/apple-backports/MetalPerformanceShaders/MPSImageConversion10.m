#import "RevenantMPSImage.h"


@implementation MPSImageConversion {
    MPSAlphaType _sourceAlpha;
    MPSAlphaType _destinationAlpha;
    BOOL _flattens;
    BOOL _setsAlphaOne;
    BOOL _multiplies;
    BOOL _divides;
    double _background[4];
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
                        srcAlpha:(MPSAlphaType)srcAlpha
                       destAlpha:(MPSAlphaType)destAlpha
                 backgroundColor:(CGFloat *)backgroundColor
                  conversionInfo:(CGColorConversionInfoRef)conversionInfo
{
    if (conversionInfo) {
        RevenantMPSRefuse(@"MPSImageConversion: a colour space conversion was asked for and this port cannot"
                        @" perform it - CoreGraphics declares no accessor that reads the source and the"
                        @" destination space back out of a CGColorConversionInfoRef, so there is nothing"
                        @" to convert between. Pass NULL, which means no colour"
                        @" space conversion is needed, and the alpha conversion is carried");
        return nil;
    }
    if (!(self = [super initWithDevice:device]))
        return nil;
    _sourceAlpha = srcAlpha;
    _destinationAlpha = destAlpha;
    for (NSUInteger channel = 0; channel < 4; channel++)
        _background[channel] = 0.0;
    if (backgroundColor)
        for (NSUInteger channel = 0; channel < 4; channel++)
            _background[channel] = (double)backgroundColor[channel];
    _flattens = destAlpha == MPSAlphaTypeAlphaIsOne && srcAlpha != destAlpha;
    _setsAlphaOne = destAlpha == MPSAlphaTypeAlphaIsOne || srcAlpha == MPSAlphaTypeAlphaIsOne;
    _multiplies = destAlpha == MPSAlphaTypePremultiplied && srcAlpha == MPSAlphaTypeNonPremultiplied;
    _divides = destAlpha == MPSAlphaTypeNonPremultiplied && srcAlpha == MPSAlphaTypePremultiplied;
    return self;
}

- (MPSAlphaType)sourceAlpha { return _sourceAlpha; }
- (MPSAlphaType)destinationAlpha { return _destinationAlpha; }

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                  sourceImage:(MPSImage *)sourceImage
             destinationImage:(MPSImage *)destinationImage
{
    NSString *what = @"MPSImageConversion";
    if (!RevenantMPSCommandBufferPermits(commandBuffer))
        return;
    RevenantMPSImageLayout from = RevenantMPSImageLayoutOf(sourceImage);
    RevenantMPSImageLayout to = RevenantMPSImageLayoutOf(destinationImage);
    if (!RevenantMPSImageUsable(sourceImage, @"MPSImageConversion source") ||
        !RevenantMPSImageUsable(destinationImage, @"MPSImageConversion destination")) {
        RevenantMPSRefuse(@"%@: an image with no walkable shape was given, so nothing was written", what);
        return;
    }
    MTLRegion region = MTLRegionMake2D(0, 0, from.width, from.height);
    if (to.width < from.width || to.height < from.height) {
        RevenantMPSRefuse(@"%@: the destination is %lux%lu and the source %lux%lu, and a conversion does not"
                        @" enlarge or move pixels, so nothing was written", what,
                        (unsigned long)to.width, (unsigned long)to.height,
                        (unsigned long)from.width, (unsigned long)from.height);
        return;
    }
    from.count = (NSUInteger)region.size.width * (NSUInteger)region.size.height * from.channels;
    void *source = RevenantMPSImageReadRegion(sourceImage, &from, region, what);
    if (!source)
        return;
    size_t bytes = (size_t)to.width * to.channels * to.height * to.elementSize;
    unsigned char *destination = bytes ? (unsigned char *)calloc(bytes, 1) : NULL;
    if (!destination) {
        free(source);
        RevenantMPSRefuse(@"%@: no memory for a %lux%lu destination, so nothing was written", what,
                        (unsigned long)to.width, (unsigned long)to.height);
        return;
    }

    NSUInteger fromAlpha = from.channels > 1 ? from.channels - 1 : (NSUInteger)-1;
    NSUInteger toAlpha = to.channels > 1 ? to.channels - 1 : (NSUInteger)-1;
    NSUInteger pixels = from.width * from.height;
    for (NSUInteger pixel = 0; pixel < pixels; pixel++) {
        NSUInteger at = pixel * from.channels;
        NSUInteger into = pixel * to.channels;
        double alpha = _flattens || _multiplies || _divides
            ? (fromAlpha != (NSUInteger)-1 ? RevenantMPSImageLoad(source, &from, at + fromAlpha) : 1.0)
            : 1.0;
        for (NSUInteger channel = 0; channel < to.channels; channel++) {
            double value = channel < from.channels ? RevenantMPSImageLoad(source, &from, at + channel) : 0.0;
            if (toAlpha != (NSUInteger)-1 && channel == toAlpha) {
                value = _setsAlphaOne ? 1.0 : (fromAlpha != (NSUInteger)-1 ? alpha : 1.0);
            } else if (_divides) {
                value = alpha != 0.0 ? value / alpha : 0.0;
            } else if (_multiplies) {
                value = value * alpha;
            } else if (_flattens) {
                value = value * alpha + _background[channel < 4 ? channel : 3] * (1.0 - alpha);
            }
            RevenantMPSImageStore(destination, &to, into + channel, value);
        }
    }
    RevenantMPSImageWriteRegion(destinationImage, &to,
                              MTLRegionMake2D(0, 0, to.width, to.height), destination, what);
    free(source);
    free(destination);
}

@end
