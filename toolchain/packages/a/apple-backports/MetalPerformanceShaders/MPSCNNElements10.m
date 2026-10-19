#import "CharonMPSCnn.h"
#import "CharonMPS.h"
#import "CharonMPSImage.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

static BOOL CharonMPSCnnPairIsFloat32(MPSImage *source, MPSImage *destination, NSString *what)
{
    if (source.featureChannelFormat != MPSImageFeatureChannelFormatFloat32 ||
        destination.featureChannelFormat != MPSImageFeatureChannelFormatFloat32) {
        CharonMPSRefuse(@"%@: only single precision images are carried, so nothing was written", what);
        return NO;
    }
    if (!source.width || !source.height || !source.featureChannels ||
        !destination.width || !destination.height || !destination.featureChannels) {
        CharonMPSRefuse(@"%@: an image of the pair has no shape or no feature channels, so nothing was written",
                        what);
        return NO;
    }
    return YES;
}

typedef struct {
    const void *base;
    size_t width, height, channels;
    size_t valuesPerPixel;
} CharonMPSCnnInterleaved;

static BOOL CharonMPSCnnRead(MPSImage *image, CharonMPSCnnInterleaved *out)
{
    CharonMPSImageLayout layout = CharonMPSImageLayoutOf(image);
    memset(out, 0, sizeof(*out));
    out->width = layout.width;
    out->height = layout.height;
    out->channels = layout.channels;
    out->valuesPerPixel = layout.elementSize ? layout.bytesPerPixel / layout.elementSize : 0;
    if (!out->width || !out->height || !out->channels || !out->valuesPerPixel)
        return NO;
    layout.count = out->width * out->height * out->channels;
    out->base = CharonMPSImageReadRegion(image, &layout,
                                         MTLRegionMake2D(0, 0, out->width, out->height),
                                         @"MPSCNNElements10");
    return out->base != NULL;
}

static void CharonMPSCnnWrite(MPSImage *image, CharonMPSCnnInterleaved *view)
{
    if (!view->base)
        return;
    CharonMPSImageLayout layout = CharonMPSImageLayoutOf(image);
    layout.count = view->width * view->height * view->channels;
    CharonMPSImageWriteRegion(image, &layout, MTLRegionMake2D(0, 0, view->width, view->height),
                              view->base, @"MPSCNNElements10");
    view->base = NULL;
}

static double CharonMPSCnnValue(const CharonMPSCnnInterleaved *view, size_t x, size_t y, size_t channel)
{
    if (!view->base || x >= view->width || y >= view->height || channel >= view->channels)
        return 0.0;
    return CharonMPSLoad((const char *)view->base +
                         (y * view->width * view->valuesPerPixel + x * view->valuesPerPixel + channel) *
                         sizeof(float),
                         MPSDataTypeFloat32, 0);
}

static void CharonMPSCnnStore(CharonMPSCnnInterleaved *view, size_t x, size_t y, size_t channel, double value)
{
    if (!view->base || x >= view->width || y >= view->height || channel >= view->channels)
        return;
    CharonMPSStore((char *)view->base +
                   (y * view->width * view->valuesPerPixel + x * view->valuesPerPixel + channel) *
                   sizeof(float),
                   MPSDataTypeFloat32, 0, value);
}

static double CharonMPSCnnWindowSquares(const CharonMPSCnnInterleaved *view, size_t channel,
                                        size_t x, size_t y, NSUInteger kernel)
{
    long first = -(long)(kernel / 2);
    double total = 0.0;
    for (NSUInteger ky = 0; ky < kernel; ky++)
        for (NSUInteger kx = 0; kx < kernel; kx++) {
            double value = CharonMPSCnnValue(view, (size_t)((long)x + first + (long)kx),
                                             (size_t)((long)y + first + (long)ky), channel);
            total += value * value;
        }
    return total;
}

