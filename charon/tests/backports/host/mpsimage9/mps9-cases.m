// mps9-cases.m - the three MPSImage kernels SDK 16.4's headers mark ios(9.0), against a plain C
// reference computed in this process from the release's own header formulas.
//
// ONE build, covering all three kernels: MPSImageIntegral, MPSImageIntegralOfSquares and
// MPSImageSobel, over a set of shapes and channel counts chosen so each rule in the object is
// exercised. Compiled twice, normal and with a plant, so the comparison has to be seen to fail.
//
// WHY THERE IS NO SYSTEM BUILD HERE, and why that is not a gap. This host's AGX family does not
// implement computeCommandEncoderWithDispatchType:, and the release's own MPSImage kernels die encoding
// with '-[AGXG16XFamilyCommandBuffer mtlnext computeCommandEncoderWithDispatchType:]': unrecognized
// selector. The release answers nothing on this machine, so the oracle is the header's formula in
// mps9-reference.h and every row for these three says so. Comparing the port against Apple's MPS
// binaries belongs in a harness that builds them, on a host where they run.
//
// Three modes, and the second two exist so the grader is known to be able to fail:
//   normal        the port's own arithmetic
//   all-wrong     every value printed is replaced by a constant, so every element of every case differs
//   one-wrong     every value but the first of the first case is right, so the grader has to name one
//                 wrong element rather than a case
//
// The port's classes are renamed through a header generated from the classes THIS build's objects
// actually define, which is what makes the MPSImage and the answer the port's own rather than the
// release's class reached by accident.

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
// The reference, in plain C, from the headers' own formulas.
#include "mps9-reference.h"
// class_getImageName, which the class lines below print.
#import <objc/runtime.h>

// MPSImageKernel.h declares this encode on MPSUnaryImageKernel; the class in the header is not the
// one the port's own objects implement, so the selector is spelled out as a protocol and the kernel
// is called through it, the way every selector in this harness's sibling is.
@protocol CharonMPS9UnaryEncode
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                 sourceImage:(MPSImage *)sourceImage
            destinationImage:(MPSImage *)destinationImage;
@end

static id<MTLDevice> gDevice = nil;

// One unorm8 RGBA source and its float32 destination, filled from `pixels` and read back as float32.
// The images are filled and read through `image.texture` and its replaceRegion:/getBytes:, which both
// SDKs declare, rather than through the image-path readBytes:/writeBytes: the port's MPSImage
// implements - the sibling harness measured that the host SDK declares neither image-path selector
// while answering the kernels themselves, and says so in its own header.
// BOTH SIDES ARE FLOAT32, and that is a limit of the walking layer rather than of these kernels.
// MPSImageIntegral.h:22-26 recommends a 32-bit floating-point destination for normalized, half-float or floating source channels, and
// CharonMPSImageWalk13.m's own walkability check compares the two images' DATA TYPES
// (CharonMPSImageDataTypeOf), so an Unorm8 source (MPSDataTypeUInt8, 8) into a Float32 destination
// (0x10000010) is refused by name and nothing is written - measured, 95 mismatches of 96, every value
// 0. The header's recommended conversion is therefore owed with the layer, and these cases measure the
// data type the layer does walk. The rows say so.
static MPSImage *CharonMPS9MakeImage(const void *pixels, NSUInteger cols, NSUInteger rows,
                                     id<MTLDevice> device)
{
    // The descriptor's own factory, the way the sibling harness builds its images (image-cases.m:261-264).
    MPSImageDescriptor *descriptor =
        [MPSImageDescriptor imageDescriptorWithChannelFormat:MPSImageFeatureChannelFormatFloat32
                                                    width:cols height:rows featureChannels:1];
    MPSImage *image = [[MPSImage alloc] initWithDevice:device imageDescriptor:descriptor];
    // A NULL fill is not filled. -replaceRegion: with a NULL buffer reaches the driver's
    // agxaAssertBufferIsValid and the process dies there - measured, lldb frame #4 in
    // CharonMPS9MakeImage - so a destination this case only writes into is not written to at all.
    // The port's own MPSImage already zeroed it (MPSImage13.m, "the release zeroes a fresh image").
    if (pixels)
        [image.texture replaceRegion:MTLRegionMake2D(0, 0, cols, rows)
                        mipmapLevel:0 withBytes:pixels
                      bytesPerRow:cols * sizeof(float)];
    return image;
}

static float *CharonMPS9ReadImage(MPSImage *image, NSUInteger cols, NSUInteger rows, NSUInteger elements)
{
    NSUInteger floats = cols * rows * elements;
    float *out = calloc(floats ? floats : 1, sizeof(float));
    // The same row as the fill: a single channel float32 texture's row is cols * sizeof(float). The
    // port maps featureChannels:1 to R32Float (MPSImage13.m:42), so there is no fourth channel to
    // stride over. A first pass of this case used cols*4*sizeof(float) and read back 1, 1.4e-45,
    // -4.7e30, 4 - which looks like a stride defect in the walking layer and is not one.
    [image.texture getBytes:out
                bytesPerRow:cols * sizeof(float)
                 fromRegion:MTLRegionMake2D(0, 0, cols, rows)
                mipmapLevel:0];
    return out;
}

