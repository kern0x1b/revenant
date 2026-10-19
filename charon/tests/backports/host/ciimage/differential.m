#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>
#import <CoreVideo/CoreVideo.h>

@interface CIImage (CharonHost)
- (CIImage *)charonHost_imageByCompositingOverImage:(CIImage *)dest;
- (instancetype)initCharonHostWithCVImageBuffer:(CVImageBufferRef)buffer;
- (instancetype)initCharonHostWithCVImageBuffer:(CVImageBufferRef)buffer options:(NSDictionary *)options;
+ (CIImage *)charonHost_imageWithCVImageBuffer:(CVImageBufferRef)buffer;
+ (CIImage *)charonHost_imageWithCVImageBuffer:(CVImageBufferRef)buffer options:(NSDictionary *)options;
- (CIImage *)charonHost_imageBySamplingLinear;
@end

@interface CIFilter (CharonHost)
+ (CIFilter *)charonHost_filterWithName:(NSString *)name withInputParameters:(NSDictionary *)params;
@end

void host_attach_prefixed(const char *prefix);

static long checks, different;
static CIContext *context;

static void check(BOOL same, NSString *what)
{
    checks++;
    if (!same && different++ < 30)
        printf("different: %s\n", what.UTF8String);
}

// The image drawn into 8-bit RGBA over its extent made whole pixels and widened by a margin (64x64
// around the origin when infinite).
static NSData *pixels_in(CIImage *image, CGFloat margin)
{
    if (!image)
        return nil;
    CGRect extent = CGRectIsInfinite(image.extent) ? CGRectMake(-32, -32, 64, 64) : CGRectInset(CGRectIntegral(image.extent), -margin, -margin);
    size_t width = (size_t)ceil(extent.size.width), height = (size_t)ceil(extent.size.height);
    NSMutableData *data = [NSMutableData dataWithLength:width * height * 4];
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    [context render:image toBitmap:data.mutableBytes rowBytes:width * 4 bounds:extent format:kCIFormatRGBA8 colorSpace:space];
    CGColorSpaceRelease(space);
    return data;
}

static NSData *pixels(CIImage *image)
{
    return pixels_in(image, 0);
}

// Within one step of 255 per channel: the host's explicit linear sampling rounds a few edge pixels
// one step away from the linear sampling an image has by default.
static BOOL near_data(NSData *a, NSData *b)
{
    if (a.length != b.length)
        return NO;
    const uint8_t *x = a.bytes, *y = b.bytes;
    for (NSUInteger i = 0; i < a.length; i++)
        if (abs((int)x[i] - (int)y[i]) > 1)
            return NO;
    return YES;
}

static void near_image(CIImage *host, CIImage *port, NSString *what)
{
    // With a margin: rendered over bounds that cut through its edge, the host's explicitly linear
    // image treats that edge otherwise than the image it came from.
    NSData *a = pixels_in(host, 3), *b = pixels_in(port, 3);
    int worst = 0;
    for (NSUInteger i = 0; i < MIN(a.length, b.length); i++)
        worst = MAX(worst, abs((int)((const uint8_t *)a.bytes)[i] - (int)((const uint8_t *)b.bytes)[i]));
    if (worst > 1)
        printf("%s: %lu and %lu bytes, worst step %d\n", what.UTF8String, (unsigned long)a.length, (unsigned long)b.length, worst);
    check(host && port && CGRectEqualToRect(host.extent, port.extent) && near_data(a, b), what);
}

static void same_image(CIImage *host, CIImage *port, NSString *what)
{
    check((host == nil) == (port == nil), [what stringByAppendingString:@": nil"]);
    if (!host || !port)
        return;
    check(CGRectEqualToRect(host.extent, port.extent), [NSString stringWithFormat:@"%@: extent %@ and %@", what,
                                                         NSStringFromRect(NSRectFromCGRect(host.extent)), NSStringFromRect(NSRectFromCGRect(port.extent))]);
    check([pixels(host) isEqualToData:pixels(port)], [what stringByAppendingString:@": pixels"]);
}

static CIImage *square(CGFloat r, CGFloat g, CGFloat b, CGFloat a, CGRect rect)
{
    return [[CIImage imageWithColor:[CIColor colorWithRed:r green:g blue:b alpha:a]] imageByCroppingToRect:rect];
}

static id outcome(CIFilter *(^make)(void))
{
    @try {
        CIFilter *filter = make();
        if (!filter)
            return @"nil";
        NSMutableDictionary *values = [NSMutableDictionary dictionary];
        for (NSString *key in filter.inputKeys)
            if ([filter valueForKey:key])
                values[key] = [[filter valueForKey:key] description];
        return @[filter.name ?: @"", values];
    } @catch (NSException *exception) {
        return exception.name;
    }
}

