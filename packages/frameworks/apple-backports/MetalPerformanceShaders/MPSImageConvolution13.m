#import "RevenantMPS.h"
#import "RevenantMPSImage.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

static void RevenantMPSConvolveRegion(MPSImage *source, MPSImage *destination, MTLRegion read,
                                    NSUInteger kernelWidth, NSUInteger kernelHeight, const float *weights,
                                    double bias, NSString *what)
{
    RevenantMPSImageLayout in = RevenantMPSImageLayoutOf(source);
    RevenantMPSImageLayout out = RevenantMPSImageLayoutOf(destination);
    if (!kernelWidth || !kernelHeight) {
        RevenantMPSRefuse(@"%@: a %lux%lu kernel has no weights to apply, so nothing was written", what,
                        (unsigned long)kernelWidth, (unsigned long)kernelHeight);
        return;
    }
    RevenantMPSImageLayout slice = in;
    slice.count = read.size.width * read.size.height * in.channels;
    void *from = RevenantMPSImageReadRegion(source, &slice, read, what);
    if (slice.count && !from)
        return;

    NSUInteger halfW = kernelWidth / 2, halfH = kernelHeight / 2;
    NSUInteger values = read.size.width * read.size.height;
    float *answer = calloc(values ? values : 1, sizeof(float));
    if (!answer) {
        RevenantMPSRefuse(@"%@: no memory for %lu convolved values, so nothing was written", what,
                        (unsigned long)values);
        return;
    }
    for (NSUInteger y = 0; y < read.size.height; y++) {
        for (NSUInteger x = 0; x < read.size.width; x++) {
            double total = 0.0;
            for (NSUInteger ky = 0; ky < kernelHeight; ky++) {
                for (NSUInteger kx = 0; kx < kernelWidth; kx++) {
                    long sy = (long)(read.origin.y + y + ky) - (long)halfH;
                    long sx = (long)(read.origin.x + x + kx) - (long)halfW;
                    double sample = 0.0;
                    if (sy >= 0 && sy < (long)in.height && sx >= 0 && sx < (long)in.width)
                        sample = RevenantMPSImageLoad(from, &slice,
                                                    RevenantMPSImageIndex(&slice,
                                        (NSUInteger)sy * read.size.width + (NSUInteger)sx, 0));
                    total += (double)weights[ky * kernelWidth + kx] * sample;
                }
            }
            answer[y * read.size.width + x] = (float)(total + bias);
        }
    }
    RevenantMPSImageWriteRegion(destination, &out, read, answer, what);
    free(answer);
    RevenantMPSConsumeReadCount(source);
}

@interface MPSUnaryImageKernel (RevenantMPSConvolution)
- (void)revenant_mps_convolveRegionWithSource:(MPSImage *)source
                                destination:(MPSImage *)destination
                                 kernelWidth:(NSUInteger)kernelWidth
                                kernelHeight:(NSUInteger)kernelHeight
                                    weights:(const float *)weights
                                        bias:(double)bias
                                        what:(NSString *)what;
@end

@implementation MPSUnaryImageKernel (RevenantMPSConvolution)

- (void)revenant_mps_convolveRegionWithSource:(MPSImage *)source
                                destination:(MPSImage *)destination
                                 kernelWidth:(NSUInteger)kernelWidth
                                kernelHeight:(NSUInteger)kernelHeight
                                    weights:(const float *)weights
                                        bias:(double)bias
                                        what:(NSString *)what
{
    if (self.edgeMode != MPSImageEdgeModeZero) {
        RevenantMPSRefuse(@"%@: edgeMode %lu is not MPSImageEdgeModeZero, the only mode this port implements"
                        @" - a Clamp or Mirror answer would be a different kernel - so nothing was written",
                        what, (unsigned long)self.edgeMode);
        return;
    }
    RevenantMPSConvolveRegion(source, destination,
                            RevenantMPSImageResolvedRegion(destination, self.clipRect),
                            kernelWidth, kernelHeight, weights, bias, what);
}

@end

