#import <CoreImage/CoreImage.h>
#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

static NSString *const CharonCITTTypePNG = @"public.png";
static NSString *const CharonCITTTypeTIFF = @"public.tiff";
static NSString *const CharonCITTTypeJPEG = @"public.jpeg";

static BOOL CharonCIEncodedFormat(CIFormat format, CFStringRef *type, CIFormat *rendered)
{
    if (format == kCIFormatRGBA8) {
        *type = (__bridge CFStringRef)CharonCITTTypePNG, *rendered = kCIFormatRGBA8;
        return YES;
    }
    if (format == kCIFormatBGRA8) {
        *type = (__bridge CFStringRef)CharonCITTTypePNG, *rendered = kCIFormatBGRA8;
        return YES;
    }
    if (format == kCIFormatL8) {
        *type = (__bridge CFStringRef)CharonCITTTypeTIFF, *rendered = kCIFormatL8;
        return YES;
    }
    if (format == kCIFormatLA8) {
        *type = (__bridge CFStringRef)CharonCITTTypeTIFF, *rendered = kCIFormatLA8;
        return YES;
    }
    if (format == kCIFormatRGBAf) {
        *type = (__bridge CFStringRef)CharonCITTTypeTIFF, *rendered = kCIFormatRGBAh;
        return YES;
    }
    if (format == kCIFormatRGBAh) {
        *type = (__bridge CFStringRef)CharonCITTTypeTIFF, *rendered = kCIFormatRGBAh;
        return YES;
    }
    return NO;
}

@implementation CIContext (CharonRepresentations)

- (CGImageRef)createCGImage:(CIImage *)image
                   fromRect:(CGRect)rect
                     format:(CIFormat)format
                 colorSpace:(CGColorSpaceRef)colorSpace
                   deferred:(BOOL)deferred
{
    if (!image || CGRectIsNull(rect) || CGRectIsEmpty(rect))
        return NULL;
    NSUInteger width = (NSUInteger)ceil(rect.size.width), height = (NSUInteger)ceil(rect.size.height);
    size_t components = format == kCIFormatL8 ? 1 : (format == kCIFormatLA8 ? 2 : 4);
    size_t bits = format == kCIFormatRGBAf || format == kCIFormatRGBAh ? 16 : 8;
    NSMutableData *bytes = [NSMutableData dataWithLength:width * height * components * (bits / 8)];
    [self render:image toBitmap:bytes.mutableBytes rowBytes:(NSInteger)(width * components * (bits / 8)) bounds:rect
           format:format colorSpace:colorSpace];
    CGColorSpaceRef space = colorSpace ?: CGColorSpaceCreateDeviceRGB();
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)bytes);
    static const CGBitmapInfo infos[4] = {kCGImageAlphaNone, kCGImageAlphaOnly, kCGImageAlphaNoneSkipLast,
                                          kCGImageAlphaPremultipliedLast};
    CGImageRef made = CGImageCreate(width, height, bits, components * bits, width * components * (bits / 8), space,
                                    infos[components - 1], provider, NULL, NO, kCGRenderingIntentDefault);
    CGDataProviderRelease(provider);
    if (!colorSpace)
        CGColorSpaceRelease(space);
    return made;
}

- (NSData *)PNGRepresentationOfImage:(CIImage *)image format:(CIFormat)format colorSpace:(CGColorSpaceRef)colorSpace
                             options:(NSDictionary *)options
{
    return [self charon_representationOfImage:image format:format colorSpace:colorSpace type:(__bridge CFStringRef)CharonCITTTypePNG];
}

- (NSData *)TIFFRepresentationOfImage:(CIImage *)image format:(CIFormat)format colorSpace:(CGColorSpaceRef)colorSpace
                              options:(NSDictionary *)options
{
    return [self charon_representationOfImage:image format:format colorSpace:colorSpace type:(__bridge CFStringRef)CharonCITTTypeTIFF];
}

- (NSData *)JPEGRepresentationOfImage:(CIImage *)image colorSpace:(CGColorSpaceRef)colorSpace options:(NSDictionary *)options
{
    return [self charon_representationOfImage:image format:kCIFormatL8 colorSpace:colorSpace type:(__bridge CFStringRef)CharonCITTTypeJPEG];
}

- (NSData *)charon_representationOfImage:(CIImage *)image format:(CIFormat)format colorSpace:(CGColorSpaceRef)colorSpace
                                      type:(CFStringRef)type
{
    CFStringRef fileType = NULL;
    CIFormat rendered = kCIFormatRGBA8;
    if (!CharonCIEncodedFormat(format, &fileType, &rendered))
        return nil;
    if (CFEqual(type, (__bridge CFStringRef)CharonCITTTypeJPEG)) {
        rendered = kCIFormatRGBAf;
    }
    CGImageRef made = [self createCGImage:image fromRect:image.extent format:rendered colorSpace:colorSpace deferred:NO];
    if (!made)
        return nil;
    NSMutableData *data = [NSMutableData data];
    CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)data, type, 1, NULL);
    BOOL written = NO;
    if (destination) {
        CGImageDestinationAddImage(destination, made, NULL);
        written = CGImageDestinationFinalize(destination);
        CFRelease(destination);
    }
    CGImageRelease(made);
    return written ? data : nil;
}

- (BOOL)writePNGRepresentationOfImage:(CIImage *)image
                               toURL:(NSURL *)url
                              format:(CIFormat)format
                          colorSpace:(CGColorSpaceRef)colorSpace
                             options:(NSDictionary *)options
                               error:(NSError **)error
{
    return [self charon_writeRepresentationOfImage:image toURL:url format:format colorSpace:colorSpace
                                               type:(__bridge CFStringRef)CharonCITTTypePNG error:error];
}

- (BOOL)writeTIFFRepresentationOfImage:(CIImage *)image
                                toURL:(NSURL *)url
                               format:(CIFormat)format
                           colorSpace:(CGColorSpaceRef)colorSpace
                              options:(NSDictionary *)options
                                error:(NSError **)error
{
    return [self charon_writeRepresentationOfImage:image toURL:url format:format colorSpace:colorSpace
                                               type:(__bridge CFStringRef)CharonCITTTypeTIFF error:error];
}

- (BOOL)writeJPEGRepresentationOfImage:(CIImage *)image
                                toURL:(NSURL *)url
                           colorSpace:(CGColorSpaceRef)colorSpace
                              options:(NSDictionary *)options
                                error:(NSError **)error
{
    return [self charon_writeRepresentationOfImage:image toURL:url format:kCIFormatRGBAf colorSpace:colorSpace
                                               type:(__bridge CFStringRef)CharonCITTTypeJPEG error:error];
}

- (BOOL)charon_writeRepresentationOfImage:(CIImage *)image
                                   toURL:(NSURL *)url
                                  format:(CIFormat)format
                              colorSpace:(CGColorSpaceRef)colorSpace
                                    type:(CFStringRef)type
                                   error:(NSError **)error
{
    NSData *data = [self charon_representationOfImage:image format:format colorSpace:colorSpace type:type];
    if (!data) {
        if (error)
            *error = [NSError errorWithDomain:@"kCIErrorDomain" code:-1 userInfo:nil];
        return NO;
    }
    return [data writeToURL:url options:NSDataWritingAtomic error:error];
}

- (void)clearCaches
{
    [self reclaimResources];
}

@end
