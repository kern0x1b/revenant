#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>

#import "RevenantDocumentScan.h"
#import "check.h"

static void expect(BOOL ok, const char *name, NSString *seen)
{
    revenant_check(ok != revenant_negative, name, seen);
}

static const size_t SCENE_WIDTH = 1600;
static const size_t SCENE_HEIGHT = 1200;
static const double PAGE_WIDTH = 760;
static const double PAGE_HEIGHT = 1000;
static const double PAGE_ANGLE = 8.0 * M_PI / 180.0;

static CGImageRef makeScene(BOOL withPage)
{
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, SCENE_WIDTH, SCENE_HEIGHT, 8, 0, space, (CGBitmapInfo)kCGImageAlphaNoneSkipLast);
    CGColorSpaceRelease(space);
    CGContextSetRGBFillColor(context, 0.16, 0.17, 0.19, 1);
    CGContextFillRect(context, CGRectMake(0, 0, SCENE_WIDTH, SCENE_HEIGHT));
    if (withPage) {
        CGContextTranslateCTM(context, SCENE_WIDTH / 2.0, SCENE_HEIGHT / 2.0);
        CGContextRotateCTM(context, PAGE_ANGLE);
        CGContextSetRGBFillColor(context, 0.94, 0.94, 0.92, 1);
        CGContextFillRect(context, CGRectMake(-PAGE_WIDTH / 2, -PAGE_HEIGHT / 2, PAGE_WIDTH, PAGE_HEIGHT));
        double sw = 0.14 * PAGE_WIDTH, sh = 0.14 * PAGE_HEIGHT, mx = 0.04 * PAGE_WIDTH, my = 0.04 * PAGE_HEIGHT;
        double left = -PAGE_WIDTH / 2 + mx, right = PAGE_WIDTH / 2 - mx - sw, bottom = -PAGE_HEIGHT / 2 + my, top = PAGE_HEIGHT / 2 - my - sh;
        CGContextSetRGBFillColor(context, 1, 0, 0, 1);
        CGContextFillRect(context, CGRectMake(left, top, sw, sh));
        CGContextSetRGBFillColor(context, 0, 1, 0, 1);
        CGContextFillRect(context, CGRectMake(right, top, sw, sh));
        CGContextSetRGBFillColor(context, 0, 0, 1, 1);
        CGContextFillRect(context, CGRectMake(right, bottom, sw, sh));
        CGContextSetRGBFillColor(context, 1, 1, 0, 1);
        CGContextFillRect(context, CGRectMake(left, bottom, sw, sh));
        CGContextSetRGBFillColor(context, 0.35, 0.35, 0.35, 1);
        for (int line = 0; line < 9; line++)
            CGContextFillRect(context, CGRectMake(-PAGE_WIDTH * 0.3, PAGE_HEIGHT * 0.25 - line * PAGE_HEIGHT * 0.06, PAGE_WIDTH * 0.6, PAGE_HEIGHT * 0.02));
    }
    CGImageRef image = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    return image;
}

static NSData *stillFrom(CGImageRef upright, int orientation)
{
    size_t width = CGImageGetWidth(upright), height = CGImageGetHeight(upright);
    CGImageRef stored = CGImageRetain(upright);
    if (orientation == 6) {
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        CGContextRef context = CGBitmapContextCreate(NULL, height, width, 8, 0, space, (CGBitmapInfo)kCGImageAlphaNoneSkipLast);
        CGColorSpaceRelease(space);
        CGContextTranslateCTM(context, height, 0);
        CGContextRotateCTM(context, M_PI_2);
        CGContextDrawImage(context, CGRectMake(0, 0, width, height), upright);
        CGImageRelease(stored);
        stored = CGBitmapContextCreateImage(context);
        CGContextRelease(context);
    }
    NSMutableData *data = [NSMutableData data];
    CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)data, CFSTR("public.jpeg"), 1, NULL);
    NSDictionary *options = @{(__bridge NSString *)kCGImageDestinationLossyCompressionQuality : @0.9,
                              (__bridge NSString *)kCGImagePropertyOrientation : @(orientation)};
    CGImageDestinationAddImage(destination, stored, (__bridge CFDictionaryRef)options);
    CGImageDestinationFinalize(destination);
    CFRelease(destination);
    CGImageRelease(stored);
    return data;
}