@implementation MPSImageConvolution {
    NSUInteger _kernelWidth, _kernelHeight;
    NSMutableData *_weights;
    float _bias;
}

@synthesize kernelWidth = _kernelWidth;
@synthesize kernelHeight = _kernelHeight;
@synthesize bias = _bias;

- (instancetype)initWithDevice:(id<MTLDevice>)device
                 kernelWidth:(NSUInteger)kernelWidth
                kernelHeight:(NSUInteger)kernelHeight
                     weights:(const float *)kernelWeights
{
    if ((self = [super initWithDevice:device])) {
        if (!kernelWidth || !kernelHeight || !kernelWeights) {
            RevenantMPSRefuse(@"MPSImageConvolution: a %lux%lu kernel with weights %s is not a kernel",
                            (unsigned long)kernelWidth, (unsigned long)kernelHeight,
                            kernelWeights ? "given" : "not given");
            return nil;
        }
        _kernelWidth = kernelWidth;
        _kernelHeight = kernelHeight;
        _weights = [NSMutableData dataWithLength:kernelWidth * kernelHeight * sizeof(float)];
        if (!_weights) {
            RevenantMPSRefuse(@"MPSImageConvolution: no memory for a %lux%lu kernel, so no object was made",
                            (unsigned long)kernelWidth, (unsigned long)kernelHeight);
            return nil;
        }
        [_weights replaceBytesInRange:NSMakeRange(0, kernelWidth * kernelHeight * sizeof(float))
                            withBytes:kernelWeights];
        _bias = 0.0f;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder device:(id<MTLDevice>)device
{
    RevenantMPSRefuse(@"MPSImageConvolution: -initWithCoder:device: is not carried - the release's keys for a"
                    @" kernel's weights are in no header, so a decoder cannot rebuild them honestly");
    return nil;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                   sourceImage:(MPSImage *)sourceImage
             destinationImage:(MPSImage *)destinationImage
{
    NSString *what = NSStringFromClass([self class]);
    if (!commandBuffer) {
        RevenantMPSRefuse(@"%@: no command buffer, so nothing was written", what);
        return;
    }
    if (!RevenantMPSCommandBufferPermits(commandBuffer))
        return;
    if (!RevenantMPSImageUsable(sourceImage, what)) {
        RevenantMPSRefuse(@"%@: the source image cannot be walked", what);
        return;
    }
    if (!destinationImage) {
        RevenantMPSRefuse(@"%@: no destination image, so nothing was written", what);
        return;
    }
    if (self.edgeMode != MPSImageEdgeModeZero) {
        RevenantMPSRefuse(@"%@: edgeMode %lu is not MPSImageEdgeModeZero, which is the only mode this port"
                        @" implements - a Clamp or Mirror answer would be a different kernel - so nothing"
                        @" was written", what, (unsigned long)self.edgeMode);
        return;
    }
    RevenantMPSConvolveRegion(sourceImage, destinationImage,
                            RevenantMPSImageResolvedRegion(destinationImage, self.clipRect),
                            _kernelWidth, _kernelHeight, (const float *)_weights.bytes, (double)_bias, what);
}

@end

@implementation MPSImageBox {
    NSUInteger _kernelWidth, _kernelHeight;
    NSMutableData *_weights;
}

@synthesize kernelWidth = _kernelWidth;
@synthesize kernelHeight = _kernelHeight;

- (instancetype)initWithDevice:(id<MTLDevice>)device kernelHeight:(NSUInteger)kernelHeight
                    kernelWidth:(NSUInteger)kernelWidth
{
    if ((self = [super initWithDevice:device])) {
        if (!kernelWidth || !kernelHeight || !(kernelWidth % 2) || !(kernelHeight % 2)) {
            RevenantMPSRefuse(@"MPSImageBox: a %lux%lu window is refused - the width and the height have to be odd,"
                            @" so no object was made", (unsigned long)kernelWidth,
                            (unsigned long)kernelHeight);
            return nil;
        }
        _kernelWidth = kernelWidth;
        _kernelHeight = kernelHeight;
        _weights = [NSMutableData dataWithLength:kernelWidth * kernelHeight * sizeof(float)];
        if (!_weights) {
            RevenantMPSRefuse(@"MPSImageBox: no memory for a %lux%lu window, so no object was made",
                            (unsigned long)kernelWidth, (unsigned long)kernelHeight);
            return nil;
        }
        float *weights = (float *)_weights.mutableBytes;
        float one = (float)(1.0 / (double)(kernelWidth * kernelHeight));
        for (NSUInteger i = 0; i < kernelWidth * kernelHeight; i++)
            weights[i] = one;
    }
    return self;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    RevenantMPSRefuse(@"MPSImageBox: -initWithDevice: is NS_UNAVAILABLE - the"
                    @" window size is what makes a box, so no object was made");
    return nil;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                   sourceImage:(MPSImage *)sourceImage
             destinationImage:(MPSImage *)destinationImage
{
    NSString *what = NSStringFromClass([self class]);
    if (self.edgeMode != MPSImageEdgeModeZero) {
        RevenantMPSRefuse(@"%@: edgeMode %lu is not MPSImageEdgeModeZero, the only mode this port implements,"
                        @" so nothing was written", what, (unsigned long)self.edgeMode);
        return;
    }
    RevenantMPSConvolveRegion(sourceImage, destinationImage,
                            RevenantMPSImageResolvedRegion(destinationImage, self.clipRect),
                            _kernelWidth, _kernelHeight, (const float *)_weights.bytes, 0.0, what);
}

@end

@interface MPSImageBox (RevenantTentWeights)
- (void)revenant_makeTentWeights;
@end

@implementation MPSImageTent

- (instancetype)initWithDevice:(id<MTLDevice>)device kernelHeight:(NSUInteger)kernelHeight
                    kernelWidth:(NSUInteger)kernelWidth
{
    if ((self = [super initWithDevice:device kernelHeight:kernelHeight kernelWidth:kernelWidth]))
        [self revenant_makeTentWeights];
    return self;
}

@end

@implementation MPSImageGaussianBlur {
    float _sigma;
    NSUInteger _kernelWidth, _kernelHeight;
    NSMutableData *_weights;
}

@synthesize sigma = _sigma;

- (instancetype)initWithDevice:(id<MTLDevice>)device sigma:(float)sigma
{
    if ((self = [super initWithDevice:device])) {
        RevenantMPSRefuse(@"MPSImageGaussianBlur: -initWithDevice:sigma: needs the tap count MPSImage"
                        @"Convolution.h does not state for a sigma, and a blur of a different width is a"
                        @" different blur, so no object was made");
        return nil;
    }
    return nil;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                   sourceImage:(MPSImage *)sourceImage
             destinationImage:(MPSImage *)destinationImage
{
    RevenantMPSRefuse(@"MPSImageGaussianBlur: no object can be built, so nothing was written");
}

@end

@implementation MPSImageBox (RevenantTentWeights)
- (void)revenant_makeTentWeights
{
    NSUInteger w = self.kernelWidth, h = self.kernelHeight;
    if (!w || !h || !_weights)
        return;
    float *weights = (float *)_weights.mutableBytes;
    double total = 0.0;
    for (NSUInteger ky = 0; ky < h; ky++)
        for (NSUInteger kx = 0; kx < w; kx++)
            total += (double)(1 + (w / 2) - (kx < w / 2 ? kx : w - 1 - kx)) *
                     (1 + (h / 2) - (ky < h / 2 ? ky : h - 1 - ky));
    if (total <= 0.0)
        return;
    for (NSUInteger ky = 0; ky < h; ky++)
        for (NSUInteger kx = 0; kx < w; kx++) {
            double wx = (double)(1 + (w / 2) - (kx < w / 2 ? kx : w - 1 - kx));
            double wy = (double)(1 + (h / 2) - (ky < h / 2 ? ky : h - 1 - ky));
            weights[ky * w + kx] = (float)(wx * wy / total);
        }
}
@end
