#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static id<MTLDevice> gDevice;
static id<MTLCommandQueue> gQueue;

static void printClassImages(void)
{
    NSString *names[] = {
        @"MPSCNNKernel", @"MPSCNNNeuron", @"MPSCNNNeuronLinear", @"MPSCNNNeuronReLU",
        @"MPSCNNNeuronSigmoid", @"MPSCNNNeuronTanH", @"MPSCNNNeuronAbsolute",
        @"MPSCNNSoftMax", @"MPSCNNLogSoftMax", @"MPSCNNSpatialNormalization",
        @"MPSCNNLocalContrastNormalization", @"MPSCNNCrossChannelNormalization",
    };
    for (unsigned i = 0; i < sizeof(names) / sizeof(names[0]); i++) {
        Class cls = NSClassFromString(names[i]);
        const char *image = cls ? (class_getImageName(cls) ?: "(none)") : "(absent)";
        printf("image %-38s %s\n", names[i].UTF8String, image);
        NSString *charon = [@"Charon" stringByAppendingString:names[i]];
        Class mine = NSClassFromString(charon);
        const char *where = mine ? (class_getImageName(mine) ?: "(none)") : "(absent)";
        printf("image %-38s %s\n", charon.UTF8String, where);
    }
}

static BOOL portHas(const char *name)
{
#ifdef CHARON_PORT_BUILD
    NSString *charon = [@"Charon" stringByAppendingString:[NSString stringWithUTF8String:name]];
    return NSClassFromString(charon) != Nil;
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

static NSUInteger valuesPerPixelOf(id<MTLTexture> t)
{
    switch (t.pixelFormat) {
    case MTLPixelFormatR32Float: return 1;
    case MTLPixelFormatRG32Float: return 2;
    case MTLPixelFormatRGBA32Float: return 4;
    default: return 4;
    }
}

static size_t strideFor(NSUInteger width, NSUInteger valuesPerPixel)
{
    size_t row = width * valuesPerPixel * sizeof(float);
    size_t aligned = ((row + 255) / 256) * 256;
    return aligned ? aligned : 256;
}

static MPSImage *make(NSUInteger w, NSUInteger h, NSUInteger channels, const float *planes)
{
    MPSImageDescriptor *d = [MPSImageDescriptor imageDescriptorWithChannelFormat:MPSImageFeatureChannelFormatFloat32
                                                                          width:w height:h featureChannels:channels];
    MPSImage *image = [[MPSImage alloc] initWithDevice:gDevice imageDescriptor:d];
    if (planes) {
        NSUInteger perPixel = valuesPerPixelOf(image.texture);
        size_t stride = strideFor(w, perPixel);
        float *row = calloc(stride / sizeof(float), sizeof(float));
        for (NSUInteger y = 0; y < h; y++) {
            memset(row, 0, stride);
            for (NSUInteger x = 0; x < w; x++)
                for (NSUInteger ch = 0; ch < channels && ch < perPixel; ch++)
                    row[x * perPixel + ch] = planes[ch * w * h + y * w + x];
            [[image texture] replaceRegion:MTLRegionMake2D(0, (NSUInteger)y, w, 1) mipmapLevel:0
                                 withBytes:row bytesPerRow:stride];
        }
        free(row);
    }
    return image;
}

static void dump(const char *name, MPSImage *image, NSUInteger w, NSUInteger h, NSUInteger channels)
{
    NSUInteger perPixel = valuesPerPixelOf(image.texture);
    size_t stride = strideFor(w, perPixel);
    float *row = calloc(stride / sizeof(float), sizeof(float));
    printf("%s %zu\n", name, (size_t)(w * h * channels));
    for (NSUInteger y = 0; y < h; y++) {
        memset(row, 0, stride);
        [[image texture] getBytes:row bytesPerRow:stride
                        fromRegion:MTLRegionMake2D(0, (NSUInteger)y, w, 1) mipmapLevel:0];
        for (NSUInteger ch = 0; ch < channels && ch < perPixel; ch++) {
            printf("  ch%lu row%lu", (unsigned long)ch, (unsigned long)y);
            for (NSUInteger x = 0; x < w; x++)
                printf(" %.9g", row[x * perPixel + ch]);
            printf("\n");
        }
    }
    free(row);
}

static id<MTLCommandBuffer> buffer(void)
{
    return [gQueue commandBufferWithUnretainedReferences];
}

static void run(id<MTLCommandBuffer> b)
{
    [b commit];
    [b waitUntilCompleted];
    if (b.error)
        printf("   buffer error: %s\n", [[b.error description] UTF8String]);
}

static const float k4x4[16] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16};
static const float kNeg[16] = {-8, -7, -6, -5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5, 6, 7};
static const float k2ch[32] = {
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
    2, 1, 4, 3, 6, 5, 8, 7, 10, 9, 12, 11, 14, 13, 16, 15,
};
static const float k4ch[64] = {
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
    2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32,
    5, 1, 5, 1, 5, 1, 5, 1, 5, 1, 5, 1, 5, 1, 5, 1,
    16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1,
};

