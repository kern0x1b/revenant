// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// coreimage.m: guest test of what Core Image needs from the device.
//
// 1. An OpenGL ES 2 context: EAGLContext answers an object for ES2 (and ES1), as it does on a
//    device. Core Image's default renderer is built on one.
// 2. The CPU renderer (kCIContextUseSoftwareRenderer): a CIImage made from a CGImage with an
//    alpha channel reads back as it was drawn, opaque or not, and so does one with no alpha.
// 3. The default renderer, only where part 1 gave it a context to run on.
//
// One line per case, "ok" or "FAIL <why>"; exits with the number of failures.
#import <CoreImage/CoreImage.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import <OpenGLES/EAGL.h>

static int failures;

static void check(const char *name, BOOL good, const char *why)
{
    if (good) {
        printf("ok   %s\n", name);
    } else {
        printf("FAIL %s: %s\n", name, why);
        failures++;
    }
    fflush(stdout);
}

// A 4x4 image of one premultiplied RGBA colour (components given as the premultiplied bytes), with
// or without an alpha channel in the CGImage itself.
static CGImageRef makeImage(uint8_t r, uint8_t g, uint8_t b, uint8_t a, BOOL withAlpha)
{
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo info = (CGBitmapInfo)(withAlpha ? kCGImageAlphaPremultipliedLast : kCGImageAlphaNoneSkipLast);
    CGContextRef context = CGBitmapContextCreate(NULL, 4, 4, 8, 16, space, info);
    CGColorSpaceRelease(space);
    if (!context) return NULL;
    uint8_t *bytes = CGBitmapContextGetData(context);
    for (int i = 0; i < 16; i++) {
        bytes[i * 4] = r;
        bytes[i * 4 + 1] = g;
        bytes[i * 4 + 2] = b;
        bytes[i * 4 + 3] = withAlpha ? a : 255;
    }
    CGImageRef image = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    return image;
}

