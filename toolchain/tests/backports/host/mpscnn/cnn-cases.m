#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

static id<MTLDevice> gDevice;

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
        NSString *revenant = [@"Revenant" stringByAppendingString:names[i]];
        Class mine = NSClassFromString(revenant);
        const char *where = mine ? (class_getImageName(mine) ?: "(none)") : "(absent)";
        printf("image %-38s %s\n", revenant.UTF8String, where);
    }
}

static BOOL portHas(const char *name)
{
#ifdef REVENANT_PORT_BUILD
    NSString *revenant = [@"Revenant" stringByAppendingString:[NSString stringWithUTF8String:name]];
    return NSClassFromString(revenant) != Nil;
#else
    (void)name;
    return YES;
#endif
}

static NSUInteger gCompared = 0, gNotCompared = 0;

static BOOL require(const char *caseName, const char *className)
{
    if (portHas(className))
        return YES;
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
