#import <Accelerate/Accelerate.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>   // BOOL, which the 4.3 include chain does not reach on its own
#include <stdlib.h>
#include <string.h>

#pragma clang diagnostic ignored "-Wnonnull"
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

typedef struct {
    int channels;
    int alphaAt;
    int red;
    int green;
    int blue;
    BOOL premultiplied;
} charon_layout;

static unsigned charon_clamp(unsigned value)
{
    return value > 255 ? 255 : value;
}

static BOOL charon_known_flags(vImage_Flags flags, vImage_Flags allowed)
{
    return (flags & ~allowed) == 0;
}

static vImage_Error charon_check_format(const vImage_CGImageFormat *format, charon_layout *layout)
{
    if (format->version != 0)
        return kvImageInvalidImageFormat;
    switch (format->bitsPerComponent) {
    case 0: case 1: case 2: case 4: case 5: case 8: case 16: case 32:
        break;
    default:
        return kvImageInvalidParameter;
    }
    if (format->bitmapInfo & ~(CGBitmapInfo)0x7F1F)
        return kvImageInvalidParameter;
    CGBitmapInfo alpha = format->bitmapInfo & kCGBitmapAlphaInfoMask;
    CGBitmapInfo order = format->bitmapInfo & kCGBitmapByteOrderMask;
    if (format->bitsPerComponent != 8 || (format->bitmapInfo & kCGBitmapFloatInfoMask))
        return kvImageInvalidImageFormat;
    if (format->colorSpace && CGColorSpaceGetModel(format->colorSpace) != kCGColorSpaceModelRGB)
        return kvImageInvalidImageFormat;
    memset(layout, 0, sizeof(*layout));
    if (format->bitsPerPixel == 24) {
        if (alpha != kCGImageAlphaNone || order != kCGBitmapByteOrderDefault)
            return kvImageInvalidImageFormat;
        layout->channels = 3;
        layout->alphaAt = -1;
        layout->red = 0;
        layout->green = 1;
        layout->blue = 2;
        return kvImageNoError;
    }
    if (format->bitsPerPixel != 32 || (order != kCGBitmapByteOrderDefault && order != kCGBitmapByteOrder32Big && order != kCGBitmapByteOrder32Little))
        return kvImageInvalidImageFormat;
    BOOL first = alpha == kCGImageAlphaPremultipliedFirst || alpha == kCGImageAlphaFirst || alpha == kCGImageAlphaNoneSkipFirst;
    BOOL last = alpha == kCGImageAlphaPremultipliedLast || alpha == kCGImageAlphaLast || alpha == kCGImageAlphaNoneSkipLast;
    if (!first && !last)
        return kvImageInvalidImageFormat;
    layout->channels = 4;
    layout->premultiplied = alpha == kCGImageAlphaPremultipliedFirst || alpha == kCGImageAlphaPremultipliedLast;
    int a = first ? 0 : 3, r = first ? 1 : 0, g = first ? 2 : 1, b = first ? 3 : 2;
    if (order == kCGBitmapByteOrder32Little) {
        a = 3 - a;
        r = 3 - r;
        g = 3 - g;
        b = 3 - b;
    }
    layout->alphaAt = a;
    layout->red = r;
    layout->green = g;
    layout->blue = b;
    return kvImageNoError;
}

static CGColorSpaceRef charon_space(const vImage_CGImageFormat *format)
{
    if (format->colorSpace)
        return CGColorSpaceRetain(format->colorSpace);
    return CGColorSpaceCreateDeviceRGB();
}

