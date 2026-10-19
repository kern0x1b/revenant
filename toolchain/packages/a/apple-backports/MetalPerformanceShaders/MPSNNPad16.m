#import "CharonMPSCnn.h"

@implementation MPSNNPad {
    MPSImageCoordinate _paddingSizeBefore;
    MPSImageCoordinate _paddingSizeAfter;
    float _fillValue;
    NSData *_fillValueArray;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    return [self initWithDevice:device
             paddingSizeBefore:(MPSImageCoordinate){0, 0, 0}
              paddingSizeAfter:(MPSImageCoordinate){0, 0, 0}
                 fillValueArray:nil];
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
            paddingSizeBefore:(MPSImageCoordinate)paddingSizeBefore
             paddingSizeAfter:(MPSImageCoordinate)paddingSizeAfter
{
    return [self initWithDevice:device paddingSizeBefore:paddingSizeBefore paddingSizeAfter:paddingSizeAfter fillValueArray:nil];
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
            paddingSizeBefore:(MPSImageCoordinate)paddingSizeBefore
             paddingSizeAfter:(MPSImageCoordinate)paddingSizeAfter
                fillValueArray:(NSData *)fillValueArray
{
    if ((self = [super initWithDevice:device])) {
        _paddingSizeBefore = paddingSizeBefore;
        _paddingSizeAfter = paddingSizeAfter;
        _fillValue = 0.0f;
        _fillValueArray = fillValueArray;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder device:(id<MTLDevice>)device
{
    return [super initWithCoder:aDecoder device:device];
}

- (MPSImageCoordinate)paddingSizeBefore { return _paddingSizeBefore; }
- (void)setPaddingSizeBefore:(MPSImageCoordinate)paddingSizeBefore { _paddingSizeBefore = paddingSizeBefore; }
- (MPSImageCoordinate)paddingSizeAfter { return _paddingSizeAfter; }
- (void)setPaddingSizeAfter:(MPSImageCoordinate)paddingSizeAfter { _paddingSizeAfter = paddingSizeAfter; }
- (float)fillValue { return _fillValue; }
- (void)setFillValue:(float)fillValue { _fillValue = fillValue; }

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                  sourceImage:(MPSImage *)sourceImage
             destinationImage:(MPSImage *)destinationImage
{
    NSString *what = @"MPSNNPad";
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    if (!sourceImage || !destinationImage || !sourceImage.width || !sourceImage.height ||
        !destinationImage.width || !destinationImage.height) {
        CharonMPSRefuse(@"%@: an image with no shape was given, so nothing was written", what);
        return;
    }
    NSUInteger wantWidth = sourceImage.width + _paddingSizeBefore.x + _paddingSizeAfter.x;
    NSUInteger wantHeight = sourceImage.height + _paddingSizeBefore.y + _paddingSizeAfter.y;
    NSUInteger wantChannels = sourceImage.featureChannels + _paddingSizeBefore.channel + _paddingSizeAfter.channel;
    if (destinationImage.width != wantWidth || destinationImage.height != wantHeight ||
        destinationImage.featureChannels != wantChannels) {
        CharonMPSRefuse(@"%@: a %lux%lu source with %lu before and %lu after pads is %lux%lu with %lu feature"
                        @" channels, and the destination is %lux%lu with %lu; nothing was written", what,
                        (unsigned long)sourceImage.width, (unsigned long)sourceImage.height,
                        (unsigned long)_paddingSizeBefore.x, (unsigned long)_paddingSizeAfter.x,
                        (unsigned long)wantWidth, (unsigned long)wantHeight, (unsigned long)wantChannels,
                        (unsigned long)destinationImage.width, (unsigned long)destinationImage.height,
                        (unsigned long)destinationImage.featureChannels);
        return;
    }
    NSUInteger perChannel = 0;
    const float *fill = (const float *)[_fillValueArray bytes];
    if (fill)
        perChannel = (NSUInteger)([_fillValueArray length] / sizeof(float));
    if (fill && perChannel < wantChannels) {
        CharonMPSRefuse(@"%@: the fill array holds %lu value(s) and the destination has %lu feature channels,"
                        @" which is undefined behavior, so nothing was written", what,
                        (unsigned long)perChannel, (unsigned long)wantChannels);
        return;
    }

    CharonMPSCnnPlane from, to;
    size_t inWidth, inHeight, inChannels, outWidth, outHeight, outChannels;
    CharonMPSCnnTake(sourceImage, &from, &inWidth, &inHeight, &inChannels);
    CharonMPSCnnTake(destinationImage, &to, &outWidth, &outHeight, &outChannels);
    for (NSUInteger channel = 0; channel < outChannels; channel++) {
        double filled = fill ? (double)fill[channel] : (double)_fillValue;
        for (NSUInteger oy = 0; oy < outHeight; oy++) {
            for (NSUInteger ox = 0; ox < outWidth; ox++) {
                long sx = (long)ox - (long)_paddingSizeBefore.x;
                long sy = (long)oy - (long)_paddingSizeBefore.y;
                long sc = (long)channel - (long)_paddingSizeBefore.channel;
                double value = filled;
                if (sx >= 0 && sy >= 0 && sc >= 0 && (NSUInteger)sx < inWidth && (NSUInteger)sy < inHeight &&
                    (NSUInteger)sc < inChannels) {
                    value = CharonMPSLoad(CharonMPSCnnPixel(&from, (size_t)sx, (size_t)sy, (size_t)sc),
                                          MPSDataTypeFloat32, 0);
                }
                CharonMPSStore(CharonMPSCnnPixelMutable(&to, ox, oy, channel), MPSDataTypeFloat32, 0, value);
            }
        }
    }
    CharonMPSCnnGive(destinationImage, &to);
    CharonMPSCnnGive(sourceImage, &from);
    CharonMPSConsumeReadCount(sourceImage);
}

@end
