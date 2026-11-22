#import "../app/revenant_check.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <QuartzCore/QuartzCore.h>

static CMSampleBufferRef planar_sample(OSType format, size_t height, uint8_t cb, uint8_t cr, CFStringRef matrix)
{
    CVPixelBufferRef pixel = NULL;
    if (CVPixelBufferCreate(kCFAllocatorDefault, 16, height, format, NULL, &pixel) != kCVReturnSuccess || !pixel)
        return NULL;
    CVPixelBufferLockBaseAddress(pixel, 0);
    memset(CVPixelBufferGetBaseAddressOfPlane(pixel, 0), 0x90,
           CVPixelBufferGetHeightOfPlane(pixel, 0) * CVPixelBufferGetBytesPerRowOfPlane(pixel, 0));
    uint8_t *chroma = CVPixelBufferGetBaseAddressOfPlane(pixel, 1);
    size_t rows = CVPixelBufferGetHeightOfPlane(pixel, 1);
    size_t stride = CVPixelBufferGetBytesPerRowOfPlane(pixel, 1);
    for (size_t row = 0; row < rows; row++) {
        for (size_t offset = 0; offset + 1 < stride; offset += 2) {
            chroma[row * stride + offset] = cb;
            chroma[row * stride + offset + 1] = cr;
        }
    }
    CVPixelBufferUnlockBaseAddress(pixel, 0);
    if (matrix)
        CVBufferSetAttachment(pixel, CFSTR("YCbCrMatrix"), matrix, kCVAttachmentMode_ShouldPropagate);
    CMSampleBufferRef sample = NULL;
    CMVideoFormatDescriptionRef description = NULL;
    if (CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixel, &description) == noErr) {
        CMSampleTimingInfo timing = {kCMTimeInvalid, kCMTimeZero, kCMTimeInvalid};
        CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixel, true, NULL, NULL, description, &timing, &sample);
        CFRelease(description);
    }
    CVPixelBufferRelease(pixel);
    if (sample) {
        CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sample, true);
        if (attachments && CFArrayGetCount(attachments) > 0) {
            CFMutableDictionaryRef values = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
            CFDictionarySetValue(values, kCMSampleAttachmentKey_DisplayImmediately, kCFBooleanTrue);
        }
    }
    return sample;
}

static BOOL pixel_of(id contents, int *red, int *green, int *blue)
{
    if (!contents || CFGetTypeID((__bridge CFTypeRef)contents) != CGImageGetTypeID())
        return NO;
    unsigned char pixel[4] = {0, 0, 0, 0};
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixel, 1, 1, 8, 4, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    CGContextDrawImage(context, CGRectMake(0, 0, 1, 1), (__bridge CGImageRef)contents);
    CGContextRelease(context);
    *red = pixel[0];
    *green = pixel[1];
    *blue = pixel[2];
    return YES;
}

static BOOL near(int value, int expected)
{
    return value >= expected - 2 && value <= expected + 2;
}

static void spin(void)
{
    for (int index = 0; index < 40; index++) {
        @autoreleasepool {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
        }
    }
}

REVENANT_CASE(avfoundation_display_layer_formats)
{
    BOOL flip = (BOOL)negative;
    struct {
        const char *name;
        OSType format;
        size_t height;
        uint8_t cb;
        uint8_t cr;
        CFStringRef matrix;
        int red;
        int green;
        int blue;
    } scenarios[] = {
        {"420v neutral chroma", kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, 16, 0x80, 0x80, NULL, 149, 149, 149},
        {"420f neutral chroma", kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, 16, 0x80, 0x80, NULL, 144, 144, 144},
        {"420v colour, no matrix, standard definition", kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, 480, 0x70, 0x90, NULL, 178, 144, 115},
        {"420v colour, ITU_R_601_4", kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, 16, 0x70, 0x90, CFSTR("ITU_R_601_4"), 175, 142, 117},
        {"420v colour, ITU_R_709_2", kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, 16, 0x70, 0x90, CFSTR("ITU_R_709_2"), 178, 144, 115},
        {"420v colour, no matrix, high definition", kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, 720, 0x70, 0x90, NULL, 178, 144, 115},
        {"420f colour, ITU_R_601_4", kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, 16, 0x70, 0x90, CFSTR("ITU_R_601_4"), 166, 138, 116},
    };
    for (size_t index = 0; index < sizeof scenarios / sizeof scenarios[0]; index++) {
        @autoreleasepool {
            AVSampleBufferDisplayLayer *layer = [[AVSampleBufferDisplayLayer alloc] init];
            CMSampleBufferRef sample = planar_sample(scenarios[index].format, scenarios[index].height, scenarios[index].cb, scenarios[index].cr, scenarios[index].matrix);
            revenant_expect_true([NSString stringWithFormat:@"a %s sample buffer is made", scenarios[index].name],
                                 (sample != NULL) != flip, @"no sample buffer");
            if (!sample)
                continue;
            [layer enqueueSampleBuffer:sample];
            CFRelease(sample);
            spin();
            int red = -1, green = -1, blue = -1;
            BOOL drawn = layer.status != AVQueuedSampleBufferRenderingStatusFailed && pixel_of(layer.contents, &red, &green, &blue);
            revenant_expect_true([NSString stringWithFormat:@"a %s frame is drawn", scenarios[index].name],
                                 drawn != flip, [NSString stringWithFormat:@"contents %d status %ld", layer.contents != nil, (long)layer.status]);
            revenant_expect_true([NSString stringWithFormat:@"a %s frame has red %d, green %d, blue %d", scenarios[index].name,
                                  scenarios[index].red, scenarios[index].green, scenarios[index].blue],
                                 (near(red, scenarios[index].red) && near(green, scenarios[index].green) && near(blue, scenarios[index].blue)) != flip,
                                 [NSString stringWithFormat:@"red %d green %d blue %d", red, green, blue]);
        }
    }
    @autoreleasepool {
        AVSampleBufferDisplayLayer *layer = [[AVSampleBufferDisplayLayer alloc] init];
        CMSampleBufferRef sample = planar_sample(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, 16, 0x70, 0x90, CFSTR("SMPTE_240M"));
        [layer enqueueSampleBuffer:sample];
        if (sample)
            CFRelease(sample);
        spin();
        revenant_expect_true(@"a 420v frame in an unsupported matrix is not drawn, and the system reports no failure for it",
                             (layer.contents == nil && layer.status == AVQueuedSampleBufferRenderingStatusRendering) != flip,
                             [NSString stringWithFormat:@"contents %d status %ld", layer.contents != nil, (long)layer.status]);
    }
}