static void neuronCases(void)
{
    if (!require("neuron-relu", "MPSCNNNeuronReLU") || !require("neuron-relu", "MPSImage") ||
        !require("neuron-relu", "MPSImageDescriptor")) {
        counted(NO);
        return;
    }
    counted(YES);
    {
        MPSImage *s = make(4, 4, 1, k4x4), *d = make(4, 4, 1, NULL);
        MPSCNNNeuronReLU *k = [[MPSCNNNeuronReLU alloc] initWithDevice:gDevice a:0.0f];
        printf("relu-defaults a=%g b=%g c=%g\n", k.a, k.b, k.c);
        id<MTLCommandBuffer> b = buffer();
        [k encodeToCommandBuffer:b sourceImage:s destinationImage:d];
        run(b);
        dump("neuron-relu-a0-positive", d, 4, 4, 1);
    }
    {
        MPSImage *s = make(4, 4, 1, kNeg), *d = make(4, 4, 1, NULL);
        MPSCNNNeuronReLU *k = [[MPSCNNNeuronReLU alloc] initWithDevice:gDevice a:0.0f];
        id<MTLCommandBuffer> b = buffer();
        [k encodeToCommandBuffer:b sourceImage:s destinationImage:d];
        run(b);
        dump("neuron-relu-a0-negative", d, 4, 4, 1);
    }
    {
        MPSImage *s = make(4, 4, 1, kNeg), *d = make(4, 4, 1, NULL);
        MPSCNNNeuronReLU *k = [[MPSCNNNeuronReLU alloc] initWithDevice:gDevice a:0.25f];
        id<MTLCommandBuffer> b = buffer();
        [k encodeToCommandBuffer:b sourceImage:s destinationImage:d];
        run(b);
        dump("neuron-relu-a0.25-negative", d, 4, 4, 1);
    }
}

static void neuronRestCases(void)
{
    if (!require("neuron-rest", "MPSCNNNeuronLinear") || !require("neuron-rest", "MPSCNNNeuronSigmoid") ||
        !require("neuron-rest", "MPSCNNNeuronTanH") || !require("neuron-rest", "MPSCNNNeuronAbsolute")) {
        counted(NO);
        return;
    }
    counted(YES);
    {
        MPSImage *s = make(4, 4, 1, k4x4), *d = make(4, 4, 1, NULL);
        MPSCNNNeuronLinear *k = [[MPSCNNNeuronLinear alloc] initWithDevice:gDevice a:2.0f b:0.5f];
        id<MTLCommandBuffer> b = buffer();
        [k encodeToCommandBuffer:b sourceImage:s destinationImage:d];
        run(b);
        dump("neuron-linear-a2-b0.5", d, 4, 4, 1);
    }
    {
        MPSImage *s = make(4, 4, 1, k4x4), *d = make(4, 4, 1, NULL);
        MPSCNNNeuronSigmoid *k = [[MPSCNNNeuronSigmoid alloc] initWithDevice:gDevice];
        id<MTLCommandBuffer> b = buffer();
        [k encodeToCommandBuffer:b sourceImage:s destinationImage:d];
        run(b);
        dump("neuron-sigmoid", d, 4, 4, 1);
    }
    {
        MPSImage *s = make(4, 4, 1, k4x4), *d = make(4, 4, 1, NULL);
        MPSCNNNeuronTanH *k = [[MPSCNNNeuronTanH alloc] initWithDevice:gDevice a:1.0f b:1.0f];
        id<MTLCommandBuffer> b = buffer();
        [k encodeToCommandBuffer:b sourceImage:s destinationImage:d];
        run(b);
        dump("neuron-tanh-a1-b1", d, 4, 4, 1);
    }
    {
        MPSImage *s = make(4, 4, 1, k4x4), *d = make(4, 4, 1, NULL);
        MPSCNNNeuronTanH *k = [[MPSCNNNeuronTanH alloc] initWithDevice:gDevice a:3.0f b:0.5f];
        id<MTLCommandBuffer> b = buffer();
        [k encodeToCommandBuffer:b sourceImage:s destinationImage:d];
        run(b);
        dump("neuron-tanh-a3-b0.5", d, 4, 4, 1);
    }
    {
        MPSImage *s = make(4, 4, 1, kNeg), *d = make(4, 4, 1, NULL);
        MPSCNNNeuronAbsolute *k = [[MPSCNNNeuronAbsolute alloc] initWithDevice:gDevice];
        id<MTLCommandBuffer> b = buffer();
        [k encodeToCommandBuffer:b sourceImage:s destinationImage:d];
        run(b);
        dump("neuron-absolute-negative", d, 4, 4, 1);
    }
}

