#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>
#include <dlfcn.h>
#import "check.h"

static const unsigned char png[] = {
    0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x02,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x9d, 0x74, 0x66, 0x1a, 0x00, 0x00, 0x00, 0x11, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9c, 0x63, 0xf8, 0xcf, 0xc0, 0xf0,
    0x1f, 0x86, 0x19, 0x90, 0x39, 0x00, 0x9b, 0x7e, 0x0b, 0xf5, 0x72, 0xb0, 0xb9, 0x3c, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42,
    0x60, 0x82,
};

static NSString *decoded(NSDictionary *options)
{
    CFDataRef data = CFDataCreate(NULL, png, sizeof png);
    CGImageSourceRef source = CGImageSourceCreateWithData(data, NULL);
    CGImageRef image = source ? CGImageSourceCreateImageAtIndex(source, 0, (__bridge CFDictionaryRef)options) : NULL;
    NSString *answer = image ? [NSString stringWithFormat:@"%zux%zu", CGImageGetWidth(image), CGImageGetHeight(image)] : @"NULL";
    if (image) {
        uint8_t pixel[4] = {0};
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        CGContextRef context = CGBitmapContextCreate(pixel, 1, 1, 8, 4, space, kCGImageAlphaPremultipliedLast);
        CGContextDrawImage(context, CGRectMake(0, 0, 3, 2), image);
        answer = [answer stringByAppendingFormat:@" %d,%d,%d,%d", pixel[0], pixel[1], pixel[2], pixel[3]];
        CGContextRelease(context);
        CGColorSpaceRelease(space);
        CGImageRelease(image);
    }
    if (source)
        CFRelease(source);
    CFRelease(data);
    return answer;
}

int main(void)
{
    @autoreleasepool {
        CHECK_EQUAL((__bridge NSString *)kCGImageSourceShouldCacheImmediately, @"kCGImageSourceShouldCacheImmediately", "the option key is the string ImageIO gives it");
        CHECK(CFGetTypeID(kCGImageSourceShouldCacheImmediately) == CFStringGetTypeID(), "the option key is a string");
        NSString *plain = decoded(nil);
        CHECK_EQUAL(plain, @"3x2 255,0,0,255", "an image is decoded without options");
        CHECK_EQUAL(decoded(@{(__bridge id)kCGImageSourceShouldCacheImmediately: @YES}), plain, "an image is decoded the same with the option set");
        CHECK_EQUAL(decoded(@{(__bridge id)kCGImageSourceShouldCacheImmediately: @NO, (__bridge id)kCGImageSourceShouldCache: @YES}), plain, "and with the option cleared beside another");
#ifndef CHARON_HOST
        Dl_info info;
        CHECK(dladdr(&kCGImageSourceShouldCacheImmediately, &info) && info.dli_fname && strstr(info.dli_fname, "GraphicsBackports"), "the key comes from the backports library on a release that lacks it");
#endif
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        return charon_failures;
    }
}