int main(void)
{
    @autoreleasepool {
        host_attach_prefixed("");
        context = [CIContext contextWithOptions:@{kCIContextWorkingColorSpace: [NSNull null]}];
        NSArray *images = @[square(1, 0, 0, 0.5, CGRectMake(0, 0, 10, 10)), square(0, 0, 1, 1, CGRectMake(5, 5, 10, 10)),
                            square(0, 1, 0, 0, CGRectMake(-3, 2, 7, 4)), square(0.2, 0.4, 0.6, 0.8, CGRectMake(20, 20, 3, 3)),
                            [CIImage imageWithColor:[CIColor colorWithRed:0.1 green:0.2 blue:0.3 alpha:0.4]]];
        for (NSUInteger i = 0; i < images.count; i++) {
            for (NSUInteger j = 0; j < images.count; j++)
                same_image([images[i] imageByCompositingOverImage:images[j]], [images[i] charonHost_imageByCompositingOverImage:images[j]],
                           [NSString stringWithFormat:@"composite %lu over %lu", (unsigned long)i, (unsigned long)j]);
            same_image([images[i] imageByCompositingOverImage:nil], [images[i] charonHost_imageByCompositingOverImage:nil],
                       [NSString stringWithFormat:@"composite %lu over nil", (unsigned long)i]);
            CIImage *scaled = [images[i] imageByApplyingTransform:CGAffineTransformMakeScale(2.5, 1.5)];
            near_image([[images[i] imageBySamplingLinear] imageByApplyingTransform:CGAffineTransformMakeScale(2.5, 1.5)],
                       [[images[i] charonHost_imageBySamplingLinear] imageByApplyingTransform:CGAffineTransformMakeScale(2.5, 1.5)],
                       [NSString stringWithFormat:@"sampling linear %lu, scaled", (unsigned long)i]);
            check([images[i] charonHost_imageBySamplingLinear] == images[i], [NSString stringWithFormat:@"sampling linear %lu is the image", (unsigned long)i]);
            same_image(scaled, [[images[i] charonHost_imageBySamplingLinear] imageByApplyingTransform:CGAffineTransformMakeScale(2.5, 1.5)],
                       [NSString stringWithFormat:@"sampling linear %lu is the image's own sampling", (unsigned long)i]);
        }

        NSArray *names = @[@"CIGaussianBlur", @"CIColorControls", @"CISourceOverCompositing", @"CIAffineTransform", @"CINoSuchFilter"];
        NSArray *parameters = @[[NSNull null], @{}, @{@"inputRadius": @3}, @{@"inputSaturation": @0.5, @"inputBrightness": @0.1},
                                @{@"inputNoSuchKey": @1}, @{kCIInputImageKey: images[0]}];
        for (NSString *name in names) {
            for (id given in parameters) {
                NSDictionary *params = given == [NSNull null] ? nil : given;
                id host = outcome(^CIFilter *{ return [CIFilter filterWithName:name withInputParameters:params]; });
                id port = outcome(^CIFilter *{ return [CIFilter charonHost_filterWithName:name withInputParameters:params]; });
                check([host isEqual:port], [NSString stringWithFormat:@"filter %@ with %@: %@ and %@", name, params, host, port]);
            }
        }

        OSType formats[] = {kCVPixelFormatType_32BGRA, kCVPixelFormatType_32ARGB, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange};
        for (size_t f = 0; f < sizeof formats / sizeof *formats; f++) {
            CVPixelBufferRef buffer = NULL;
            CVPixelBufferCreate(NULL, 24, 12, formats[f], (__bridge CFDictionaryRef)@{(id)kCVPixelBufferIOSurfacePropertiesKey: @{}}, &buffer);
            CVPixelBufferLockBaseAddress(buffer, 0);
            for (size_t plane = 0; plane < MAX((size_t)1, CVPixelBufferGetPlaneCount(buffer)); plane++) {
                uint8_t *base = CVPixelBufferGetPlaneCount(buffer) ? CVPixelBufferGetBaseAddressOfPlane(buffer, plane) : CVPixelBufferGetBaseAddress(buffer);
                size_t size = CVPixelBufferGetPlaneCount(buffer) ? CVPixelBufferGetBytesPerRowOfPlane(buffer, plane) * CVPixelBufferGetHeightOfPlane(buffer, plane)
                                                                 : CVPixelBufferGetDataSize(buffer);
                for (size_t k = 0; k < size; k++)
                    base[k] = (uint8_t)(k * 37 + plane * 11);
            }
            CVPixelBufferUnlockBaseAddress(buffer, 0);
            NSString *what = [NSString stringWithFormat:@"pixel buffer %zu", f];
            same_image([[CIImage alloc] initWithCVImageBuffer:buffer], [[CIImage alloc] initCharonHostWithCVImageBuffer:buffer], [what stringByAppendingString:@" init"]);
            NSDictionary *options = @{kCIImageColorSpace: [NSNull null]};
            same_image([[CIImage alloc] initWithCVImageBuffer:buffer options:options], [[CIImage alloc] initCharonHostWithCVImageBuffer:buffer options:options],
                       [what stringByAppendingString:@" init with options"]);
            same_image([CIImage imageWithCVImageBuffer:buffer], [CIImage charonHost_imageWithCVImageBuffer:buffer], [what stringByAppendingString:@" image"]);
            same_image([CIImage imageWithCVImageBuffer:buffer options:options], [CIImage charonHost_imageWithCVImageBuffer:buffer options:options],
                       [what stringByAppendingString:@" image with options"]);
            CVPixelBufferRelease(buffer);
        }
        same_image([[CIImage alloc] initWithCVImageBuffer:NULL], [[CIImage alloc] initCharonHostWithCVImageBuffer:NULL], @"NULL buffer init");
        same_image([CIImage imageWithCVImageBuffer:NULL], [CIImage charonHost_imageWithCVImageBuffer:NULL], @"NULL buffer image");

        printf("ciimage: %ld checks, %ld different\n", checks, different);
        return different ? 1 : 0;
    }
}
