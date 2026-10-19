#import <Accelerate/Accelerate.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import "check.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

vImage_Error charon_host_vImageBuffer_Init(vImage_Buffer *buf, vImagePixelCount height, vImagePixelCount width, uint32_t pixelBits, vImage_Flags flags);
vImage_Error charon_host_vImageBuffer_InitWithCGImage(vImage_Buffer *buf, vImage_CGImageFormat *format, const CGFloat *backgroundColor, CGImageRef image, vImage_Flags flags);
CGImageRef charon_host_vImageCreateCGImageFromBuffer(const vImage_Buffer *buf, const vImage_CGImageFormat *format, void (*callback)(void *userData, void *buf_data), void *userData, vImage_Flags flags, vImage_Error *error);

static CGImageRef make_image(size_t width, size_t height)
{
    size_t rowBytes = width * 4;
    uint8_t *px = malloc(rowBytes * height);
    for (size_t y = 0; y < height; y++)
        for (size_t x = 0; x < width; x++) {
            uint8_t *p = px + y * rowBytes + x * 4;
            unsigned a = (y * 61 + x * 37 + 20) % 256;
            if (x == 0 && y == 0) a = 255;
            if (x == 1 && y == 1) a = 0;
            unsigned r = (x * 71 + y * 13) % 256, g = (x * 29 + y * 97 + 40) % 256, b = (x * 3 + y * 211 + 90) % 256;
            p[0] = r * a / 255; p[1] = g * a / 255; p[2] = b * a / 255; p[3] = a;
        }
    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
    CFDataRef data = CFDataCreate(NULL, px, rowBytes * height);
    free(px);
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    CGImageRef image = CGImageCreate(width, height, 8, 32, rowBytes, rgb, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault, provider, NULL, false, kCGRenderingIntentDefault);
    CGColorSpaceRelease(rgb);
    CGDataProviderRelease(provider);
    CFRelease(data);
    return image;
}

static int max_difference(const vImage_Buffer *a, const vImage_Buffer *b, size_t bytesPerPixel)
{
    int worst = 0;
    for (size_t y = 0; y < a->height; y++)
        for (size_t x = 0; x < a->width * bytesPerPixel; x++) {
            int d = abs((int)((uint8_t *)a->data)[y * a->rowBytes + x] - (int)((uint8_t *)b->data)[y * b->rowBytes + x]);
            worst = MAX(worst, d);
        }
    return worst;
}

