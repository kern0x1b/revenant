// cnn-cases.m — the convolutional kernels, run twice: once against the system's own MPS and once
// against this port's classes under names of their own. Every case prints the bytes of a result the
// case owns, so the two runs are compared exactly for the results that are exact, and against a
// written-down float tolerance for the ones that are not.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

static id<MTLDevice> gDevice;

// Which image every compared class came out of, printed before anything else. A class of the port's
// with the same name as one of the host's is registered once, and a message sent to it reaches whichever
// loaded first - so the comparison says which that was, on every run, rather than leaving it to be
// inferred from a number that came out wrong.
static void printClassImages(void)
{
    NSString *names[] = {
        @"MPSKernel", @"MPSCNNKernel", @"MPSCNNPooling", @"MPSCNNPoolingAverage", @"MPSCNNPoolingMax",
        @"MPSCNNConvolution", @"MPSCNNConvolutionDescriptor", @"MPSCNNConvolutionWeightsAndBiasesState",
        @"MPSCNNBatchNormalization", @"MPSState", @"MPSStateResourceList", @"MPSPredicate", @"MPSCommandBuffer",
        @"MPSImage", @"MPSImageDescriptor", @"MPSMatrix", @"MPSVector",
    };
    for (unsigned i = 0; i < sizeof(names) / sizeof(names[0]); i++) {
        Class cls = NSClassFromString(names[i]);
        const char *image = cls ? (class_getImageName(cls) ?: "(none)") : "(absent)";
        printf("image %-38s %s\n", names[i].UTF8String, image);
        // And the name the port's own copy is registered under, which is what the cases call: if it is
        // absent, the cases reached the host's class and the comparison is not a comparison.
        NSString *charon = [@"Charon" stringByAppendingString:names[i]];
        Class mine = NSClassFromString(charon);
        const char *where = mine ? (class_getImageName(mine) ?: "(none)") : "(absent)";
        printf("image %-38s %s\n", charon.UTF8String, where);
    }
}

// Whether the port has its own copy of a class, under the name the rename header gives it. The
// rename header is generated from the classes the port's objects define, so a class the port does not
// implement is not renamed and the case reaches the host's class instead - which means the case
// compares the host's implementation with the host's implementation and says nothing about this port
// on that class. It is a check that examined nothing, and it has to fail rather than pass quietly.
static BOOL portHas(const char *name)
{
#ifdef CHARON_PORT_BUILD
    NSString *charon = [@"Charon" stringByAppendingString:[NSString stringWithUTF8String:name]];
    return NSClassFromString(charon) != Nil;
#else
    (void)name;
    // The system build links the release's own classes and has no port to ask about, so the question
    // is not asked on that side. The guard is a claim about the port's build, and the port's transcript
    // is the one that carries it; the comparison fails when the port's side has an uncompared case.
    return YES;
#endif
}

// A case that ran, a case that did not, and why not. Every case checks the classes it builds from
// before it builds them, and a case that cannot is named and counted rather than compared.
static NSUInteger gCompared = 0, gNotCompared = 0;

static BOOL require(const char *caseName, const char *className)
{
    if (portHas(className))
        return YES;
    // printed once per (case, class) pair, with the count, so a run that compared nothing says so
    static NSMutableSet *said = nil;
    if (!said) said = [NSMutableSet set];
    NSString *key = [NSString stringWithFormat:@"%s|%s", caseName, className];
    if (![said containsObject:key]) {
        [said addObject:key];
        printf("case %-28s NOT COMPARED: the port has no %s, so this case reached the host's class"
               " on both sides and compared the host with itself\n", caseName, className);
    }
    gNotCompared++;
    return NO;
}

static void counted(BOOL ran)
{
    if (ran)
        gCompared++;
}

static void put(const char *name, const void *bytes, size_t count, size_t element)
{
    printf("%s %zu\n", name, count);
    const float *values = (const float *)bytes;
    for (size_t i = 0; i < count; i++)
        printf("%s%.9g", i ? " " : "", (double)values[i]);
    (void)element;
    printf("\n");
}

// A 3x3 single precision image, and the plane its values live in.
static MPSImage *image3x3(const float *values)
{
    MPSImageDescriptor *descriptor = [MPSImageDescriptor imageDescriptorWithChannelFormat:MPSImageFeatureChannelFormatFloat32
                                                                                       width:3 height:3 featureChannels:1];
    MPSImage *image = [[MPSImage alloc] initWithDevice:gDevice imageDescriptor:descriptor];
    [[image texture] replaceRegion:MTLRegionMake2D(0, 0, 3, 3) mipmapLevel:0 withBytes:values bytesPerRow:3 * sizeof(float)];
    return image;
}

static float sSource[9] = {1, 2, 3, 4, 5, 6, 7, 8, 9};

