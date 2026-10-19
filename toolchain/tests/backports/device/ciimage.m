#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>
#import <CoreVideo/CoreVideo.h>
#import "check.h"

static CIContext *context;

static void rgba(CIImage *image, CGPoint at, uint8_t out[4])
{
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    [context render:image toBitmap:out rowBytes:4 bounds:CGRectMake(at.x, at.y, 1, 1) format:kCIFormatRGBA8 colorSpace:space];
    CGColorSpaceRelease(space);
}

static BOOL near4(const uint8_t a[4], int r, int g, int b, int al)
{
    return abs(a[0] - r) <= 1 && abs(a[1] - g) <= 1 && abs(a[2] - b) <= 1 && abs(a[3] - al) <= 1;
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to([NSString stringWithUTF8String:argv[1]]);
        context = [CIContext contextWithOptions:@{kCIContextUseSoftwareRenderer: @YES, kCIContextWorkingColorSpace: [NSNull null]}];
        CIImage *red = [[CIImage imageWithColor:[CIColor colorWithRed:1 green:0 blue:0 alpha:0.5]] imageByCroppingToRect:CGRectMake(0, 0, 10, 10)];
        CIImage *blue = [[CIImage imageWithColor:[CIColor colorWithRed:0 green:0 blue:1 alpha:1]] imageByCroppingToRect:CGRectMake(5, 5, 10, 10)];
        CHECK([CIFilter filterWithName:@"CISourceOverCompositing"] != nil, "the release has CISourceOverCompositing");
        CIImage *over = [red imageByCompositingOverImage:blue];
        printf("measure composite extent %g %g %g %g\n", over.extent.origin.x, over.extent.origin.y, over.extent.size.width, over.extent.size.height);
        CHECK(CGRectEqualToRect(over.extent, CGRectMake(0, 0, 15, 15)), "the composite covers both extents");
        uint8_t p[4];
        rgba(over, CGPointMake(7, 7), p);
        printf("measure composite at 7,7: %d %d %d %d\n", p[0], p[1], p[2], p[3]);
        CHECK(near4(p, 128, 0, 128, 255), "half red over blue is source over (premultiplied 128 0 128 255)");
        rgba(over, CGPointMake(2, 2), p);
        CHECK(near4(p, 128, 0, 0, 128), "half red over nothing stays half red");
        rgba(over, CGPointMake(12, 12), p);
        CHECK(near4(p, 0, 0, 255, 255), "blue where red is not");
        CHECK([red imageByCompositingOverImage:nil] == red, "over nil the image is itself");

        CIFilter *blur = [CIFilter filterWithName:@"CIGaussianBlur" withInputParameters:@{@"inputRadius": @3}];
        CHECK([[blur valueForKey:@"inputRadius"] doubleValue] == 3, "the parameters are set");
        CIFilter *controls = [CIFilter filterWithName:@"CIColorControls" withInputParameters:@{@"inputSaturation": @0.5}];
        printf("measure CIColorControls brightness %s contrast %s\n", [[controls valueForKey:@"inputBrightness"] description].UTF8String,
               [[controls valueForKey:@"inputContrast"] description].UTF8String);
        CHECK([[controls valueForKey:@"inputBrightness"] doubleValue] == 0 && [[controls valueForKey:@"inputContrast"] doubleValue] == 1,
              "the other inputs keep the release's defaults");
        CHECK([CIFilter filterWithName:@"CINoSuchFilter" withInputParameters:@{@"inputRadius": @3}] == nil, "an unknown filter is nil");
        NSString *raised = nil;
        @try {
            [CIFilter filterWithName:@"CIGaussianBlur" withInputParameters:@{@"inputNoSuchKey": @1}];
        } @catch (NSException *exception) {
            raised = exception.name;
        }
        printf("measure an unknown key raises %s\n", raised.UTF8String ?: "nothing");
        CHECK([raised isEqualToString:NSUndefinedKeyException], "an unknown key raises NSUnknownKeyException");

        CVPixelBufferRef plainBuffer = NULL, surfaced = NULL;
        CVPixelBufferCreate(NULL, 24, 12, kCVPixelFormatType_32BGRA, NULL, &plainBuffer);
        CVPixelBufferCreate(NULL, 24, 12, kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef)@{(__bridge NSString *)kCVPixelBufferIOSurfacePropertiesKey: @{}}, &surfaced);
        CHECK([[CIImage alloc] initWithCVPixelBuffer:plainBuffer] == nil, "the release's own initWithCVPixelBuffer: refuses a buffer with no IOSurface");
        CHECK([[CIImage alloc] initWithCVImageBuffer:plainBuffer] == nil, "and so does initWithCVImageBuffer:, the same answer");
        CIImage *fromImageBuffer = [[CIImage alloc] initWithCVImageBuffer:surfaced];
        CHECK(fromImageBuffer && CGRectEqualToRect(fromImageBuffer.extent, CGRectMake(0, 0, 24, 12)), "an IOSurface-backed buffer makes a 24x12 image");
        CHECK(CGRectEqualToRect([CIImage imageWithCVImageBuffer:surfaced options:@{kCIImageColorSpace: [NSNull null]}].extent, CGRectMake(0, 0, 24, 12)),
              "with options, 24x12");
        CHECK([[CIImage alloc] initWithCVImageBuffer:NULL] == nil && [CIImage imageWithCVImageBuffer:NULL] == nil, "NULL is nil");
        CVPixelBufferRelease(plainBuffer);
        CVPixelBufferRelease(surfaced);

        CHECK([red imageBySamplingLinear] == red, "an image is its own linearly sampled image");
        CIImage *scaled = [blue imageByApplyingTransform:CGAffineTransformMakeScale(2.5, 1)];
        uint8_t edge[4];
        rgba(scaled, CGPointMake(12, 7), edge);
        printf("measure the release's scaled edge at 12,7: %d %d %d %d\n", edge[0], edge[1], edge[2], edge[3]);
        CHECK(edge[3] > 64 && edge[3] < 192, "the release samples a scaled edge half covered as half, so linearly");
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures ? 1 : 0;
}
