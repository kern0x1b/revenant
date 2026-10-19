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
    NSString *names[] = { @"MPSImage", @"MPSImageDescriptor", @"MPSUnaryImageKernel",
                          @"MPSImageLaplacian", @"MPSImageConversion", @"MPSImagePyramid",
                          @"MPSImageGaussianPyramid", @"MPSTemporaryImage" };
    for (unsigned i = 0; i < sizeof(names) / sizeof(names[0]); i++) {
        Class cls = NSClassFromString(names[i]);
        const char *image = cls ? (class_getImageName(cls) ?: "(none)") : "(absent)";
        printf("image %-30s %s\n", names[i].UTF8String, image);
        NSString *charon = [@"Charon" stringByAppendingString:names[i]];
        Class mine = NSClassFromString(charon);
        printf("image %-30s %s\n", charon.UTF8String,
               mine ? (class_getImageName(mine) ?: "(none)") : "(absent)");
    }
}

static NSUInteger gCompared = 0, gNotCompared = 0;

static BOOL portHas(const char *name)
{
#ifdef CHARON_PORT_BUILD
    return NSClassFromString([@"Charon" stringByAppendingString:[NSString stringWithUTF8String:name]]) != Nil;
#else
    (void)name;
    return YES;
#endif
}

static BOOL require_class(const char *caseName, const char *className)
{
    if (portHas(className))
        return YES;
    printf("case %-28s NOT COMPARED: the port has no %s, so this case reached the host's class on both"
           " sides and compared the host with itself\n", caseName, className);
    gNotCompared++;
    return NO;
}

static void counted(BOOL ran)
{
    if (ran)
        gCompared++;
}

static size_t strideFor(NSUInteger width)
{
    size_t row = width * sizeof(float);
    size_t aligned = ((row + 255) / 256) * 256;
    return aligned ? aligned : 256;
}

static MPSImage *make(NSUInteger w, NSUInteger h, const float *values)
{
    MPSImageDescriptor *d = [MPSImageDescriptor imageDescriptorWithChannelFormat:MPSImageFeatureChannelFormatFloat32
                                                                          width:w height:h featureChannels:1];
    MPSImage *image = [[MPSImage alloc] initWithDevice:gDevice imageDescriptor:d];
    if (values) {
        size_t stride = strideFor(w);
        float *row = calloc(stride / sizeof(float), sizeof(float));
        for (NSUInteger y = 0; y < h; y++) {
            memset(row, 0, stride);
            memcpy(row, values + y * w, w * sizeof(float));
            [[image texture] replaceRegion:MTLRegionMake2D(0, y, w, 1) mipmapLevel:0
                                 withBytes:row bytesPerRow:stride];
        }
        free(row);
    }
    return image;
}

static void dump(const char *name, MPSImage *image, NSUInteger w, NSUInteger h)
{
    size_t stride = strideFor(w);
    float *row = calloc(stride / sizeof(float), sizeof(float));
    printf("%s %zu\n", name, (size_t)(w * h));
    for (NSUInteger y = 0; y < h; y++) {
        memset(row, 0, stride);
        [[image texture] getBytes:row bytesPerRow:stride fromRegion:MTLRegionMake2D(0, y, w, 1) mipmapLevel:0];
        printf("  row%lu", (unsigned long)y);
        for (NSUInteger x = 0; x < w; x++)
            printf(" %.9g", row[x]);
        printf("\n");
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

static void laplacianCases(void)
{
    if (!require_class("laplacian", "MPSImageLaplacian") || !require_class("laplacian", "MPSImage")) {
        counted(NO);
        return;
    }
    counted(YES);
    for (int variant = 0; variant < 2; variant++) {
        MPSImage *s = make(4, 4, k4x4), *d = make(4, 4, NULL);
        MPSImageLaplacian *k = [[MPSImageLaplacian alloc] initWithDevice:gDevice];
        printf("laplacian bias=%g edgeMode=%lu\n", k.bias, (unsigned long)k.edgeMode);
        if (variant) k.bias = 1.0f;
        id<MTLCommandBuffer> b = buffer();
        [k encodeToCommandBuffer:b sourceImage:s destinationImage:d];
        run(b);
        dump(variant ? "laplacian-bias1" : "laplacian-bias0", d, 4, 4);
    }
}

static void freshImageCase(void)
{
    if (!require_class("fresh-image", "MPSImage") || !require_class("fresh-image", "MPSImageDescriptor")) {
        counted(NO);
        return;
    }
    counted(YES);
    MPSImage *fresh = make(4, 4, NULL);
    dump("fresh-image-zeroes", fresh, 4, 4);
}

static void conversionCase(void)
{
    if (!portHas("MPSImageConversion")) {
        printf("case conversion-null-info  NOT COMPARED: the port has no MPSImageConversion, which is what"
               " this row's absence says - the class needs a CGColorConversionInfoRef this port does not"
               " carry. The SYSTEM side below is the measurement: its no-op is what makes the row's claim.\n");
        gNotCompared++;
        return;
    }
    counted(YES);
    float v[4] = {1, 2, 3, 4};
    MPSImage *s = make(2, 2, v), *d = make(2, 2, NULL);
    MPSImageConversion *k = [[MPSImageConversion alloc] initWithDevice:gDevice
                                                             srcAlpha:MPSAlphaTypeAlphaIsOne
                                                            destAlpha:MPSAlphaTypeAlphaIsOne
                                                        backgroundColor:NULL
                                                         conversionInfo:NULL];
    printf("conversion-defaults sourceAlpha=%lu destinationAlpha=%lu\n",
           (unsigned long)k.sourceAlpha, (unsigned long)k.destinationAlpha);
    id<MTLCommandBuffer> b = buffer();
    [k encodeToCommandBuffer:b sourceImage:s destinationImage:d];
    run(b);
    dump("conversion-null-info", d, 2, 2);
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
        laplacianCases();
        freshImageCase();
        conversionCase();
        printf("compared: %lu cases, %lu not compared\n", (unsigned long)gCompared, (unsigned long)gNotCompared);
    }
    return 0;
}