// The first pixel of an image drawn into a premultiplied RGBA bitmap, replacing what was there.
static void readBack(CGImageRef image, uint8_t out[4])
{
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef bitmap = CGBitmapContextCreate(out, 1, 1, 8, 4, space, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    CGContextSetBlendMode(bitmap, kCGBlendModeCopy);
    CGContextDrawImage(bitmap, CGRectMake(0, 0, 1, 1), image);
    CGContextRelease(bitmap);
}

// What a context's rendering of the image reads back as in the first pixel, premultiplied RGBA.
static BOOL render(CIContext *context, CGImageRef source, uint8_t out[4])
{
    CIImage *input = [CIImage imageWithCGImage:source];
    CGImageRef drawn = [context createCGImage:input fromRect:[input extent]];
    if (!drawn) return NO;
    readBack(drawn, out);
    CFDataRef data = CGDataProviderCopyData(CGImageGetDataProvider(drawn));
    const uint8_t *raw = data ? CFDataGetBytePtr(data) : NULL;
    printf("note rendered image: alpha info %d, %zu bits per pixel, first bytes %d,%d,%d,%d\n",
           (int)CGImageGetAlphaInfo(drawn), CGImageGetBitsPerPixel(drawn),
           raw ? raw[0] : -1, raw ? raw[1] : -1, raw ? raw[2] : -1, raw ? raw[3] : -1);
    if (data) CFRelease(data);
    CGImageRelease(drawn);
    return YES;
}

static void expectPixel(const char *name, CIContext *context, uint8_t r, uint8_t g, uint8_t b, uint8_t a, BOOL withAlpha)
{
    CGImageRef source = makeImage(r, g, b, a, withAlpha);
    uint8_t got[4] = {0, 0, 0, 0};
    if (!source || !render(context, source, got)) {
        check(name, NO, "no image");
        return;
    }
    CGImageRelease(source);
    uint8_t want[4] = {r, g, b, withAlpha ? a : 255};
    BOOL same = YES;
    for (int i = 0; i < 4; i++) {
        int d = (int)got[i] - (int)want[i];
        if (d < -2 || d > 2) same = NO;
    }
    char why[96];
    snprintf(why, sizeof why, "read %d,%d,%d,%d, drew %d,%d,%d,%d", got[0], got[1], got[2], got[3],
             want[0], want[1], want[2], want[3]);
    check(name, same, why);
}

// Where an alpha source goes wrong, told apart by what the image is made of and what it is drawn to.
static void expectPixelFrom(const char *name, CIImage *input, CIContext *context, const uint8_t want[4])
{
    CGImageRef drawn = [context createCGImage:input fromRect:CGRectMake(0, 0, 4, 4)];
    uint8_t got[4] = {0, 0, 0, 0};
    if (!drawn) {
        check(name, NO, "no image");
        return;
    }
    readBack(drawn, got);
    CGImageRelease(drawn);
    BOOL same = YES;
    for (int i = 0; i < 4; i++) {
        int d = (int)got[i] - (int)want[i];
        if (d < -2 || d > 2) same = NO;
    }
    char why[96];
    snprintf(why, sizeof why, "read %d,%d,%d,%d, drew %d,%d,%d,%d", got[0], got[1], got[2], got[3],
             want[0], want[1], want[2], want[3]);
    check(name, same, why);
}

static void expectBitmap(const char *name, CIImage *input, CIContext *context, CIFormat format, const uint8_t want[4])
{
    uint8_t out[4 * 4 * 4];
    memset(out, 0x55, sizeof out);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    [context render:input toBitmap:out rowBytes:16 bounds:CGRectMake(0, 0, 4, 4) format:format colorSpace:space];
    CGColorSpaceRelease(space);
    BOOL same = YES;
    for (int i = 0; i < 4; i++) {
        int d = (int)out[i] - (int)want[i];
        if (d < -2 || d > 2) same = NO;
    }
    char why[96];
    snprintf(why, sizeof why, "read %d,%d,%d,%d, drew %d,%d,%d,%d", out[0], out[1], out[2], out[3],
             want[0], want[1], want[2], want[3]);
    check(name, same, why);
}

// A pixel of an image (row counted from the top), read from a copy of the whole image drawn into a
// premultiplied RGBA bitmap of its own size, replacing what was there.
static void pixelAt(CGImageRef image, int x, int y, uint8_t out[4])
{
    size_t width = CGImageGetWidth(image), height = CGImageGetHeight(image);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef bitmap = CGBitmapContextCreate(NULL, width, height, 8, width * 4, space, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    CGContextSetBlendMode(bitmap, kCGBlendModeCopy);
    CGContextDrawImage(bitmap, CGRectMake(0, 0, width, height), image);
    const uint8_t *bytes = CGBitmapContextGetData(bitmap);
    memcpy(out, bytes + (size_t)y * width * 4 + (size_t)x * 4, 4);
    CGContextRelease(bitmap);
}

// CIGaussianBlur over a 40x20 picture of a red half and a blue half, drawn over the whole extent the
// blur makes (it widens the picture by three times the radius on every side): where the halves meet
// the pixel is a mixture of the two colours.
static void expectBlur(const char *name, CIContext *context)
{
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef bitmap = CGBitmapContextCreate(NULL, 40, 20, 8, 160, space, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    uint8_t *bytes = CGBitmapContextGetData(bitmap);
    for (int y = 0; y < 20; y++) {
        for (int x = 0; x < 40; x++) {
            uint8_t *p = bytes + y * 160 + x * 4;
            p[0] = x < 20 ? 255 : 0;
            p[1] = 0;
            p[2] = x < 20 ? 0 : 255;
            p[3] = 255;
        }
    }
    CGImageRef source = CGBitmapContextCreateImage(bitmap);
    CGContextRelease(bitmap);
    CIImage *input = [CIImage imageWithCGImage:source];
    CGImageRelease(source);
    CIFilter *blur = [CIFilter filterWithName:@"CIGaussianBlur"];
    [blur setValue:input forKey:@"inputImage"];
    [blur setValue:@6 forKey:@"inputRadius"];
    CIImage *output = [blur valueForKey:@"outputImage"];
    CGRect produced = [output extent];
    printf("note blur extent %g,%g %gx%g\n", produced.origin.x, produced.origin.y, produced.size.width, produced.size.height);
    CGImageRef drawn = [context createCGImage:output fromRect:produced];
    if (!drawn) {
        check(name, NO, "no image");
        return;
    }
    uint8_t middle[4] = {0, 0, 0, 0};
    pixelAt(drawn, (int)(20 - produced.origin.x), (int)(produced.size.height / 2), middle);
    CGImageRelease(drawn);
    char why[96];
    snprintf(why, sizeof why, "the middle reads %d,%d,%d,%d", middle[0], middle[1], middle[2], middle[3]);
    check(name, middle[0] > 30 && middle[2] > 30, why);
}

int main(void)
{
    @autoreleasepool {
        setenv("CL_LOG_ERRORS", "stdout", 1); // OpenCL names what it refuses, where it refuses it

        EAGLContext *es2 = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        check("EAGLContext ES2", es2 != nil, "initWithAPI:kEAGLRenderingAPIOpenGLES2 answered nil");
        EAGLContext *es1 = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
        check("EAGLContext ES1", es1 != nil, "initWithAPI:kEAGLRenderingAPIOpenGLES1 answered nil");

        // The control: the same source, read back without Core Image in between.
        CGImageRef plain = makeImage(128, 0, 0, 128, YES);
        uint8_t direct[4] = {0, 0, 0, 0};
        if (plain) readBack(plain, direct);
        CGImageRelease(plain);
        check("CoreGraphics reads a half-alpha image back", direct[0] == 128 && direct[3] == 128, "the control itself reads wrong");

        NSDictionary *software = @{kCIContextUseSoftwareRenderer : @YES};
        CIContext *cpu = [CIContext contextWithOptions:software];
        check("CIContext software", cpu != nil, "no context");
        if (cpu) {
            expectPixel("CPU opaque source, no alpha channel", cpu, 255, 0, 0, 255, NO);
            expectPixel("CPU opaque source, alpha channel", cpu, 255, 0, 0, 255, YES);
            expectPixel("CPU half-alpha source", cpu, 128, 0, 0, 128, YES);
            expectPixel("CPU clear source", cpu, 0, 0, 0, 0, YES);

            const uint8_t half[4] = {128, 0, 0, 128};
            const uint8_t red[4] = {255, 0, 0, 255};
            CIColor *halfRed = [CIColor colorWithRed:1 green:0 blue:0 alpha:128.0 / 255.0];
            expectPixelFrom("CPU half-alpha colour image", [CIImage imageWithColor:halfRed], cpu, half);
            expectBitmap("CPU half-alpha colour image to RGBA8", [CIImage imageWithColor:halfRed], cpu, kCIFormatRGBA8, half);
            expectBitmap("CPU opaque colour image to RGBA8", [CIImage imageWithColor:[CIColor colorWithRed:1 green:0 blue:0]],
                         cpu, kCIFormatRGBA8, red);
            uint8_t pixels[4 * 4 * 4];
            for (int i = 0; i < 16; i++) {
                pixels[i * 4] = 128;
                pixels[i * 4 + 1] = 0;
                pixels[i * 4 + 2] = 0;
                pixels[i * 4 + 3] = 128;
            }
            NSData *data = [NSData dataWithBytes:pixels length:sizeof pixels];
            CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
            CIImage *bitmap = [CIImage imageWithBitmapData:data bytesPerRow:16 size:CGSizeMake(4, 4) format:kCIFormatRGBA8 colorSpace:rgb];
            CGColorSpaceRelease(rgb);
            expectBitmap("CPU half-alpha bitmap image to RGBA8", bitmap, cpu, kCIFormatRGBA8, half);
            expectBlur("CPU blur mixes the colours either side of a line", cpu);
        }

        if (es2) {
            CIContext *gpu = [CIContext contextWithEAGLContext:es2];
            check("CIContext EAGL", gpu != nil, "no context");
            if (gpu) {
                expectPixel("GL opaque source", gpu, 255, 0, 0, 255, NO);
                expectPixel("GL half-alpha source", gpu, 128, 0, 0, 128, YES);
                expectBlur("GL blur mixes the colours either side of a line", gpu);
            }
        } else {
            printf("skip the default renderer: no ES2 context to run it on\n");
        }
    }
    return failures;
}