static void casesPooling(void)
{
    // The average: a 3x3 window over a 3x3 image with the zero edge mode, so the corner windows hang
    // half outside. The answer says what the divisor is.
    //
    // Every case below builds its source and destination as an MPSImage through an MPSImageDescriptor,
    // so all three of these have to be the port's own or the case is not a comparison of this port.
    if (!require("pooling", "MPSImage") || !require("pooling", "MPSImageDescriptor") ||
        !require("pooling", "MPSCNNPoolingAverage") || !require("pooling", "MPSCNNPoolingMax")) {
        counted(NO);
        return;
    }
    counted(YES);
    for (NSUInteger pad = 0; pad < 2; pad++) {
        MPSImage *source = image3x3(sSource);
        MPSImageDescriptor *descriptor = [MPSImageDescriptor imageDescriptorWithChannelFormat:MPSImageFeatureChannelFormatFloat32
                                                                                       width:3 height:3 featureChannels:1];
        MPSImage *destination = [[MPSImage alloc] initWithDevice:gDevice imageDescriptor:descriptor];
        MPSCNNPoolingAverage *kernel = [[MPSCNNPoolingAverage alloc] initWithDevice:gDevice kernelWidth:3 kernelHeight:3
                                                                     strideInPixelsX:1 strideInPixelsY:1];
        kernel.edgeMode = MPSImageEdgeModeZero;
        if (pad) { kernel.zeroPadSizeX = 1; kernel.zeroPadSizeY = 1; }
        id<MTLCommandQueue> queue = [gDevice newCommandQueue];
        id<MTLCommandBuffer> buffer = [queue commandBufferWithUnretainedReferences];
        [kernel encodeToCommandBuffer:buffer sourceImage:source destinationImage:destination];
        [buffer commit];
        [buffer waitUntilCompleted];
        float out[9] = {0};
        [[destination texture] getBytes:out bytesPerRow:3 * sizeof(float) fromRegion:MTLRegionMake2D(0, 0, 3, 3) mipmapLevel:0];
        char name[64];
        snprintf(name, sizeof(name), "pooling-average-pad%lu", (unsigned long)pad);
        put(name, out, 9, sizeof(float));
    }
    // The maximum, same window.
    {
        MPSImage *source = image3x3(sSource);
        MPSImageDescriptor *descriptor = [MPSImageDescriptor imageDescriptorWithChannelFormat:MPSImageFeatureChannelFormatFloat32
                                                                                       width:3 height:3 featureChannels:1];
        MPSImage *destination = [[MPSImage alloc] initWithDevice:gDevice imageDescriptor:descriptor];
        MPSCNNPoolingMax *kernel = [[MPSCNNPoolingMax alloc] initWithDevice:gDevice kernelWidth:3 kernelHeight:3
                                                                   strideInPixelsX:1 strideInPixelsY:1];
        kernel.edgeMode = MPSImageEdgeModeZero;
        id<MTLCommandQueue> queue = [gDevice newCommandQueue];
        id<MTLCommandBuffer> buffer = [queue commandBufferWithUnretainedReferences];
        [kernel encodeToCommandBuffer:buffer sourceImage:source destinationImage:destination];
        [buffer commit];
        [buffer waitUntilCompleted];
        float out[9] = {0};
        [[destination texture] getBytes:out bytesPerRow:3 * sizeof(float) fromRegion:MTLRegionMake2D(0, 0, 3, 3) mipmapLevel:0];
        put("pooling-max", out, 9, sizeof(float));
    }
    // A 2x2 window with a stride of one, which has no window hanging outside: the divisor is
    // unambiguous there and pins the rule the corner case only suggests.
    {
        float s[9] = {1, 2, 3, 4, 5, 6, 7, 8, 9};
        MPSImage *source = image3x3(s);
        MPSImageDescriptor *descriptor = [MPSImageDescriptor imageDescriptorWithChannelFormat:MPSImageFeatureChannelFormatFloat32
                                                                                       width:2 height:2 featureChannels:1];
        MPSImage *destination = [[MPSImage alloc] initWithDevice:gDevice imageDescriptor:descriptor];
        MPSCNNPoolingAverage *kernel = [[MPSCNNPoolingAverage alloc] initWithDevice:gDevice kernelWidth:2 kernelHeight:2
                                                                     strideInPixelsX:1 strideInPixelsY:1];
        id<MTLCommandQueue> queue = [gDevice newCommandQueue];
        id<MTLCommandBuffer> buffer = [queue commandBufferWithUnretainedReferences];
        [kernel encodeToCommandBuffer:buffer sourceImage:source destinationImage:destination];
        [buffer commit];
        [buffer waitUntilCompleted];
        float out[4] = {0};
        [[destination texture] getBytes:out bytesPerRow:2 * sizeof(float) fromRegion:MTLRegionMake2D(0, 0, 2, 2) mipmapLevel:0];
        put("pooling-average-2x2", out, 4, sizeof(float));
    }
}