vImage_Error vImageBuffer_InitWithCGImage(vImage_Buffer *buf, vImage_CGImageFormat *format, const CGFloat *backgroundColor, CGImageRef image, vImage_Flags flags)
{
    if (!format || !image)
        return kvImageNullPointerArgument;
    if (!charon_known_flags(flags, kvImageNoAllocate | kvImagePrintDiagnosticsToConsole))
        return kvImageUnknownFlagsBit;
    charon_layout layout;
    vImage_Error status = charon_check_format(format, &layout);
    if (status != kvImageNoError)
        return status;
    size_t width = CGImageGetWidth(image), height = CGImageGetHeight(image);
    size_t bytesPerPixel = format->bitsPerPixel / 8;
    if (!(flags & kvImageNoAllocate)) {
        vImage_Buffer fresh = {0};
        status = vImageBuffer_Init(&fresh, height, width, format->bitsPerPixel, kvImageNoFlags);
        if (status != kvImageNoError) {
            buf->data = NULL;
            return status;
        }
        *buf = fresh;
    } else {
        buf->height = height;
        buf->width = width;
    }
    CGColorSpaceRef space = charon_space(format);
    size_t stride = width * 4;
    uint8_t *scratch = calloc(stride * (height ? height : 1), 1);
    CGContextRef context = CGBitmapContextCreate(scratch, width, height, 8, stride, space, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault);
    CGColorSpaceRelease(space);
    if (!context) {
        free(scratch);
        if (!(flags & kvImageNoAllocate)) {
            free(buf->data);
            buf->data = NULL;
        }
        return kvImageInvalidImageFormat;
    }
    if (layout.alphaAt < 0) {
        CGContextSetRGBFillColor(context, backgroundColor ? backgroundColor[0] : 0, backgroundColor ? backgroundColor[1] : 0, backgroundColor ? backgroundColor[2] : 0, 1);
        CGContextFillRect(context, CGRectMake(0, 0, width, height));
    }
    CGContextSetBlendMode(context, kCGBlendModeNormal);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
    CGContextRelease(context);
    uint8_t *out = buf->data;
    for (size_t y = 0; y < height; y++) {
        uint8_t *row = out + y * buf->rowBytes;
        const uint8_t *source = scratch + y * stride;
        for (size_t x = 0; x < width; x++) {
            uint8_t r = source[x * 4], g = source[x * 4 + 1], b = source[x * 4 + 2], a = source[x * 4 + 3];
            uint8_t *pixel = row + x * bytesPerPixel;
            if (layout.channels == 3) {
                pixel[0] = r;
                pixel[1] = g;
                pixel[2] = b;
                continue;
            }
            pixel[layout.alphaAt] = a;
            if (!layout.premultiplied) {
                if (a == 0) {
                    r = g = b = 0;
                } else if (a != 255) {
                    r = (uint8_t)charon_clamp(((unsigned)r * 255 + a / 2) / a);
                    g = (uint8_t)charon_clamp(((unsigned)g * 255 + a / 2) / a);
                    b = (uint8_t)charon_clamp(((unsigned)b * 255 + a / 2) / a);
                }
            }
            pixel[layout.red] = r;
            pixel[layout.green] = g;
            pixel[layout.blue] = b;
        }
    }
    free(scratch);
    return kvImageNoError;
}

typedef struct {
    void (*callback)(void *userData, void *data);
    void *userData;
} charon_release;

static void charon_release_data(void *info, const void *data, size_t size)
{
    charon_release *release = info;
    if (release->callback)
        release->callback(release->userData, (void *)data);
    else
        free((void *)data);
    free(release);
}

CGImageRef vImageCreateCGImageFromBuffer(const vImage_Buffer *buf, const vImage_CGImageFormat *format, void (*callback)(void *userData, void *buf_data), void *userData, vImage_Flags flags, vImage_Error *error)
{
    vImage_Error status = kvImageNoError;
    CGImageRef image = NULL;
    charon_layout layout;
    if (!buf || !format) {
        status = kvImageNullPointerArgument;
    } else if (!charon_known_flags(flags, kvImageNoAllocate | kvImagePrintDiagnosticsToConsole | kvImageHighQualityResampling | kvImageDoNotTile)) {
        status = kvImageUnknownFlagsBit;
    } else if ((status = charon_check_format(format, &layout)) == kvImageNoError) {
        size_t minimum = (buf->width * format->bitsPerPixel + 7) / 8;
        if (!buf->data || buf->rowBytes < minimum) {
            status = kvImageInvalidRowBytes;
        } else {
            size_t size = buf->rowBytes * buf->height;
            CGDataProviderRef provider;
            if (flags & kvImageNoAllocate) {
                charon_release *release = malloc(sizeof(*release));
                release->callback = callback;
                release->userData = userData;
                provider = CGDataProviderCreateWithData(release, buf->data, size, charon_release_data);
            } else {
                CFDataRef copy = CFDataCreate(kCFAllocatorDefault, buf->data, (CFIndex)size);
                provider = CGDataProviderCreateWithCFData(copy);
                CFRelease(copy);
            }
            CGColorSpaceRef space = charon_space(format);
            image = CGImageCreate(buf->width, buf->height, format->bitsPerComponent, format->bitsPerPixel, buf->rowBytes, space, format->bitmapInfo, provider, format->decode, false, format->renderingIntent);
            CGColorSpaceRelease(space);
            CGDataProviderRelease(provider);
            if (!image)
                status = kvImageInvalidImageFormat;
        }
    }
    if (error)
        *error = status;
    return image;
}
