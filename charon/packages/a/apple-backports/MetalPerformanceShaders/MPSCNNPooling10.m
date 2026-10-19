#import "CharonMPSCnn.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation MPSCNNPooling {
    NSUInteger _zeroPadSizeX, _zeroPadSizeY;
    BOOL _maximum;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
                 kernelWidth:(NSUInteger)kernelWidth
                kernelHeight:(NSUInteger)kernelHeight
               strideInPixelsX:(NSUInteger)strideInPixelsX
               strideInPixelsY:(NSUInteger)strideInPixelsY
{
    if ((self = [super initWithDevice:device])) {
        [self charon_mps_setWindowWidth:kernelWidth height:kernelHeight
                        strideInPixelsX:strideInPixelsX strideInPixelsY:strideInPixelsY
                         dilationRateX:1 dilationRateY:1];
    }
    self.edgeMode = MPSImageEdgeModeZero;
    return self;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device kernelWidth:(NSUInteger)kernelWidth kernelHeight:(NSUInteger)kernelHeight
{
    return [self initWithDevice:device kernelWidth:kernelWidth kernelHeight:kernelHeight strideInPixelsX:1 strideInPixelsY:1];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder device:(id<MTLDevice>)device
{
    return [super initWithDevice:device];
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    NSLog(@"MPSCNNPooling: -initWithDevice: names no window; use -initWithDevice:kernelWidth:kernelHeight:strideInPixelsX:strideInPixelsY:");
    return nil;
}

- (NSUInteger)charon_mps_zeroPadSizeX { return _zeroPadSizeX; }
- (NSUInteger)charon_mps_zeroPadSizeY { return _zeroPadSizeY; }

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                  sourceImage:(MPSImage *)sourceImage
               destinationImage:(MPSImage *)destinationImage
{
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    if (sourceImage.featureChannelFormat != MPSImageFeatureChannelFormatFloat32 ||
        destinationImage.featureChannelFormat != MPSImageFeatureChannelFormatFloat32) {
        CharonMPSRefuse(@"MPSCNNPooling: only single precision images are carried, so nothing was written");
        return;
    }
    CharonMPSCnnPlane from, to;
    size_t inWidth, inHeight, inChannels, outWidth, outHeight, outChannels;
    CharonMPSCnnTake(sourceImage, &from, &inWidth, &inHeight, &inChannels);
    CharonMPSCnnTake(destinationImage, &to, &outWidth, &outHeight, &outChannels);

    NSUInteger windowWidth = self.kernelWidth;
    NSUInteger windowHeight = self.kernelHeight;
    double divisor = (double)windowWidth * (double)windowHeight;
    NSUInteger leftPad = windowWidth / 2, topPad = windowHeight / 2;
    (void)[self charon_mps_zeroPadSizeX];
    (void)[self charon_mps_zeroPadSizeY];
    for (NSUInteger channel = 0; channel < outChannels; channel++) {
        for (NSUInteger oy = 0; oy < outHeight; oy++) {
            for (NSUInteger ox = 0; ox < outWidth; ox++) {
                double best = -INFINITY, sum = 0.0;
                for (NSUInteger wy = 0; wy < windowHeight; wy++) {
                    for (NSUInteger wx = 0; wx < windowWidth; wx++) {
                        long sx = (long)ox * (long)self.strideInPixelsX + (long)wx - (long)leftPad;
                        long sy = (long)oy * (long)self.strideInPixelsY + (long)wy - (long)topPad;
                        double value = 0.0;
                        if (sx >= 0 && sy >= 0 && (NSUInteger)sx < inWidth && (NSUInteger)sy < inHeight) {
                            value = CharonMPSLoad(CharonMPSCnnPixel(&from, (size_t)sx, (size_t)sy,
                                                                      channel < inChannels ? channel : inChannels - 1),
                                                  MPSDataTypeFloat32, 0);
                        } else if (self.edgeMode == MPSImageEdgeModeClamp) {
                            long cx = sx < 0 ? 0 : ((NSUInteger)sx >= inWidth ? (long)inWidth - 1 : sx);
                            long cy = sy < 0 ? 0 : ((NSUInteger)sy >= inHeight ? (long)inHeight - 1 : sy);
                            value = CharonMPSLoad(CharonMPSCnnPixel(&from, (size_t)cx, (size_t)cy,
                                                                      channel < inChannels ? channel : inChannels - 1),
                                                  MPSDataTypeFloat32, 0);
                        }
                        sum += value;
                        if (value > best)
                            best = value;
                    }
                }
                double result = _maximum ? best : sum / divisor;
                CharonMPSStore(CharonMPSCnnPixelMutable(&to, ox, oy, channel), MPSDataTypeFloat32, 0, result);
            }
        }
    }
    CharonMPSCnnGive(destinationImage, &to);
    CharonMPSCnnGive(sourceImage, &from);
    CharonMPSConsumeReadCount(sourceImage);
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (void)charon_mps_setMaximum:(BOOL)maximum
{
    _maximum = maximum;
}

@end

@implementation MPSCNNPoolingAverage {
    NSUInteger _zeroPadSizeX, _zeroPadSizeY;
}
- (NSUInteger)zeroPadSizeX { return _zeroPadSizeX; }
- (void)setZeroPadSizeX:(NSUInteger)value { _zeroPadSizeX = value; }
- (NSUInteger)zeroPadSizeY { return _zeroPadSizeY; }
- (void)setZeroPadSizeY:(NSUInteger)value { _zeroPadSizeY = value; }
- (NSUInteger)charon_mps_zeroPadSizeX { return _zeroPadSizeX; }
- (NSUInteger)charon_mps_zeroPadSizeY { return _zeroPadSizeY; }

- (instancetype)initWithDevice:(id<MTLDevice>)device
                 kernelWidth:(NSUInteger)kernelWidth
                kernelHeight:(NSUInteger)kernelHeight
               strideInPixelsX:(NSUInteger)strideInPixelsX
               strideInPixelsY:(NSUInteger)strideInPixelsY
{
    if ((self = [super initWithDevice:device kernelWidth:kernelWidth kernelHeight:kernelHeight
                       strideInPixelsX:strideInPixelsX strideInPixelsY:strideInPixelsY]))
        [self charon_mps_setMaximum:NO];
    return self;
}
@end

@implementation MPSCNNPoolingMax
- (instancetype)initWithDevice:(id<MTLDevice>)device
                 kernelWidth:(NSUInteger)kernelWidth
                kernelHeight:(NSUInteger)kernelHeight
               strideInPixelsX:(NSUInteger)strideInPixelsX
               strideInPixelsY:(NSUInteger)strideInPixelsY
{
    if ((self = [super initWithDevice:device kernelWidth:kernelWidth kernelHeight:kernelHeight
                       strideInPixelsX:strideInPixelsX strideInPixelsY:strideInPixelsY]))
        [self charon_mps_setMaximum:YES];
    return self;
}
@end
