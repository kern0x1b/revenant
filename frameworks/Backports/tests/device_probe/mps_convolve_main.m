#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

static NSMutableString *REVENANT_LOG;
static NSUInteger REVENANT_FAILURES;

static void revenant_check(BOOL ok, NSString *name)
{
    if (!ok)
        REVENANT_FAILURES++;
    [REVENANT_LOG appendFormat:@"%@ %@\n", ok ? @"PASS" : @"FAIL", name];
}

static uint8_t revenant_value(NSUInteger x, NSUInteger y, NSUInteger c)
{
    return (uint8_t)((x * 7 + y * 13 + c * 31) % 256);
}

static int revenant_box(NSUInteger width, NSUInteger height, NSUInteger x, NSUInteger y, NSUInteger c)
{
    int total = 0;
    for (long dy = -1; dy <= 1; dy++)
        for (long dx = -1; dx <= 1; dx++) {
            long sx = (long)x + dx, sy = (long)y + dy;
            if (sx >= 0 && sx < (long)width && sy >= 0 && sy < (long)height)
                total += revenant_value((NSUInteger)sx, (NSUInteger)sy, c);
        }
    return (total + 4) / 9;
}

static MPSImage *revenant_image(id<MTLDevice> device, NSUInteger width, NSUInteger height, MPSImageFeatureChannelFormat format)
{
    MPSImageDescriptor *descriptor = [MPSImageDescriptor imageDescriptorWithChannelFormat:format width:width height:height featureChannels:4];
    return [[MPSImage alloc] initWithDevice:device imageDescriptor:descriptor];
}

static void revenant_upload(MPSImage *image, NSUInteger width, NSUInteger height, BOOL pattern, uint8_t fill)
{
    uint8_t *bytes = malloc(width * height * 4);
    for (NSUInteger y = 0; y < height; y++)
        for (NSUInteger x = 0; x < width; x++)
            for (NSUInteger c = 0; c < 4; c++)
                bytes[(y * width + x) * 4 + c] = pattern ? revenant_value(x, y, c) : fill;
    [image.texture replaceRegion:MTLRegionMake2D(0, 0, width, height) mipmapLevel:0 withBytes:bytes bytesPerRow:width * 4];
    free(bytes);
}

static uint8_t *revenant_download(MPSImage *image, NSUInteger width, NSUInteger height)
{
    uint8_t *bytes = malloc(width * height * 4);
    [image.texture getBytes:bytes bytesPerRow:width * 4 fromRegion:MTLRegionMake2D(0, 0, width, height) mipmapLevel:0];
    return bytes;
}

static MPSImageConvolution *revenant_kernel(id<MTLDevice> device, NSUInteger width, NSUInteger height, const float *weights, float bias)
{
    MPSImageConvolution *kernel = [[MPSImageConvolution alloc] initWithDevice:device kernelWidth:width kernelHeight:height weights:weights];
    kernel.bias = bias;
    kernel.edgeMode = MPSImageEdgeModeZero;
    return kernel;
}

static void revenant_run(id<MTLDevice> device, MPSUnaryImageKernel *kernel, MPSImage *source, MPSImage *destination)
{
    id<MTLCommandBuffer> buffer = [[device newCommandQueue] commandBuffer];
    [kernel encodeToCommandBuffer:buffer sourceImage:source destinationImage:destination];
    [buffer commit];
    [buffer waitUntilCompleted];
}

static NSUInteger revenant_mismatches(const uint8_t *bytes, NSUInteger width, NSUInteger height, int (^expected)(NSUInteger x, NSUInteger y, NSUInteger c))
{
    NSUInteger bad = 0;
    for (NSUInteger y = 0; y < height; y++)
        for (NSUInteger x = 0; x < width; x++)
            for (NSUInteger c = 0; c < 4; c++)
                if (abs((int)bytes[(y * width + x) * 4 + c] - expected(x, y, c)) > 1)
                    bad++;
    return bad;
}

static void revenant_expect_on(id<MTLDevice> device, NSString *name, MPSUnaryImageKernel *kernel, NSUInteger width, NSUInteger height,
                               int (^expected)(NSUInteger x, NSUInteger y, NSUInteger c))
{
    MPSImage *source = revenant_image(device, width, height, MPSImageFeatureChannelFormatUnorm8);
    MPSImage *destination = revenant_image(device, width, height, MPSImageFeatureChannelFormatUnorm8);
    revenant_upload(source, width, height, YES, 0);
    revenant_upload(destination, width, height, NO, 77);
    revenant_run(device, kernel, source, destination);
    uint8_t *bytes = revenant_download(destination, width, height);
    revenant_check(revenant_mismatches(bytes, width, height, expected) == 0, name);
    free(bytes);
}

static void revenant_expect(id<MTLDevice> device, NSString *name, const float *weights, NSUInteger kernelWidth, NSUInteger kernelHeight,
                            float bias, NSUInteger width, NSUInteger height, int (^expected)(NSUInteger x, NSUInteger y, NSUInteger c))
{
    revenant_expect_on(device, name, revenant_kernel(device, kernelWidth, kernelHeight, weights, bias), width, height, expected);
}