// A data source over the four per-channel arrays batch normalisation folds.
@interface TestDataSource : NSObject <MPSCNNBatchNormalizationDataSource>
@end
@implementation TestDataSource {
    float *_gamma, *_beta, *_mean, *_variance;
    NSUInteger _channels;
}
- (instancetype)initWithChannels:(NSUInteger)channels
{
    if ((self = [super init])) {
        _channels = channels;
        _gamma = (float *)calloc(channels, sizeof(float));
        _beta = (float *)calloc(channels, sizeof(float));
        _mean = (float *)calloc(channels, sizeof(float));
        _variance = (float *)calloc(channels, sizeof(float));
    }
    return self;
}
- (void)setGamma:(const float *)v { memcpy(_gamma, v, _channels * sizeof(float)); }
- (void)setBeta:(const float *)v { memcpy(_beta, v, _channels * sizeof(float)); }
- (void)setMean:(const float *)v { memcpy(_mean, v, _channels * sizeof(float)); }
- (void)setVariance:(const float *)v { memcpy(_variance, v, _channels * sizeof(float)); }
- (NSUInteger)numberOfFeatureChannels { return _channels; }
- (float *)gamma { return _gamma; }
- (float *)beta { return _beta; }
- (float *)mean { return _mean; }
- (float *)variance { return _variance; }
- (BOOL)load { return YES; }
- (void)purge {}
- (id)copyWithZone:(NSZone *)zone { return self; }
@end

static void casesBatchNormalization(void)
{
    if (!require("batch-normalization", "MPSImage") || !require("batch-normalization", "MPSImageDescriptor") ||
        !require("batch-normalization", "MPSCNNBatchNormalization")) {
        counted(NO);
        return;
    }
    counted(YES);
    float s[9] = {1, 2, 3, 4, 5, 6, 7, 8, 9};
    float gamma[1] = {2.0f}, beta[1] = {0.5f}, mean[1] = {4.0f}, variance[1] = {1.5f};
    TestDataSource *source = [[TestDataSource alloc] initWithChannels:1];
    [source setGamma:gamma]; [source setBeta:beta]; [source setMean:mean]; [source setVariance:variance];
    MPSImage *input = image3x3(s);
    MPSImageDescriptor *descriptor = [MPSImageDescriptor imageDescriptorWithChannelFormat:MPSImageFeatureChannelFormatFloat32
                                                                                       width:3 height:3 featureChannels:1];
    MPSImage *destination = [[MPSImage alloc] initWithDevice:gDevice imageDescriptor:descriptor];
    MPSCNNBatchNormalization *kernel = [[MPSCNNBatchNormalization alloc] initWithDevice:gDevice dataSource:source];
    kernel.epsilon = 0.25f;
    id<MTLCommandQueue> queue = [gDevice newCommandQueue];
    id<MTLCommandBuffer> buffer = [queue commandBufferWithUnretainedReferences];
    [kernel encodeToCommandBuffer:buffer sourceImage:input destinationImage:destination];
    [buffer commit];
    [buffer waitUntilCompleted];
    float out[9] = {0};
    [[destination texture] getBytes:out bytesPerRow:3 * sizeof(float) fromRegion:MTLRegionMake2D(0, 0, 3, 3) mipmapLevel:0];
    put("batch-normalization", out, 9, sizeof(float));
}

// A fresh image, read before anything has written to it.
//
// Every other case writes its image and then reads it, so none of them can see what a fresh image
// holds, and a port that left a fresh image with whatever its texture carried would pass all five. This
// one makes no image hold a written value at all: it builds one and reads it straight back, and the
// answer both sides must give is zeros - the release's fresh images are zeros, and this port's are,
// because MPSImage13.m zeroes a texture it made. A mutant that fills that buffer with 0xA5 instead of
// asking for zeros is the deterministic form of "left with whatever it held", and this case is what
// notices it.
static void casesFreshImage(void)
{
    if (!require("fresh-image", "MPSImage") || !require("fresh-image", "MPSImageDescriptor")) {
        counted(NO);
        return;
    }
    counted(YES);
    MPSImageDescriptor *descriptor = [MPSImageDescriptor imageDescriptorWithChannelFormat:MPSImageFeatureChannelFormatFloat32
                                                                                       width:3 height:3 featureChannels:1];
    MPSImage *fresh = [[MPSImage alloc] initWithDevice:gDevice imageDescriptor:descriptor];
    float out[9] = {0};
    [[fresh texture] getBytes:out bytesPerRow:3 * sizeof(float) fromRegion:MTLRegionMake2D(0, 0, 3, 3) mipmapLevel:0];
    put("fresh-image", out, 9, sizeof(float));
}

int main(void)
{
    @autoreleasepool {
        gDevice = MTLCreateSystemDefaultDevice();
        if (!gDevice) { printf("no device\n"); return 1; }
        printClassImages();
        casesPooling();
        casesBatchNormalization();
        casesFreshImage();
        printf("compared: %lu cases, %lu not compared\n", (unsigned long)gCompared, (unsigned long)gNotCompared);
        if (gCompared == 0) {
            printf("this run compared nothing: every case needs a class the port does not have, and a run"
                   " that compared nothing is not a pass\n");
            return 1;
        }
        if (gNotCompared) {
            printf("this run compared %lu cases and left %lu uncompared; the uncompared ones are named above"
                   " and are not passes\n", (unsigned long)gCompared, (unsigned long)gNotCompared);
            return 1;
        }
    }
    return 0;
}
