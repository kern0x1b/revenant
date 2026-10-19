#import <CoreImage/CoreImage.h>
#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

// iOS 6's CoreImage can represent an image as TIFF, PNG and JPEG, but it spells it the way it was
// spelt then: no format to ask for, no destination URL, and no error out. What a caller of a later
// SDK wants is one encoding step with the format and the destination in it, and the answer is the
// same bytes either way: the image is rendered to a CGImage of the format asked for, and ImageIO
// writes that. Nothing here invents an encoder and nothing here re-encodes what the release already
// encoded.

// The type an encoding is written as, and the type an image is rendered as for it. A byte format is
// rendered as it is named; a float format is rendered into sixteen bits a channel, which is as much of
// a float image as a file of that type carries in a way CoreGraphics can hand over.
// The uniform types these encodings are, as the strings they are. The SDK names them (__bridge CFStringRef)CharonCITTTypePNG,
// (__bridge CFStringRef)CharonCITTTypeTIFF and (__bridge CFStringRef)CharonCITTTypeJPEG, and (__bridge CFStringRef)CharonCITTTypeJPEG is not exported by the release this is written
// against - the linker says so, undefined for armv7 - so the types are the strings themselves, which
// is what those constants hold.
static NSString *const CharonCITTTypePNG = @"public.png";
static NSString *const CharonCITTTypeTIFF = @"public.tiff";
static NSString *const CharonCITTTypeJPEG = @"public.jpeg";

static BOOL CharonCIEncodedFormat(CIFormat format, CFStringRef *type, CIFormat *rendered)
{
    // Ifs and not a switch, because the header declares the formats as exported constants and they are
    // values and not case labels - which is the same thing the accumulator ran into.
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

// The image as a CGImage of the format asked for, over the rectangle of the image, in the space the
// caller named. iOS 6 has the same rendering under a method that takes no format, so the format is
// what decides how wide a pixel is and what the bytes are read back as.
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

// The image as bytes of the type asked for: the image rendered to a CGImage of the format, and that
// image encoded. A format that is not one the encoders can carry has no representation, which is nil
// rather than a file of something else.
- (NSData *)charon_representationOfImage:(CIImage *)image format:(CIFormat)format colorSpace:(CGColorSpaceRef)colorSpace
                                      type:(CFStringRef)type
{
    CFStringRef fileType = NULL;
    CIFormat rendered = kCIFormatRGBA8;
    if (!CharonCIEncodedFormat(format, &fileType, &rendered))
        return nil;
    if (CFEqual(type, (__bridge CFStringRef)CharonCITTTypeJPEG)) {
        // JPEG is three channels and no alpha, so the image is rendered as RGB rather than RGBA.
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

// To a file, through the same bytes the representation gives: a URL is where those bytes go, and
// writing them is the whole of the difference between the two spellings.
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

// The release has no clearCaches, and has reclaimResources, which is what it did before the name
// changed. That is what this is: the release's own way of letting go of what it cached.
- (void)clearCaches
{
    [self reclaimResources];
}

@end