static double CharonMPSCnnWindowSum(const CharonMPSCnnInterleaved *view, size_t channel,
                                    size_t x, size_t y, NSUInteger kernel)
{
    long first = -(long)(kernel / 2);
    double total = 0.0;
    for (NSUInteger ky = 0; ky < kernel; ky++)
        for (NSUInteger kx = 0; kx < kernel; kx++)
            total += CharonMPSCnnValue(view, (size_t)((long)x + first + (long)kx),
                                       (size_t)((long)y + first + (long)ky), channel);
    return total;
}

@implementation MPSCNNNeuron {
    MPSCNNNeuronType _charonType;
    float _a, _b, _c;
    const float *_prelu;
    NSUInteger _preluCount;
}

@synthesize a = _a;
@synthesize b = _b;
@synthesize c = _c;

- (instancetype)initCharonMPSWithDevice:(id<MTLDevice>)device
{
    if ((self = [super initWithDevice:device])) {
        _charonType = MPSCNNNeuronTypeReLU;
        _a = 0.0f;
        _b = 0.0f;
        _c = 0.0f;
        _prelu = NULL;
        _preluCount = 0;
    }
    return self;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    CharonMPSRefuse(@"MPSCNNNeuron: at 10.0 this class has no initialiser of its own - its designated "
                    @"one takes an MPSNNNeuronDescriptor, which arrived in 11.3 - so use one of "
                    @"MPSCNNNeuronLinear, MPSCNNNeuronReLU, MPSCNNNeuronSigmoid, MPSCNNNeuronTanH "
                    @"or MPSCNNNeuronAbsolute");
    return nil;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder device:(id<MTLDevice>)device
{
    return [self initCharonMPSWithDevice:device];
}

- (MPSCNNNeuronType)charon_mps_neuronType { return _charonType; }

- (void)charon_mps_setNeuron:(MPSCNNNeuronType)type
                            a:(float)a
                            b:(float)b
                            c:(float)c
{
    _charonType = type;
    _a = a;
    _b = b;
    _c = c;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                  sourceImage:(MPSImage *)sourceImage
               destinationImage:(MPSImage *)destinationImage
{
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    if (!CharonMPSCnnPairIsFloat32(sourceImage, destinationImage, @"MPSCNNNeuron"))
        return;

    CharonMPSCnnInterleaved from, to;
    if (!CharonMPSCnnRead(sourceImage, &from) || !CharonMPSCnnRead(destinationImage, &to)) {
        CharonMPSCnnWrite(destinationImage, &to);
        CharonMPSCnnWrite(sourceImage, &from);
        return;
    }
    size_t inChannels = from.channels, outWidth = to.width, outHeight = to.height, outChannels = to.channels;

    MPSCNNNeuronType type = _charonType;
    double a = (double)_a, b = (double)_b, c = (double)_c;
    for (size_t channel = 0; channel < outChannels; channel++) {
        double perChannel = _prelu && channel < _preluCount ? (double)_prelu[channel] : a;
        size_t source = channel < inChannels ? channel : inChannels - 1;
        for (size_t y = 0; y < outHeight; y++)
            for (size_t x = 0; x < outWidth; x++) {
                double value = CharonMPSCnnValue(&from, x, y, source);
                double result = CharonMPSApplyNeuron(type, value, a, b, c, perChannel);
                CharonMPSCnnStore(&to, x, y, channel, result);
            }
    }
    CharonMPSCnnWrite(destinationImage, &to);
    CharonMPSCnnWrite(sourceImage, &from);
    CharonMPSConsumeReadCount(sourceImage);
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

@end

@implementation MPSCNNNeuronLinear
- (instancetype)initWithDevice:(id<MTLDevice>)device a:(float)a b:(float)b
{
    if ((self = [self initCharonMPSWithDevice:device]))
        [self charon_mps_setNeuron:MPSCNNNeuronTypeLinear a:a b:b c:1.0f];
    return self;
}
@end

@implementation MPSCNNNeuronReLU
- (instancetype)initWithDevice:(id<MTLDevice>)device a:(float)a
{
    if ((self = [self initCharonMPSWithDevice:device]))
        [self charon_mps_setNeuron:MPSCNNNeuronTypeReLU a:a b:0.0f c:0.0f];
    return self;
}
@end

@implementation MPSCNNNeuronSigmoid
- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    if ((self = [self initCharonMPSWithDevice:device]))
        [self charon_mps_setNeuron:MPSCNNNeuronTypeSigmoid a:1.0f b:1.0f c:1.0f];
    return self;
}
@end

@implementation MPSCNNNeuronTanH
- (instancetype)initWithDevice:(id<MTLDevice>)device a:(float)a b:(float)b
{
    if ((self = [self initCharonMPSWithDevice:device]))
        [self charon_mps_setNeuron:MPSCNNNeuronTypeTanH a:a b:b c:1.0f];
    return self;
}
@end

@implementation MPSCNNNeuronAbsolute
- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    if ((self = [self initCharonMPSWithDevice:device]))
        [self charon_mps_setNeuron:MPSCNNNeuronTypeAbsolute a:1.0f b:1.0f c:1.0f];
    return self;
}
@end

static void CharonMPSCnnSoftMaxWalk(MPSCNNKernel *owner, id<MTLCommandBuffer> commandBuffer,
                                    MPSImage *sourceImage, MPSImage *destinationImage, BOOL logarithmic)
{
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    if (!CharonMPSCnnPairIsFloat32(sourceImage, destinationImage,
                                   logarithmic ? @"MPSCNNLogSoftMax" : @"MPSCNNSoftMax"))
        return;

    CharonMPSCnnInterleaved from, to;
    if (!CharonMPSCnnRead(sourceImage, &from) || !CharonMPSCnnRead(destinationImage, &to)) {
        CharonMPSCnnWrite(destinationImage, &to);
        CharonMPSCnnWrite(sourceImage, &from);
        return;
    }
    size_t inChannels = from.channels, outWidth = to.width, outHeight = to.height, outChannels = to.channels;

    size_t channels = outChannels < inChannels ? outChannels : inChannels;
    double *values = calloc(channels ? channels : 1, sizeof(double));
    double *exponentials = calloc(channels ? channels : 1, sizeof(double));
    for (size_t y = 0; y < outHeight; y++) {
        for (size_t x = 0; x < outWidth; x++) {
            double sum = 0.0;
            for (size_t channel = 0; channel < channels; channel++) {
                double value = CharonMPSCnnValue(&from, x, y, channel);
                values[channel] = value;
                exponentials[channel] = exp(value);
                sum += exponentials[channel];
            }
            if (sum == 0.0)
                sum = 1.0;
            double logarithm = log(sum);
            for (size_t channel = 0; channel < channels; channel++) {
                double result = logarithmic ? (values[channel] - logarithm)
                                            : (exponentials[channel] / sum);
                CharonMPSCnnStore(&to, x, y, channel, result);
            }
        }
    }
    free(exponentials);
    free(values);
    CharonMPSCnnWrite(destinationImage, &to);
    CharonMPSCnnWrite(sourceImage, &from);
    CharonMPSConsumeReadCount(sourceImage);
    (void)owner;
}

@implementation MPSCNNSoftMax

+ (BOOL)charon_mps_isLogarithmic
{
    return NO;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                  sourceImage:(MPSImage *)sourceImage
               destinationImage:(MPSImage *)destinationImage
{
    CharonMPSCnnSoftMaxWalk(self, commandBuffer, sourceImage, destinationImage,
                            [[self class] charon_mps_isLogarithmic]);
}

@end

@implementation MPSCNNLogSoftMax
+ (BOOL)charon_mps_isLogarithmic
{
    return YES;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                  sourceImage:(MPSImage *)sourceImage
               destinationImage:(MPSImage *)destinationImage
{
    CharonMPSCnnSoftMaxWalk(self, commandBuffer, sourceImage, destinationImage,
                            [[self class] charon_mps_isLogarithmic]);
}
@end

@implementation MPSCNNSpatialNormalization {
    float _alpha, _beta, _delta;
}

@synthesize alpha = _alpha;
@synthesize beta = _beta;
@synthesize delta = _delta;

- (instancetype)initWithDevice:(id<MTLDevice>)device
                 kernelWidth:(NSUInteger)kernelWidth
                kernelHeight:(NSUInteger)kernelHeight
{
    if ((self = [super initWithDevice:device])) {
        _alpha = 1.0f;
        _beta = 5.0f;
        _delta = 1.0f;
        [self charon_mps_setWindowWidth:kernelWidth height:kernelHeight
                        strideInPixelsX:1 strideInPixelsY:1 dilationRateX:1 dilationRateY:1];
    }
    return self;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                  sourceImage:(MPSImage *)sourceImage
               destinationImage:(MPSImage *)destinationImage
{
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    if (!CharonMPSCnnPairIsFloat32(sourceImage, destinationImage, @"MPSCNNSpatialNormalization"))
        return;

    CharonMPSCnnInterleaved from, to;
    if (!CharonMPSCnnRead(sourceImage, &from) || !CharonMPSCnnRead(destinationImage, &to)) {
        CharonMPSCnnWrite(destinationImage, &to);
        CharonMPSCnnWrite(sourceImage, &from);
        return;
    }
    size_t inChannels = from.channels, outWidth = to.width, outHeight = to.height, outChannels = to.channels;

    NSUInteger kernel = self.kernelWidth ? self.kernelWidth : 1;
    double area = (double)kernel * (double)(self.kernelHeight ? self.kernelHeight : kernel);
    double alpha = (double)_alpha, beta = (double)_beta, delta = (double)_delta;
    for (size_t channel = 0; channel < outChannels; channel++) {
        size_t source = channel < inChannels ? channel : inChannels - 1;
        for (size_t y = 0; y < outHeight; y++)
            for (size_t x = 0; x < outWidth; x++) {
                double n2 = CharonMPSCnnWindowSquares(&from, source, x, y, kernel);
                double value = CharonMPSCnnValue(&from, x, y, source);
                double denominator = pow(delta + alpha / area * n2, beta);
                double result = denominator == 0.0 ? 0.0 : value / denominator;
                CharonMPSCnnStore(&to, x, y, channel, result);
            }
    }
    CharonMPSCnnWrite(destinationImage, &to);
    CharonMPSCnnWrite(sourceImage, &from);
    CharonMPSConsumeReadCount(sourceImage);
}

@end

@implementation MPSCNNLocalContrastNormalization {
    float _alpha, _beta, _delta, _p0, _pm, _ps;
}

@synthesize alpha = _alpha;
@synthesize beta = _beta;
@synthesize delta = _delta;
@synthesize p0 = _p0;
@synthesize pm = _pm;
@synthesize ps = _ps;

- (instancetype)initWithDevice:(id<MTLDevice>)device
                 kernelWidth:(NSUInteger)kernelWidth
                kernelHeight:(NSUInteger)kernelHeight
{
    if ((self = [super initWithDevice:device])) {
        _alpha = 0.0f;
        _beta = 0.5f;
        _delta = 1.0f / 1024.0f;
        _p0 = 1.0f;
        _pm = 0.0f;
        _ps = 1.0f;
        [self charon_mps_setWindowWidth:kernelWidth height:kernelHeight
                        strideInPixelsX:1 strideInPixelsY:1 dilationRateX:1 dilationRateY:1];
    }
    return self;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                  sourceImage:(MPSImage *)sourceImage
               destinationImage:(MPSImage *)destinationImage
{
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    if (!CharonMPSCnnPairIsFloat32(sourceImage, destinationImage, @"MPSCNNLocalContrastNormalization"))
        return;

    CharonMPSCnnInterleaved from, to;
    if (!CharonMPSCnnRead(sourceImage, &from) || !CharonMPSCnnRead(destinationImage, &to)) {
        CharonMPSCnnWrite(destinationImage, &to);
        CharonMPSCnnWrite(sourceImage, &from);
        return;
    }
    size_t inChannels = from.channels, outWidth = to.width, outHeight = to.height, outChannels = to.channels;

    NSUInteger kernel = self.kernelWidth ? self.kernelWidth : 1;
    double count = (double)kernel * (double)(self.kernelHeight ? self.kernelHeight : kernel);
    double alpha = (double)_alpha, beta = (double)_beta, delta = (double)_delta;
    double p0 = (double)_p0, pm = (double)_pm, ps = (double)_ps;
    for (size_t channel = 0; channel < outChannels; channel++) {
        size_t source = channel < inChannels ? channel : inChannels - 1;
        for (size_t y = 0; y < outHeight; y++)
            for (size_t x = 0; x < outWidth; x++) {
                double sum = CharonMPSCnnWindowSum(&from, source, x, y, kernel);
                double squares = CharonMPSCnnWindowSquares(&from, source, x, y, kernel);
                double mean = sum / count;
                double variance = squares / count - mean * mean;
                double value = CharonMPSCnnValue(&from, x, y, source);
                double denominator = pow(delta + alpha * variance, beta);
                double result = denominator == 0.0 ? pm : pm + ps * (value - p0 * mean) / denominator;
                CharonMPSCnnStore(&to, x, y, channel, result);
            }
    }
    CharonMPSCnnWrite(destinationImage, &to);
    CharonMPSCnnWrite(sourceImage, &from);
    CharonMPSConsumeReadCount(sourceImage);
}

@end

@implementation MPSCNNCrossChannelNormalization {
    float _alpha, _beta, _delta;
    NSUInteger _kernelSize;
}

@synthesize alpha = _alpha;
@synthesize beta = _beta;
@synthesize delta = _delta;
@synthesize kernelSize = _kernelSize;

- (instancetype)initWithDevice:(id<MTLDevice>)device kernelSize:(NSUInteger)kernelSize
{
    if ((self = [super initWithDevice:device])) {
        _alpha = 1.0f;
        _beta = 5.0f;
        _delta = 1.0f;
        _kernelSize = kernelSize ? kernelSize : 5;
    }
    return self;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                  sourceImage:(MPSImage *)sourceImage
               destinationImage:(MPSImage *)destinationImage
{
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    if (!CharonMPSCnnPairIsFloat32(sourceImage, destinationImage, @"MPSCNNCrossChannelNormalization"))
        return;

    CharonMPSCnnInterleaved from, to;
    if (!CharonMPSCnnRead(sourceImage, &from) || !CharonMPSCnnRead(destinationImage, &to)) {
        CharonMPSCnnWrite(destinationImage, &to);
        CharonMPSCnnWrite(sourceImage, &from);
        return;
    }
    size_t inChannels = from.channels, outWidth = to.width, outHeight = to.height, outChannels = to.channels;

    size_t channels = outChannels < inChannels ? outChannels : inChannels;
    NSUInteger size = _kernelSize ? _kernelSize : 5;
    double divisor = (double)size;
    double alpha = (double)_alpha, beta = (double)_beta, delta = (double)_delta;
    for (size_t y = 0; y < outHeight; y++) {
        for (size_t x = 0; x < outWidth; x++) {
            for (size_t channel = 0; channel < channels; channel++) {
                long first = (long)channel - (long)(size / 2);
                long last = (long)channel + (long)((size - 1) / 2);
                if (first < 0)
                    first = 0;
                if (last > (long)channels - 1)
                    last = (long)channels - 1;
                double squares = 0.0;
                for (long q = first; q <= last; q++) {
                    double value = CharonMPSCnnValue(&from, x, y, (size_t)q);
                    squares += value * value;
                }
                double value = CharonMPSCnnValue(&from, x, y, channel);
                double denominator = pow(delta + alpha / divisor * squares, beta);
                double result = denominator == 0.0 ? 0.0 : value / denominator;
                CharonMPSCnnStore(&to, x, y, channel, result);
            }
        }
    }
    CharonMPSCnnWrite(destinationImage, &to);
    CharonMPSCnnWrite(sourceImage, &from);
    CharonMPSConsumeReadCount(sourceImage);
}

@end
