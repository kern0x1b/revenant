#import <CoreGraphics/CoreGraphics.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreML/CoreML.h>
#import <Foundation/Foundation.h>
#import <Vision/Vision.h>

#include <dlfcn.h>
#include <stdint.h>

#ifdef CHARON_PORT_BUILD
#import <Vision/Vision.h>
#import "CharonVisionImage.h"
#endif

static CGImageRef picture(size_t wide, size_t high)
{
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
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
    return (CVPixelBufferRef)CVPixelBufferRetain(value.imageBufferValue);
}

#ifdef CHARON_PORT_BUILD
static CVPixelBufferRef port_answer(CGImageRef image, size_t wide, size_t high, VNImageCropAndScaleOption option)
{
    CVPixelBufferRef source = charon_vision_buffer_of_image(image);
    CVPixelBufferRef answer;
    if (source == NULL) {
        return NULL;
    }
    answer = charon_vision_pixels(source, wide, high, option);
    CVPixelBufferRelease(source);
    return answer;
}
#endif

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