static BOOL sampleJPEG(NSData *jpeg, double fx, double fy, int rgb[3])
{
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)jpeg, NULL);
    if (source == NULL)
        return NO;
    CGImageRef image = CGImageSourceCreateImageAtIndex(source, 0, NULL);
    CFRelease(source);
    if (image == NULL)
        return NO;
    size_t width = CGImageGetWidth(image), height = CGImageGetHeight(image);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, 0, space, (CGBitmapInfo)kCGImageAlphaNoneSkipLast);
    CGColorSpaceRelease(space);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
    CGImageRelease(image);
    const uint8_t *pixels = CGBitmapContextGetData(context);
    const uint8_t *pixel = pixels + (size_t)(fy * height) * CGBitmapContextGetBytesPerRow(context) + (size_t)(fx * width) * 4;
    for (int i = 0; i < 3; i++)
        rgb[i] = pixel[i];
    CGContextRelease(context);
    return YES;
}

static BOOL colourNear(const int rgb[3], int red, int green, int blue, int tolerance)
{
    return abs(rgb[0] - red) <= tolerance && abs(rgb[1] - green) <= tolerance && abs(rgb[2] - blue) <= tolerance;
}

static RevenantDocumentQuad truth(void)
{
    double sx[4] = {-1, 1, 1, -1}, sy[4] = {1, 1, -1, -1};
    RevenantDocumentQuad quad;
    for (int i = 0; i < 4; i++) {
        double x = sx[i] * PAGE_WIDTH / 2, y = sy[i] * PAGE_HEIGHT / 2;
        quad.corners[i].x = (float)((x * cos(PAGE_ANGLE) - y * sin(PAGE_ANGLE) + SCENE_WIDTH / 2.0) / SCENE_WIDTH);
        quad.corners[i].y = (float)((x * sin(PAGE_ANGLE) + y * cos(PAGE_ANGLE) + SCENE_HEIGHT / 2.0) / SCENE_HEIGHT);
    }
    return quad;
}