static int image_difference(CGImageRef a, CGImageRef b)
{
    size_t w = CGImageGetWidth(a), h = CGImageGetHeight(a);
    if (CGImageGetWidth(b) != w || CGImageGetHeight(b) != h)
        return 999;
    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
    uint8_t *pa = calloc(w * 4, h), *pb = calloc(w * 4, h);
    CGContextRef ca = CGBitmapContextCreate(pa, w, h, 8, w * 4, rgb, kCGImageAlphaPremultipliedLast);
    CGContextRef cb = CGBitmapContextCreate(pb, w, h, 8, w * 4, rgb, kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(ca, CGRectMake(0, 0, w, h), a);
    CGContextDrawImage(cb, CGRectMake(0, 0, w, h), b);
    int worst = 0;
    for (size_t i = 0; i < w * 4 * h; i++)
        worst = MAX(worst, abs((int)pa[i] - (int)pb[i]));
    CGContextRelease(ca); CGContextRelease(cb); CGColorSpaceRelease(rgb);
    free(pa); free(pb);
    return worst;
}

typedef struct {
    const char *name;
    uint32_t bpc, bpp;
    BOOL gray;
    CGBitmapInfo info;
} Format;

static void check_conversions(void)
{
    Format formats[] = {
        {"ARGB premult first", 8, 32, NO, kCGImageAlphaPremultipliedFirst},
        {"BGRA premult first 32Little", 8, 32, NO, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little},
        {"RGBA premult last", 8, 32, NO, kCGImageAlphaPremultipliedLast},
        {"ABGR premult last 32Little", 8, 32, NO, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Little},
        {"ARGB first", 8, 32, NO, kCGImageAlphaFirst},
        {"RGBA last", 8, 32, NO, kCGImageAlphaLast},
        {"BGRA first 32Little", 8, 32, NO, kCGImageAlphaFirst | kCGBitmapByteOrder32Little},
        {"xRGB skip first", 8, 32, NO, kCGImageAlphaNoneSkipFirst},
        {"RGBx skip last", 8, 32, NO, kCGImageAlphaNoneSkipLast},
        {"BGRx skip first 32Little", 8, 32, NO, kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little},
        {"RGB888", 8, 24, NO, kCGImageAlphaNone},
    };
    size_t sizes[][2] = {{2, 2}, {5, 4}, {17, 9}, {64, 3}};
    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB(), gray = CGColorSpaceCreateDeviceGray();
    CGFloat backgrounds[][3] = {{0, 0, 0}, {0.5, 0.25, 0.75}, {1, 1, 1}};
    for (size_t f = 0; f < sizeof(formats) / sizeof(*formats); f++) {
        int worstPixels = 0, worstBack = 0, mismatched = 0;
        for (size_t s = 0; s < sizeof(sizes) / sizeof(*sizes); s++) {
            CGImageRef image = make_image(sizes[s][0], sizes[s][1]);
            for (size_t b = 0; b < 3; b++) {
                vImage_CGImageFormat format = {formats[f].bpc, formats[f].bpp, formats[f].gray ? gray : rgb, formats[f].info, 0, NULL, kCGRenderingIntentDefault};
                vImage_Buffer ours = {0}, theirs = {0};
                vImage_Error e1 = charon_host_vImageBuffer_InitWithCGImage(&ours, &format, backgrounds[b], image, kvImageNoFlags);
                vImage_Error e2 = vImageBuffer_InitWithCGImage(&theirs, &format, backgrounds[b], image, kvImageNoFlags);
                if (e1 != e2) {
                    mismatched++;
                    printf("%s: errors differ %ld %ld\n", formats[f].name, (long)e1, (long)e2);
                    continue;
                }
                if (e1)
                    continue;
                if (ours.width != theirs.width || ours.height != theirs.height) {
                    mismatched++;
                    continue;
                }
                worstPixels = MAX(worstPixels, max_difference(&ours, &theirs, formats[f].bpp / 8));
                vImage_Error r1 = 0, r2 = 0;
                CGImageRef back1 = charon_host_vImageCreateCGImageFromBuffer(&theirs, &format, NULL, NULL, kvImageNoFlags, &r1);
                CGImageRef back2 = vImageCreateCGImageFromBuffer(&theirs, &format, NULL, NULL, kvImageNoFlags, &r2);
                if (r1 != r2 || !back1 != !back2) {
                    mismatched++;
                    printf("%s: image errors differ %ld %ld\n", formats[f].name, (long)r1, (long)r2);
                } else if (back1) {
                    worstBack = MAX(worstBack, image_difference(back1, back2));
                }
                if (back1) CGImageRelease(back1);
                if (back2) CGImageRelease(back2);
                free(ours.data);
                free(theirs.data);
            }
            CGImageRelease(image);
        }
        int tolerance = 1;
        char name[160];
        snprintf(name, sizeof name, "%s: pixels within %d of the system's (worst %d), the image made from them within %d (worst %d)", formats[f].name, tolerance, worstPixels, tolerance, worstBack);
        CHECK(mismatched == 0 && worstPixels <= tolerance && worstBack <= tolerance, name);
    }
    CGColorSpaceRelease(rgb);
    CGColorSpaceRelease(gray);
}

static void check_errors(void)
{
    CGImageRef image = make_image(3, 3);
    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
    vImage_CGImageFormat good = {8, 32, rgb, kCGImageAlphaPremultipliedFirst, 0, NULL, kCGRenderingIntentDefault};
    struct { const char *name; vImage_CGImageFormat format; vImage_Flags flags; } cases[6];
    memset(cases, 0, sizeof cases);
    cases[0].name = "bad bitsPerComponent"; cases[0].format = good; cases[0].format.bitsPerComponent = 3;
    cases[1].name = "bad bitsPerPixel for 8"; cases[1].format = good; cases[1].format.bitsPerPixel = 20;
    cases[2].name = "unknown bitmapInfo bit"; cases[2].format = good; cases[2].format.bitmapInfo |= 0x40000000;
    cases[3].name = "version 2"; cases[3].format = good; cases[3].format.version = 2;
    CGFloat decode[] = {0, 1, 0, 1, 0, 1, 0, 1};
    cases[4].name = "decode"; cases[4].format = good; cases[4].format.decode = decode;
    cases[5].name = "unknown flag"; cases[5].format = good; cases[5].flags = 1;
    for (int i = 0; i < 6; i++) {
        vImage_Buffer a = {0}, b = {0};
        vImage_Error ours = charon_host_vImageBuffer_InitWithCGImage(&a, &cases[i].format, NULL, image, cases[i].flags);
        vImage_Error theirs = vImageBuffer_InitWithCGImage(&b, &cases[i].format, NULL, image, cases[i].flags);
        CHECK(ours == theirs, cases[i].name);
        if (!ours) { free(a.data); free(b.data); }
    }
    vImage_Buffer x = {0}, y = {0};
    CHECK(charon_host_vImageBuffer_Init(&x, 10, 10, 32, 1) == vImageBuffer_Init(&y, 10, 10, 32, 1), "Init: an unknown flag");
    CHECK(charon_host_vImageBuffer_Init(&x, 10, 10, 32, kvImageDoNotTile) == vImageBuffer_Init(&y, 10, 10, 32, kvImageDoNotTile), "Init: DoNotTile is unknown to it");
    vImage_Error ea = charon_host_vImageBuffer_Init(&x, 10, 10, 32, kvImageNoFlags), eb = vImageBuffer_Init(&y, 10, 10, 32, kvImageNoFlags);
    CHECK(ea == eb && x.height == y.height && x.width == y.width, "Init: the size of the buffer");
    CHECK(x.rowBytes % 16 == 0 && x.rowBytes >= 40 && y.rowBytes % 16 == 0 && y.rowBytes >= 40, "Init: rowBytes is a multiple of 16 and holds a row");
    CHECK((uintptr_t)x.data % 16 == 0 && (uintptr_t)y.data % 16 == 0, "Init: the data is aligned to 16");
    free(x.data); free(y.data);
    vImage_Buffer zero1 = {0}, zero2 = {0};
    CHECK(charon_host_vImageBuffer_Init(&zero1, 0, 10, 32, 0) == vImageBuffer_Init(&zero2, 0, 10, 32, 0) && (zero1.data != NULL) == (zero2.data != NULL), "Init: a buffer of no rows");
    free(zero1.data); free(zero2.data);
    CHECK(charon_host_vImageBuffer_Init(&x, 1u << 30, 1u << 30, 32, 0) == vImageBuffer_Init(&y, 1u << 30, 1u << 30, 32, 0), "Init: an impossible size");
    CGColorSpaceRelease(rgb);
    CGImageRelease(image);
}

static void check_no_allocate(void)
{
    CGImageRef image = make_image(6, 5);
    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
    vImage_CGImageFormat format = {8, 32, rgb, kCGImageAlphaPremultipliedFirst, 0, NULL, kCGRenderingIntentDefault};
    vImage_Buffer ours = {0}, theirs = {0};
    ours.rowBytes = theirs.rowBytes = 64;
    ours.data = malloc(64 * 5);
    theirs.data = malloc(64 * 5);
    void *oursData = ours.data, *theirsData = theirs.data;
    CHECK(charon_host_vImageBuffer_InitWithCGImage(&ours, &format, NULL, image, kvImageNoAllocate) == vImageBuffer_InitWithCGImage(&theirs, &format, NULL, image, kvImageNoAllocate), "NoAllocate: the same answer");
    CHECK(ours.data == oursData && theirs.data == theirsData && ours.rowBytes == 64 && theirs.rowBytes == 64, "NoAllocate: the data and rowBytes are used as they are");
    CHECK(max_difference(&ours, &theirs, 4) <= 1, "NoAllocate: the same pixels");
    free(oursData);
    free(theirsData);
    CGColorSpaceRelease(rgb);
    CGImageRelease(image);
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        check_conversions();
        check_errors();
        check_no_allocate();
        printf("%d checks, %d failed\n", charon_checks, charon_failures);
    }
    return charon_failures;
}
