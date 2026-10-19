/* crop.m -- the crop-and-scale rules against Core ML's own image constructor, pixel for pixel.
 *
 * The port's request path brings a handler's picture to the size a model declares
 * (CharonVisionImage.h). The oracle for how Core ML does that is Core ML's own image constructor,
 * which is what facts/Vision/Vision.md cites: the same CGImage, the same target size, the two
 * CVPixelBuffers compared byte for byte. One program, built twice -- once against the framework's
 * own resampler and once against the port's, which is compiled with the rest of the library under
 * names of its own by the harness -- so the only thing that differs between the two answers is
 * which resampler produced the pixels.
 *
 * Every case prints `differing=N of M`, and the harness fails the run if any N is not zero.
 */
#import <CoreGraphics/CoreGraphics.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreML/CoreML.h>
#import <Foundation/Foundation.h>
#import <Vision/Vision.h>

#include <dlfcn.h>
#include <stdint.h>

#ifdef CHARON_PORT_BUILD
#import <Vision/Vision.h>
/* The port's two functions, the header's interpolation left at its default. */
#import "CharonVisionImage.h"
#endif

/* A picture with structure rather than a flat colour, so a resampler that is off by a row or a
 * channel shows up: a left-to-right red ramp crossed with a top-to-bottom green one, with the blue
 * channel carrying a diagonal, which a paste and a blend cannot both reproduce. */
static CGImageRef picture(size_t wide, size_t high)
{
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    /* 32 bits a pixel in the same order as the target format: a 24-bit image has no alpha and
     * Core ML's own constructor refuses to make a buffer of one ("Failed to form pixel buffer from
     * CGImage"), which is the same reason the port's buffer helper draws with the same order. */
    CGContextRef context = CGBitmapContextCreate(NULL, wide, high, 8, 0, space,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Little);
    CGImageRef image = NULL;
    size_t x, y;
    CGColorSpaceRelease(space);
    if (context == NULL) {
        return NULL;
    }
    for (y = 0; y < high; y++) {
        for (x = 0; x < wide; x++) {
            CGContextSetRGBFillColor(context, (CGFloat)x / (CGFloat)(wide > 0 ? wide : 1),
                                     (CGFloat)y / (CGFloat)(high > 0 ? high : 1),
                                     (CGFloat)((x + y) % 7) / 7.0, 1.0);
            CGContextFillRect(context, CGRectMake((CGFloat)x, (CGFloat)y, 1, 1));
        }
    }
    image = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    return image;
}

/* Core ML's own constructor, which is the oracle: it takes the picture, the size to bring it to and
 * the options, and answers a buffer. */
/* Core ML's own constructor takes a VNImageCropAndScaleOption under the CropAndScale key -- the
 * header of the key says it describes how an image is cropped and scaled to a desired size, including any region of interest, so the oracle for each rule is the same rule handed
 * over, and the row is a comparison of like with like. A negative option asks for the *default*,
 * which the header does not state; the run measures it and prints it. */
static CVPixelBufferRef oracle(CGImageRef image, size_t wide, size_t high, int option)
{
    NSError *failure = nil;
    NSDictionary *options = option < 0 ? @{} : @{ MLFeatureValueImageOptionCropAndScale : @(option) };
    MLFeatureValue *value = [MLFeatureValue featureValueWithCGImage:image
                                                       pixelsWide:wide
                                                       pixelsHigh:high
                                                  pixelFormatType:kCVPixelFormatType_32BGRA
                                                          options:options
                                                            error:&failure];
    if (value == nil) {
        fprintf(stderr, "the oracle refused: %s\n", failure.localizedDescription.UTF8String);
        return NULL;
    }
    /* Retained: the value that held it is a local here and is gone when this returns, and a
     * buffer that is read afterwards has to have outlived its owner. */
    return (CVPixelBufferRef)CVPixelBufferRetain(value.imageBufferValue);
}

#ifdef CHARON_PORT_BUILD
/* The port's own: a picture into a buffer, then that buffer brought to the size with the option. */
static CVPixelBufferRef port_answer(CGImageRef image, size_t wide, size_t high, VNImageCropAndScaleOption option)
{
    CVPixelBufferRef source = charon_vision_buffer_of_image(image);
    CVPixelBufferRef answer;
    if (source == NULL) {
        return NULL;
    }
    answer = charon_vision_pixels(source, wide, high, option);
    CVPixelBufferRelease(source);
    /* The same: charon_vision_pixels answers a buffer it made, and the caller owns it. */
    return answer;
}
#endif

