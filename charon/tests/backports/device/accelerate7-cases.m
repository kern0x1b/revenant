#import <Accelerate/Accelerate.h>
#import <CoreGraphics/CoreGraphics.h>
#import "accelerate7-cases.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wimplicit-enum-enum-cast"

static CGImageRef make_image(size_t width, size_t height)
{
    size_t rowBytes = width * 4;
    uint8_t *px = malloc(rowBytes * height);
    for (size_t y = 0; y < height; y++)
        for (size_t x = 0; x < width; x++) {
            uint8_t *p = px + y * rowBytes + x * 4;
            unsigned a = (y * 61 + x * 37 + 20) % 256;
            if (x == 0 && y == 0)
                a = 255;
            if (x == 1 && y == 1)
                a = 0;
            unsigned r = (x * 71 + y * 13) % 256, g = (x * 29 + y * 97 + 40) % 256, b = (x * 3 + y * 211 + 90) % 256;
            p[0] = r * a / 255;
            p[1] = g * a / 255;
            p[2] = b * a / 255;
            p[3] = a;
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

static NSString *bytes_of(const vImage_Buffer *buffer, size_t bytesPerPixel)
{
    NSMutableString *digest = [NSMutableString string];
    for (size_t y = 0; y < buffer->height; y++) {
        for (size_t x = 0; x < buffer->width * bytesPerPixel; x++)
            [digest appendFormat:@"%d,", ((uint8_t *)buffer->data)[y * buffer->rowBytes + x]];
        [digest appendString:@"|"];
    }
    return digest;
}

static NSString *rendered(CGImageRef image)
{
    size_t width = CGImageGetWidth(image), height = CGImageGetHeight(image);
    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
    uint8_t *pixels = calloc(width * 4, height);
    CGContextRef context = CGBitmapContextCreate(pixels, width, height, 8, width * 4, rgb, kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
    NSMutableString *digest = [NSMutableString string];
    for (size_t i = 0; i < width * 4 * height; i++)
        [digest appendFormat:@"%d,", pixels[i]];
    CGContextRelease(context);
    CGColorSpaceRelease(rgb);
    free(pixels);
    return digest;
}

typedef struct {
    const char *name;
    uint32_t bpc, bpp;
    BOOL gray;
    CGBitmapInfo info;
} Format;

void charon_vimage_cases(void (^emit)(NSString *name, NSString *value))
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
    size_t sizes[][2] = {{2, 2}, {5, 4}, {17, 9}};
    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB(), gray = CGColorSpaceCreateDeviceGray();
    CGFloat backgrounds[][3] = {{0, 0, 0}, {0.5, 0.25, 0.75}};
    for (size_t f = 0; f < sizeof(formats) / sizeof(*formats); f++)
        for (size_t s = 0; s < sizeof(sizes) / sizeof(*sizes); s++) {
            CGImageRef image = make_image(sizes[s][0], sizes[s][1]);
            for (size_t b = 0; b < 2; b++) {
                vImage_CGImageFormat format = {formats[f].bpc, formats[f].bpp, formats[f].gray ? gray : rgb, formats[f].info, 0, NULL, kCGRenderingIntentDefault};
                vImage_Buffer buffer = {0};
                vImage_Error error = vImageBuffer_InitWithCGImage(&buffer, &format, backgrounds[b], image, kvImageNoFlags);
                NSString *name = [NSString stringWithFormat:@"%s %zux%zu bg%zu", formats[f].name, sizes[s][0], sizes[s][1], b];
                emit([name stringByAppendingString:@" error"], [NSString stringWithFormat:@"%ld", (long)error]);
                if (error)
                    continue;
                emit([name stringByAppendingString:@" pixels"], bytes_of(&buffer, formats[f].bpp / 8));
                vImage_Error made = 0;
                CGImageRef back = vImageCreateCGImageFromBuffer(&buffer, &format, NULL, NULL, kvImageNoFlags, &made);
                emit([name stringByAppendingString:@" image error"], [NSString stringWithFormat:@"%ld", (long)made]);
                if (back) {
                    emit([name stringByAppendingString:@" image"], rendered(back));
                    CGImageRelease(back);
                }
                free(buffer.data);
            }
            CGImageRelease(image);
        }
    CGImageRef image = make_image(3, 3);
    vImage_CGImageFormat good = {8, 32, rgb, kCGImageAlphaPremultipliedFirst, 0, NULL, kCGRenderingIntentDefault};
    vImage_CGImageFormat cases[4];
    for (int i = 0; i < 4; i++)
        cases[i] = good;
    cases[0].bitsPerComponent = 3;
    cases[1].bitsPerPixel = 20;
    cases[2].bitmapInfo |= 0x40000000;
    cases[3].version = 2;
    for (int i = 0; i < 4; i++) {
        vImage_Buffer buffer = {0};
        emit([NSString stringWithFormat:@"format error %d", i], [NSString stringWithFormat:@"%ld", (long)vImageBuffer_InitWithCGImage(&buffer, &cases[i], NULL, image, kvImageNoFlags)]);
    }
    vImage_Buffer buffer = {0};
    emit(@"flags error", [NSString stringWithFormat:@"%ld", (long)vImageBuffer_InitWithCGImage(&buffer, &good, NULL, image, kvImageDoNotTile)]);
    emit(@"init flags", [NSString stringWithFormat:@"%ld", (long)vImageBuffer_Init(&buffer, 10, 10, 32, 1)]);
    emit(@"init impossible", [NSString stringWithFormat:@"%ld", (long)vImageBuffer_Init(&buffer, 1u << 30, 1u << 30, 32, 0)]);
    CGImageRelease(image);
    CGColorSpaceRelease(rgb);
    CGColorSpaceRelease(gray);
}
