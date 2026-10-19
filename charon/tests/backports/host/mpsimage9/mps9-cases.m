#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#include "mps9-reference.h"
#import <objc/runtime.h>

@protocol CharonMPS9UnaryEncode
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                 sourceImage:(MPSImage *)sourceImage
            destinationImage:(MPSImage *)destinationImage;
@end

static id<MTLDevice> gDevice = nil;

static MPSImage *CharonMPS9MakeImage(const void *pixels, NSUInteger cols, NSUInteger rows,
                                     id<MTLDevice> device)
{
    MPSImageDescriptor *descriptor =
        [MPSImageDescriptor imageDescriptorWithChannelFormat:MPSImageFeatureChannelFormatFloat32
                                                    width:cols height:rows featureChannels:1];
    MPSImage *image = [[MPSImage alloc] initWithDevice:device imageDescriptor:descriptor];
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
    NSUInteger shapes[][2] = { {1, 1}, {3, 2}, {5, 5} };
    unsigned seed = 12345;
    for (NSUInteger shape = 0; shape < sizeof(shapes) / sizeof(shapes[0]); shape++) {
        NSUInteger cols = shapes[shape][0], rows = shapes[shape][1];
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
            CharonMPS9CheckIntegral(name, values, cols, rows, got, squared ? YES : NO);
            free(got);
        }

        {
            const char *name = "MPSImageSobel";
            float transform[3] = { 0.299f, 0.587f, 0.114f };
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
            CharonMPS9CheckSobel(name, values, cols, rows, got, 1, transform);
            free(got);
        }
        free(pixels);
        free(values);
    }
    const char *names[] = { "MPSImageIntegral", "MPSImageIntegralOfSquares", "MPSImageSobel" };
    Class found[] = { [MPSImageIntegral class], [MPSImageIntegralOfSquares class], [MPSImageSobel class] };
    for (NSUInteger i = 0; i < sizeof(names) / sizeof(names[0]); i++)
        printf("class %s %s\n", names[i], class_getImageName(found[i]) ?: "(none)");
    printf("COMPARED %lu  MISMATCHES %lu\n", (unsigned long)gCompared9, (unsigned long)gMismatches9);
    return gMismatches9 ? 1 : 0;
}