static void revenant_convolution_checks(id<MTLDevice> device)
{
    const NSUInteger w = 4, h = 4;
    const float shift[9] = {0, 0, 0, 1, 0, 0, 0, 0, 0};
    const float box[9] = {1.0f / 9, 1.0f / 9, 1.0f / 9, 1.0f / 9, 1.0f / 9, 1.0f / 9, 1.0f / 9, 1.0f / 9, 1.0f / 9};
    const float one[1] = {0.5f};
    const float doubled[1] = {2.0f};

    revenant_expect(device, @"k_shift: a one-tap kernel reads the texel to its left, and the left edge reads zero",
                    shift, 3, 3, 0, w, h, ^int(NSUInteger x, NSUInteger y, NSUInteger c) {
                        return x == 0 ? 0 : revenant_value(x - 1, y, c);
                    });
    revenant_expect(device, @"box 3x3 over a 4x4 image averages the window, with zeros outside the image",
                    box, 3, 3, 0, w, h, ^int(NSUInteger x, NSUInteger y, NSUInteger c) {
                        return revenant_box(w, h, x, y, c);
                    });
    revenant_expect(device, @"a 1x1 weight of 0.5 with bias 0.25 gives 0.5 x + 0.25, rounded",
                    one, 1, 1, 0.25f, w, h, ^int(NSUInteger x, NSUInteger y, NSUInteger c) {
                        int e = (int)floor(0.5 * revenant_value(x, y, c) + 63.75 + 0.5);
                        return e > 255 ? 255 : e;
                    });
    revenant_expect(device, @"a 1x1 weight of 2 saturates at 255, as an RGBA8 target does",
                    doubled, 1, 1, 0, w, h, ^int(NSUInteger x, NSUInteger y, NSUInteger c) {
                        int e = 2 * revenant_value(x, y, c);
                        return e > 255 ? 255 : e;
                    });
    revenant_expect(device, @"box 3x3 over a 1000x600 image matches at every texel, so the texel coordinates are exact",
                    box, 3, 3, 0, 1000, 600, ^int(NSUInteger x, NSUInteger y, NSUInteger c) {
                        return revenant_box(1000, 600, x, y, c);
                    });

    MPSImage *source = revenant_image(device, w, h, MPSImageFeatureChannelFormatUnorm8);
    MPSImage *destination = revenant_image(device, w, h, MPSImageFeatureChannelFormatUnorm8);
    revenant_upload(source, w, h, YES, 0);
    revenant_upload(destination, w, h, NO, 77);
    MPSImageConvolution *clipped = revenant_kernel(device, 3, 3, box, 0);
    clipped.clipRect = MTLRegionMake2D(1, 1, 2, 2);
    revenant_run(device, clipped, source, destination);
    uint8_t *bytes = revenant_download(destination, w, h);
    revenant_check(revenant_mismatches(bytes, w, h, ^int(NSUInteger x, NSUInteger y, NSUInteger c) {
        BOOL inside = x >= 1 && x < 3 && y >= 1 && y < 3;
        return inside ? revenant_box(w, h, x, y, c) : 77;
    }) == 0, @"a clip rect at (1,1) of 2x2 writes only its texels and leaves the rest at 77");
    free(bytes);

    MPSImageBox *boxKernel = [[MPSImageBox alloc] initWithDevice:device kernelWidth:3 kernelHeight:3];
    boxKernel.edgeMode = MPSImageEdgeModeZero;
    revenant_expect_on(device, @"MPSImageBox 3x3 averages the window like the box convolution", boxKernel, w, h, ^int(NSUInteger x, NSUInteger y, NSUInteger c) {
        return revenant_box(w, h, x, y, c);
    });

    MPSImageLaplacian *laplacian = [[MPSImageLaplacian alloc] initWithDevice:device];
    laplacian.edgeMode = MPSImageEdgeModeZero;
    revenant_expect_on(device, @"MPSImageLaplacian gives the four-neighbour sum minus four times the centre, clamped at zero", laplacian, w, h, ^int(NSUInteger x, NSUInteger y, NSUInteger c) {
        int total = -4 * (int)revenant_value(x, y, c);
        if (x > 0)
            total += revenant_value(x - 1, y, c);
        if (x + 1 < w)
            total += revenant_value(x + 1, y, c);
        if (y > 0)
            total += revenant_value(x, y - 1, c);
        if (y + 1 < h)
            total += revenant_value(x, y + 1, c);
        return total < 0 ? 0 : (total > 255 ? 255 : total);
    });
}

int main(int argc, char *argv[])
{
    @autoreleasepool {
        REVENANT_LOG = [NSMutableString string];
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        revenant_check(device != nil, @"MTLCreateSystemDefaultDevice returns a device");
        if (device)
            revenant_convolution_checks(device);
        [REVENANT_LOG appendFormat:@"REVENANT-DONE failures %lu\n", (unsigned long)REVENANT_FAILURES];
        [REVENANT_LOG writeToFile:@"/var/revenant/mps-convolve-probe.txt" atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        printf("%s", [REVENANT_LOG UTF8String]);
        return REVENANT_FAILURES ? 1 : 0;
    }
}