static void softMaxCases(void)
{
    if (!require("softmax", "MPSCNNSoftMax") || !require("logsoftmax", "MPSCNNLogSoftMax")) {
        counted(NO);
        return;
    }
    counted(YES);
    {
        MPSImage *s = make(4, 4, 2, k2ch), *d = make(4, 4, 2, NULL);
        MPSCNNSoftMax *k = [[MPSCNNSoftMax alloc] initWithDevice:gDevice];
        id<MTLCommandBuffer> b = buffer();
        [k encodeToCommandBuffer:b sourceImage:s destinationImage:d];
        run(b);
        dump("cnn-softmax", d, 4, 4, 2);
    }
    {
        MPSImage *s = make(4, 4, 2, k2ch), *d = make(4, 4, 2, NULL);
        MPSCNNLogSoftMax *k = [[MPSCNNLogSoftMax alloc] initWithDevice:gDevice];
        id<MTLCommandBuffer> b = buffer();
        [k encodeToCommandBuffer:b sourceImage:s destinationImage:d];
        run(b);
        dump("cnn-logsoftmax", d, 4, 4, 2);
    }
    {
        MPSImage *s = make(4, 4, 4, k4ch), *d = make(4, 4, 4, NULL);
        MPSCNNSoftMax *k = [[MPSCNNSoftMax alloc] initWithDevice:gDevice];
        id<MTLCommandBuffer> b = buffer();
        [k encodeToCommandBuffer:b sourceImage:s destinationImage:d];
        run(b);
        dump("cnn-softmax-4ch", d, 4, 4, 4);
    }
}