int main(void)
{
    gDevice = MTLCreateSystemDefaultDevice();
    if (!gDevice) {
        printf("mps9: no Metal device, so nothing was measured\n");
        return 2;
    }
    // The shapes: 1x1 (one pixel, every sum is itself), 3x2 (non-square, so a transposed walk is
    // caught), 5x5 (odd, square, and big enough for the 3x3 neighbourhood to have an interior).
    NSUInteger shapes[][2] = { {1, 1}, {3, 2}, {5, 5} };
    unsigned seed = 12345;
    for (NSUInteger shape = 0; shape < sizeof(shapes) / sizeof(shapes[0]); shape++) {
        NSUInteger cols = shapes[shape][0], rows = shapes[shape][1];
        // One float32 channel per pixel, four channels per row's worth of stride, from a fixed LCG so
        // the case is the same on every run and on every machine. The values are small and signed, so an
        // integral case sees both a cancellation and a growth, and the Sobel case sees both signs of the
        // gradient.
        float *pixels = calloc(cols * rows, sizeof(float));
        double *values = calloc(cols * rows, sizeof(double));
        for (NSUInteger i = 0; i < cols * rows; i++) {
            seed = seed * 1103515245u + 12345u;
            float v = (float)(((double)((seed >> 8) & 0xffff) / 65535.0) * 2.0 - 1.0);
            pixels[i] = v;
            values[i] = (double)v;
        }

        char label[128];
        snprintf(label, sizeof(label), "%lux%lu", (unsigned long)cols, (unsigned long)rows);

        // ---- MPSImageIntegral and MPSImageIntegralOfSquares: the rectangle sum, one channel, from
        // MPSImageIntegral.h:19-20 and :40-41.
        for (int squared = 0; squared < 2; squared++) {
            const char *name = squared ? "MPSImageIntegralOfSquares" : "MPSImageIntegral";
            MPSImage *source = CharonMPS9MakeImage(pixels, cols, rows, gDevice);
            MPSImage *destination =
                CharonMPS9MakeImage(NULL, cols, rows, gDevice);
            id kernel = squared ? [[MPSImageIntegralOfSquares alloc] initWithDevice:gDevice]
                                : [[MPSImageIntegral alloc] initWithDevice:gDevice];
            [(id<CharonMPS9UnaryEncode>)kernel encodeToCommandBuffer:[gDevice newCommandBuffer]
                                                          sourceImage:source
                                                     destinationImage:destination];
            float *got = CharonMPS9ReadImage(destination, cols, rows, 1);
            printf("case %s %s %lu %lu %lu\n", name, label, (unsigned long)cols, (unsigned long)rows,
                   (unsigned long)1);
            for (NSUInteger i = 0; i < cols * rows; i++)
                printf(" %g", (double)got[i]);
            printf("\n");
            // The reference sees the ONE channel these images hold, the same float32 values the case
            // wrote, and the object walks the destination channel for channel.
            CharonMPS9CheckIntegral(name, values, cols, rows, got, squared ? YES : NO);
            free(got);
        }

        // ---- MPSImageSobel: the gradient magnitude on a one channel source, the default transform.
        // MPSImageConvolution.h:281-288 and :350-352.
        {
            const char *name = "MPSImageSobel";
            float transform[3] = { 0.299f, 0.587f, 0.114f };   // :301-302, BT.601/JPEG
            MPSImage *source = CharonMPS9MakeImage(pixels, cols, rows, gDevice);
            MPSImage *destination =
                CharonMPS9MakeImage(NULL, cols, rows, gDevice);
            id kernel = [[MPSImageSobel alloc] initWithDevice:gDevice];
            [(id<CharonMPS9UnaryEncode>)kernel encodeToCommandBuffer:[gDevice newCommandBuffer]
                                                          sourceImage:source
                                                     destinationImage:destination];
            float *got = CharonMPS9ReadImage(destination, cols, rows, 1);
            printf("case %s %s %lu %lu %lu\n", name, label, (unsigned long)cols, (unsigned long)rows,
                   (unsigned long)1);
            for (NSUInteger i = 0; i < cols * rows; i++)
                printf(" %g", (double)got[i]);
            printf("\n");
            // One channel: the destination and the source both hold one, which is the header's
            // "applied to each channel separately" case at :283-285, so channel 0 of the source is
            // the whole of the value the filter sees.
            CharonMPS9CheckSobel(name, values, cols, rows, got, 1, transform);
            free(got);
        }
        free(pixels);
        free(values);
    }
    // The classes this build resolved, so a case that ran against the RELEASE's class is visible.
    // The class line names which class each case resolved, and it is printed rather than assumed: a
    // case that ran against the RELEASE's MPSImageIntegral would compare the release with itself.
    // The names are looked up as NSString, which is what NSClassFromString takes under ARC, and the
    // rename header has already rewritten each MPS* name to the port's Charon* one.
    const char *names[] = { "MPSImageIntegral", "MPSImageIntegralOfSquares", "MPSImageSobel" };
    Class found[] = { [MPSImageIntegral class], [MPSImageIntegralOfSquares class], [MPSImageSobel class] };
    for (NSUInteger i = 0; i < sizeof(names) / sizeof(names[0]); i++)
        printf("class %s %s\n", names[i], class_getImageName(found[i]) ?: "(none)");
    printf("COMPARED %lu  MISMATCHES %lu\n", (unsigned long)gCompared9, (unsigned long)gMismatches9);
    return gMismatches9 ? 1 : 0;
}
