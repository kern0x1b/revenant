#import "RevenantDocumentScan.h"

#import <ImageIO/ImageIO.h>

#define DETECTION_SIDE 640

@interface RevenantDocumentPage ()

@property (nonatomic, readwrite) NSData *jpeg;
@property (nonatomic, readwrite) size_t width;
@property (nonatomic, readwrite) size_t height;
@property (nonatomic, readwrite) RevenantDocumentQuad quad;
@property (nonatomic, readwrite) BOOL detected;

@end

@implementation RevenantDocumentPage

@synthesize jpeg = _jpeg;
@synthesize width = _width;
@synthesize height = _height;
@synthesize quad = _quad;
@synthesize detected = _detected;

@end

static CGImageRef RevenantDocumentCreateImage(NSData *data, size_t side)
{
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    if (source == NULL)
        return NULL;
    NSDictionary *options = @{
        (__bridge NSString *)kCGImageSourceCreateThumbnailFromImageAlways : @YES,
        (__bridge NSString *)kCGImageSourceCreateThumbnailWithTransform : @YES,
        (__bridge NSString *)kCGImageSourceThumbnailMaxPixelSize : @(side),
    };
    CGImageRef image = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)options);
    CFRelease(source);
    return image;
}

static BOOL RevenantDocumentDetect(CGContextRef context, const RevenantDocumentQuad *hint, RevenantDocumentQuad *quad)
{
    uint8_t *luminance = malloc(DETECTION_SIDE * DETECTION_SIDE);
    if (luminance == NULL)
        return NO;
    size_t width = 0, height = 0;
    BOOL found = RevenantDocumentLuminanceRGBA(CGBitmapContextGetData(context), CGBitmapContextGetWidth(context), CGBitmapContextGetHeight(context),
                                               CGBitmapContextGetBytesPerRow(context), DETECTION_SIDE, luminance, &width, &height) == 1 &&
                 RevenantDocumentFindQuad(luminance, width, height, width, hint, quad) == 1;
    free(luminance);
    return found;
}

static RevenantDocumentQuad RevenantDocumentWholeFrame(void)
{
    RevenantDocumentQuad quad = {{{0, 1}, {1, 1}, {1, 0}, {0, 0}}};
    return quad;
}

static void RevenantDocumentPixels(const RevenantDocumentQuad *quad, size_t width, size_t height, RevenantDocumentPoint pixels[4])
{
    for (int i = 0; i < 4; ++i) {
        pixels[i].x = quad->corners[i].x * (float)width;
        pixels[i].y = (1.0f - quad->corners[i].y) * (float)height;
    }
}

static NSData *RevenantDocumentEncode(CGImageRef image, CGFloat quality)
{
    NSMutableData *data = [NSMutableData data];
    CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)data, CFSTR("public.jpeg"), 1, NULL);
    if (destination == NULL)
        return nil;
    NSDictionary *options = @{(__bridge NSString *)kCGImageDestinationLossyCompressionQuality : @(quality)};
    CGImageDestinationAddImage(destination, image, (__bridge CFDictionaryRef)options);
    BOOL finished = CGImageDestinationFinalize(destination);
    CFRelease(destination);
    return finished ? data : nil;
}

RevenantDocumentPage *RevenantDocumentPageFromJPEG(NSData *still, const RevenantDocumentQuad *hint, size_t maximum_side, CGFloat quality)
{
    if (still.length == 0 || maximum_side == 0)
        return nil;
    CGImageRef image = RevenantDocumentCreateImage(still, maximum_side * 2);
    if (image == NULL)
        return nil;
    size_t width = CGImageGetWidth(image), height = CGImageGetHeight(image);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef source = CGBitmapContextCreate(NULL, width, height, 8, 0, space, (CGBitmapInfo)kCGImageAlphaNoneSkipLast);
    if (source == NULL) {
        CGColorSpaceRelease(space);
        CGImageRelease(image);
        return nil;
    }
    CGContextDrawImage(source, CGRectMake(0, 0, width, height), image);
    CGImageRelease(image);
    RevenantDocumentQuad quad = RevenantDocumentWholeFrame();
    BOOL detected = RevenantDocumentDetect(source, hint, &quad);
    if (!detected && hint != NULL) {
        quad = *hint;
        detected = YES;
    }
    RevenantDocumentPoint pixels[4];
    RevenantDocumentPixels(&quad, width, height, pixels);
    RevenantDocumentSize size = RevenantDocumentOutputSize(pixels, maximum_side);
    CGContextRef output = CGBitmapContextCreate(NULL, size.width, size.height, 8, 0, space, (CGBitmapInfo)kCGImageAlphaNoneSkipLast);
    if (output == NULL) {
        CGContextRelease(source);
        CGColorSpaceRelease(space);
        return nil;
    }
    BOOL warped = RevenantDocumentWarp(CGBitmapContextGetData(source), width, height, CGBitmapContextGetBytesPerRow(source), pixels,
                                       CGBitmapContextGetData(output), size.width, size.height, CGBitmapContextGetBytesPerRow(output)) == 1;
    if (!warped) {
        quad = RevenantDocumentWholeFrame();
        detected = NO;
        RevenantDocumentPixels(&quad, width, height, pixels);
        size = RevenantDocumentOutputSize(pixels, maximum_side);
        CGContextRelease(output);
        output = CGBitmapContextCreate(NULL, size.width, size.height, 8, 0, space, (CGBitmapInfo)kCGImageAlphaNoneSkipLast);
        warped = output != NULL && RevenantDocumentWarp(CGBitmapContextGetData(source), width, height, CGBitmapContextGetBytesPerRow(source), pixels,
                                                         CGBitmapContextGetData(output), size.width, size.height, CGBitmapContextGetBytesPerRow(output)) == 1;
    }
    CGContextRelease(source);
    CGColorSpaceRelease(space);
    if (!warped) {
        CGContextRelease(output);
        return nil;
    }
    CGImageRef page = CGBitmapContextCreateImage(output);
    CGContextRelease(output);
    if (page == NULL)
        return nil;
    NSData *jpeg = RevenantDocumentEncode(page, quality);
    CGImageRelease(page);
    if (jpeg == nil)
        return nil;
    RevenantDocumentPage *result = [[RevenantDocumentPage alloc] init];
    result.jpeg = jpeg;
    result.width = size.width;
    result.height = size.height;
    result.quad = quad;
    result.detected = detected;
    return result;
}