static void normalizationCases(void)
{
    if (!require("spatial", "MPSCNNSpatialNormalization")) {
        counted(NO);
    } else {
        counted(YES);
        {
            MPSImage *s = make(4, 4, 1, k4x4), *d = make(4, 4, 1, NULL);
            MPSCNNSpatialNormalization *k = [[MPSCNNSpatialNormalization alloc] initWithDevice:gDevice
                                                                                   kernelWidth:3 kernelHeight:3];
            printf("spatial-defaults alpha=%g beta=%g delta=%g kw=%lu kh=%lu\n", k.alpha, k.beta, k.delta,
                   (unsigned long)k.kernelWidth, (unsigned long)k.kernelHeight);
            id<MTLCommandBuffer> b = buffer();
            [k encodeToCommandBuffer:b sourceImage:s destinationImage:d];
            run(b);
            dump("spatial-norm-defaults", d, 4, 4, 1);
        }
        {
            MPSImage *s = make(4, 4, 1, k4x4), *d = make(4, 4, 1, NULL);
            MPSCNNSpatialNormalization *k = [[MPSCNNSpatialNormalization alloc] initWithDevice:gDevice
                                                                                   kernelWidth:2 kernelHeight:2];
            printf("spatial-k2 kw=%lu kh=%lu\n", (unsigned long)k.kernelWidth, (unsigned long)k.kernelHeight);
            id<MTLCommandBuffer> b = buffer();
            [k encodeToCommandBuffer:b sourceImage:s destinationImage:d];
            run(b);
            dump("spatial-norm-k2", d, 4, 4, 1);
        }
        {
            MPSImage *s = make(4, 4, 1, k4x4), *d = make(4, 4, 1, NULL);
            MPSCNNSpatialNormalization *k = [[MPSCNNSpatialNormalization alloc] initWithDevice:gDevice
                                                                                   kernelWidth:3 kernelHeight:3];
            id<MTLCommandBuffer> b = buffer();
            [k encodeToCommandBuffer:b sourceImage:s destinationImage:d];
            run(b);
            dump("spatial-norm-k3", d, 4, 4, 1);
        }
        {
            MPSImage *s = make(4, 4, 1, k4x4), *d = make(4, 4, 1, NULL);
            MPSCNNSpatialNormalization *k = [[MPSCNNSpatialNormalization alloc] initWithDevice:gDevice
                                                                                   kernelWidth:5 kernelHeight:5];
            printf("spatial-k5 kw=%lu kh=%lu\n", (unsigned long)k.kernelWidth, (unsigned long)k.kernelHeight);
            id<MTLCommandBuffer> b = buffer();
            [k encodeToCommandBuffer:b sourceImage:s destinationImage:d];
            run(b);
            dump("spatial-norm-k5", d, 4, 4, 1);
        }
    }
    if (!require("local-contrast", "MPSCNNLocalContrastNormalization")) {
        counted(NO);
    } else {
        counted(YES);
        {
            MPSImage *s = make(4, 4, 1, k4x4), *d = make(4, 4, 1, NULL);
            MPSCNNLocalContrastNormalization *k = [[MPSCNNLocalContrastNormalization alloc] initWithDevice:gDevice
                                                                                                     kernelWidth:3 kernelHeight:3];
            printf("localcontrast-defaults alpha=%g beta=%g delta=%g p0=%g pm=%g ps=%g\n",
                   k.alpha, k.beta, k.delta, k.p0, k.pm, k.ps);
            id<MTLCommandBuffer> b = buffer();
            [k encodeToCommandBuffer:b sourceImage:s destinationImage:d];
            run(b);
            dump("local-contrast-defaults", d, 4, 4, 1);
        }
        {
            MPSImage *s = make(4, 4, 1, k4x4), *d = make(4, 4, 1, NULL);
            MPSCNNLocalContrastNormalization *k = [[MPSCNNLocalContrastNormalization alloc] initWithDevice:gDevice
                                                                                                     kernelWidth:3 kernelHeight:3];
            k.alpha = 1.0f;
            id<MTLCommandBuffer> b = buffer();
            [k encodeToCommandBuffer:b sourceImage:s destinationImage:d];
            run(b);
            dump("local-contrast-alpha1", d, 4, 4, 1);
        }
    }
    if (!require("cross-channel", "MPSCNNCrossChannelNormalization")) {
        counted(NO);
        return;
    }
    counted(YES);
    {
        MPSImage *s = make(4, 4, 4, k4ch), *d = make(4, 4, 4, NULL);
        MPSCNNCrossChannelNormalization *k = [[MPSCNNCrossChannelNormalization alloc] initWithDevice:gDevice kernelSize:3];
        printf("crosschannel-defaults alpha=%g beta=%g delta=%g kernelSize=%lu\n",
               k.alpha, k.beta, k.delta, (unsigned long)k.kernelSize);
        id<MTLCommandBuffer> b = buffer();
        [k encodeToCommandBuffer:b sourceImage:s destinationImage:d];
        run(b);
        dump("cross-channel-k3", d, 4, 4, 4);
    }
    {
        MPSImage *s = make(4, 4, 4, k4ch), *d = make(4, 4, 4, NULL);
        MPSCNNCrossChannelNormalization *k = [[MPSCNNCrossChannelNormalization alloc] initWithDevice:gDevice kernelSize:1];
        printf("crosschannel-k1 kernelSize=%lu\n", (unsigned long)k.kernelSize);
        id<MTLCommandBuffer> b = buffer();
        [k encodeToCommandBuffer:b sourceImage:s destinationImage:d];
        run(b);
        dump("cross-channel-k1", d, 4, 4, 4);
    }
}

int main(void)
{
    @autoreleasepool {
        setbuf(stdout, NULL);
        gDevice = MTLCreateSystemDefaultDevice();
        if (!gDevice) { printf("no device\n"); return 1; }
        gQueue = [gDevice newCommandQueue];
        printf("device %s\n", [[gDevice name] UTF8String]);
        printClassImages();
        neuronCases();
        neuronRestCases();
        softMaxCases();
        normalizationCases();
        printf("compared: %lu cases, %lu not compared\n", (unsigned long)gCompared, (unsigned long)gNotCompared);
        if (gCompared == 0) {
            printf("this run compared nothing: every case needs a class the port does not have, and a run"
                   " that compared nothing is not a pass\n");
            return 1;
        }
        if (gNotCompared) {
            printf("this run compared %lu cases and left %lu uncompared; the uncompared ones are named"
                   " above and are not passes\n", (unsigned long)gCompared, (unsigned long)gNotCompared);
            return 1;
        }
    }
    return 0;
}