/* Byte for byte, over the whole of the buffer: four bytes a pixel, which is what both sides are
 * asked for (kCVPixelFormatType_32BGRA) and so what the comparison can be over. */
static long differing(CVPixelBufferRef want, CVPixelBufferRef got, size_t *of)
{
    long different = 0;
    size_t index, count = 0;
    const uint8_t *a, *b;
    if (want == NULL || got == NULL) {
        *of = 0;
        return -1;
    }
    if (CVPixelBufferGetWidth(want) != CVPixelBufferGetWidth(got) ||
        CVPixelBufferGetHeight(want) != CVPixelBufferGetHeight(got)) {
        *of = 0;
        return -1;
    }
    CVPixelBufferLockBaseAddress(want, kCVPixelBufferLock_ReadOnly);
    CVPixelBufferLockBaseAddress(got, kCVPixelBufferLock_ReadOnly);
    a = (const uint8_t *)CVPixelBufferGetBaseAddress(want);
    b = (const uint8_t *)CVPixelBufferGetBaseAddress(got);
    for (index = 0; index < CVPixelBufferGetBytesPerRow(want) * CVPixelBufferGetHeight(want); index += 4) {
        if (a[index] != b[index] || a[index + 1] != b[index + 1] || a[index + 2] != b[index + 2] ||
            a[index + 3] != b[index + 3]) {
            different++;
        }
        count++;
    }
    CVPixelBufferUnlockBaseAddress(want, kCVPixelBufferLock_ReadOnly);
    CVPixelBufferUnlockBaseAddress(got, kCVPixelBufferLock_ReadOnly);
    *of = count;
    return different;
}

/* Three pixels of a buffer, as raw bytes: the origin, the middle and the far corner, beside the
 * buffer's own pixel format and row length. Three pixels are enough to tell a vertical flip from a
 * channel order from a row's padding, which is what a "nearly every pixel differs" is. */
static void dump(CVPixelBufferRef buffer, const char *who)
{
    size_t wide = CVPixelBufferGetWidth(buffer), high = CVPixelBufferGetHeight(buffer);
    size_t stride = CVPixelBufferGetBytesPerRow(buffer);
    size_t points[3][2] = {{0, 0}, {wide / 2, high / 2}, {wide - 1, high - 1}};
    int index;
    printf("%s: format=%u bytesPerRow=%lu size=%zux%zu", who, (unsigned)CVPixelBufferGetPixelFormatType(buffer),
           (unsigned long)stride, wide, high);
    for (index = 0; index < 3; index++) {
        const uint8_t *row = (const uint8_t *)CVPixelBufferGetBaseAddress(buffer) + points[index][1] * stride;
        printf(" | (%zu,%zu) %02x %02x %02x %02x", points[index][0], points[index][1], row[points[index][0] * 4],
               row[points[index][0] * 4 + 1], row[points[index][0] * 4 + 2], row[points[index][0] * 4 + 3]);
    }
    printf("\n");
}

/* Which image each answer came out of. The framework's answer is Core ML's own constructor; the
 * port's is the kernel in CharonVisionBilinear.c. If both resolve to the same image the comparison
 * is the framework against itself and every row reads zero, which is what happened once. */
static const char *image_of(const void *address, char *into, size_t size)
{
    Dl_info info;
    if (dladdr(address, &info) != 0 && info.dli_fname != NULL) {
        const char *at = strrchr(info.dli_fname, '/');
        snprintf(into, size, "%s", at != NULL ? at + 1 : info.dli_fname);
        return into;
    }
    snprintf(into, size, "(unknown)");
    return into;
}