static void checkPage(RevenantDocumentPage *page, const char *label)
{
    NSString *prefix = [NSString stringWithUTF8String:label];
    expect(page != nil, [[prefix stringByAppendingString:@": a page is made"] UTF8String], @"");
    if (page == nil)
        return;
    expect(page.detected, [[prefix stringByAppendingString:@": the page is found"] UTF8String], @"");
    expect(labs((long)page.height - (long)PAGE_HEIGHT) <= 8 && labs((long)page.width - (long)PAGE_WIDTH) <= 8,
           [[prefix stringByAppendingString:@": the scan has the page's own size when that is under the largest side"] UTF8String],
           [NSString stringWithFormat:@"%zu by %zu", page.width, page.height]);
    RevenantDocumentQuad expected = truth();
    RevenantDocumentQuad found = page.quad;
    double distance = RevenantDocumentQuadDistance(&expected, &found);
    printf("measured: %s: the worst corner is %.4f from the page\n", label, distance);
    expect(distance < 0.015, [[prefix stringByAppendingString:@": the corners are where the page is"] UTF8String], [NSString stringWithFormat:@"%f", distance]);
    int topLeft[3], topRight[3], bottomRight[3], bottomLeft[3], middle[3];
    BOOL sampled = sampleJPEG(page.jpeg, 0.11, 0.11, topLeft) && sampleJPEG(page.jpeg, 0.89, 0.11, topRight) &&
                   sampleJPEG(page.jpeg, 0.89, 0.89, bottomRight) && sampleJPEG(page.jpeg, 0.11, 0.89, bottomLeft) && sampleJPEG(page.jpeg, 0.5, 0.05, middle);
    expect(sampled, [[prefix stringByAppendingString:@": the scan is a JPEG"] UTF8String], @"");
    if (!sampled)
        return;
    NSString *seen = [NSString stringWithFormat:@"%d,%d,%d %d,%d,%d %d,%d,%d %d,%d,%d", topLeft[0], topLeft[1], topLeft[2], topRight[0], topRight[1], topRight[2],
                      bottomRight[0], bottomRight[1], bottomRight[2], bottomLeft[0], bottomLeft[1], bottomLeft[2]];
    expect(colourNear(topLeft, 255, 0, 0, 60) && colourNear(topRight, 0, 255, 0, 60) && colourNear(bottomRight, 0, 0, 255, 60) && colourNear(bottomLeft, 255, 255, 0, 60),
           [[prefix stringByAppendingString:@": the four marks keep their corners upright"] UTF8String], seen);
    expect(colourNear(middle, 240, 240, 235, 25), [[prefix stringByAppendingString:@": the margin of the scan is paper, not table"] UTF8String],
           [NSString stringWithFormat:@"%d,%d,%d", middle[0], middle[1], middle[2]]);
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    @autoreleasepool {
        CGImageRef withPage = makeScene(YES);
        CGImageRef empty = makeScene(NO);

        NSData *upright = stillFrom(withPage, 1);
        checkPage(RevenantDocumentPageFromJPEG(upright, NULL, 1024, 0.87), "upright still");

        NSData *turned = stillFrom(withPage, 6);
        checkPage(RevenantDocumentPageFromJPEG(turned, NULL, 1024, 0.87), "still tagged for a quarter turn");

        RevenantDocumentQuad expected = truth();
        RevenantDocumentQuad nudged = expected;
        for (int i = 0; i < 4; i++)
            nudged.corners[i].x += 0.01f;
        RevenantDocumentPage *hinted = RevenantDocumentPageFromJPEG(upright, &nudged, 1024, 0.87);
        RevenantDocumentQuad hintedQuad = hinted.quad;
        expect(hinted != nil && RevenantDocumentQuadDistance(&hintedQuad, &expected) < 0.015, "a hint near the page picks the page",
               [NSString stringWithFormat:@"%f", hinted ? RevenantDocumentQuadDistance(&hintedQuad, &expected) : -1.0]);

        NSData *flat = stillFrom(empty, 1);
        RevenantDocumentPage *whole = RevenantDocumentPageFromJPEG(flat, NULL, 1024, 0.87);
        expect(whole != nil && !whole.detected && whole.width == 1024 && whole.height == 768, "a table without a page gives the whole frame",
               [NSString stringWithFormat:@"%zu by %zu", whole.width, whole.height]);
        RevenantDocumentPage *given = RevenantDocumentPageFromJPEG(flat, &expected, 1024, 0.87);
        RevenantDocumentQuad givenQuad = given.quad;
        expect(given != nil && given.detected && RevenantDocumentQuadDistance(&givenQuad, &expected) == 0, "a hint stands in when nothing is found",
               @"");
        RevenantDocumentPage *small = RevenantDocumentPageFromJPEG(upright, NULL, 300, 0.5);
        expect(small != nil && labs((long)small.height - 300) <= 1 && small.jpeg.length < given.jpeg.length, "a smaller side and quality give a smaller scan",
               [NSString stringWithFormat:@"%zu by %zu, %lu bytes against %lu", small.width, small.height, (unsigned long)small.jpeg.length, (unsigned long)given.jpeg.length]);

        expect(RevenantDocumentPageFromJPEG(nil, NULL, 1024, 0.87) == nil, "no data gives no page", @"");
        expect(RevenantDocumentPageFromJPEG([NSData dataWithBytes:"not a picture" length:13], NULL, 1024, 0.87) == nil, "bytes that are not a picture give no page", @"");
        expect(RevenantDocumentPageFromJPEG(upright, NULL, 0, 0.87) == nil, "a side of zero gives no page", @"");

        CGImageRelease(withPage);
        CGImageRelease(empty);
    }
    return revenant_finish();
}