int main(int argc, const char *argv[])
{
    /* the two options this port carries, and the sizes: the review's two, an exact 1:1, and an
     * integer 2x, which is the one where a fractional scale does not arise at all. */
    struct {
        size_t from_wide, from_high, to_wide, to_high;
    } sizes[] = {{100, 50, 224, 224}, {13, 7, 8, 8}, {16, 16, 16, 16}, {8, 8, 16, 16}, {4, 7, 33, 9}};
    size_t index;
    long worst = 0;

    @autoreleasepool {
#ifdef CHARON_PORT_BUILD
        {
            char kernel[256], framework[256];
            image_of((const void *)(uintptr_t)&charon_vision_bilinear, kernel, sizeof kernel);
            image_of((__bridge void *)NSClassFromString(@"MLFeatureValue"), framework, sizeof framework);
            printf("=== the two answers come from: the port's %s and the framework's %s\n", kernel, framework);
            if (strcmp(kernel, framework) == 0) {
                printf("BOTH SIDES ARE THE SAME IMAGE: this comparison is the framework against "
                       "itself and every row below reads zero by construction\n");
                return 2;
            }
        }
#else
        {
            char framework[256];
            image_of((const void *)(__bridge void *)NSClassFromString(@"MLFeatureValue"), framework, sizeof framework);
            printf("=== the system's own rows: both sides are %s, so they are a control, not a "
                   "verdict\n", framework);
        }
#endif
        for (index = 0; index < sizeof(sizes) / sizeof(sizes[0]); index++) {
            CGImageRef image = picture(sizes[index].from_wide, sizes[index].from_high);
            int option;
            for (option = 0; option < 2; option++) {
                CVPixelBufferRef want = oracle(image, sizes[index].to_wide, sizes[index].to_high,
                                               option == 0 ? VNImageCropAndScaleOptionCenterCrop
                                                           : VNImageCropAndScaleOptionScaleFit);
#ifdef CHARON_PORT_BUILD
                CVPixelBufferRef got = port_answer(image, sizes[index].to_wide, sizes[index].to_high,
                                                    option == 0 ? VNImageCropAndScaleOptionCenterCrop
                                                               : VNImageCropAndScaleOptionScaleFit);
#else
                CVPixelBufferRef got = oracle(image, sizes[index].to_wide, sizes[index].to_high, YES);
                (void)option;
#endif
                size_t of = 0;
                long difference = differing(want, got, &of);

                printf("%zux%zu to %zux%zu option %s: differing=%ld of %zu\n", sizes[index].from_wide,
                       sizes[index].from_high, sizes[index].to_wide, sizes[index].to_high,
                       option == 0 ? "centrecrop" : "scalefit", difference, of);
                if (index == 0) {
                    CVPixelBufferLockBaseAddress(want, kCVPixelBufferLock_ReadOnly);
                    CVPixelBufferLockBaseAddress(got, kCVPixelBufferLock_ReadOnly);
                    dump(want, "coreML");
                    dump(got, "port  ");
                    CVPixelBufferUnlockBaseAddress(want, kCVPixelBufferLock_ReadOnly);
                    CVPixelBufferUnlockBaseAddress(got, kCVPixelBufferLock_ReadOnly);
                }
                if (difference > worst) {
                    worst = difference;
                }
                if (want != NULL) {
                    CVPixelBufferRelease(want);
                }
                if (got != NULL) {
                    CVPixelBufferRelease(got);
                }
            }
            CGImageRelease(image);
        }
    }
    (void)argc;
    (void)argv;
    /* The default the header does not state: the same picture with no option in the dictionary. */
    {
        CGImageRef image = picture(100, 50);
        CVPixelBufferRef want = oracle(image, 224, 224, -1);
        CVPixelBufferRef fit = oracle(image, 224, 224, VNImageCropAndScaleOptionScaleFit);
        CVPixelBufferRef crop = oracle(image, 224, 224, VNImageCropAndScaleOptionCenterCrop);
        size_t ofFit = 0, ofCrop = 0;
        long againstFit = differing(want, fit, &ofFit);
        long againstCrop = differing(want, crop, &ofCrop);
        printf("no option given: the framework's own answer is %ld of %zu pixels from ScaleFit and "
               "%ld of %zu from CenterCrop, so its default is %s\n",
               againstFit, ofFit, againstCrop, ofCrop,
               againstFit == 0 ? "ScaleFit" : (againstCrop == 0 ? "CenterCrop" : "neither, exactly"));
        if (want != NULL) CVPixelBufferRelease(want);
        if (fit != NULL) CVPixelBufferRelease(fit);
        if (crop != NULL) CVPixelBufferRelease(crop);
        CGImageRelease(image);
    }
    printf("worst differing pixels: %ld\n", worst);
    return worst == 0 ? 0 : 1;
}
