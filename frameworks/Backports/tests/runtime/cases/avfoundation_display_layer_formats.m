#import "../app/revenant_check.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <QuartzCore/QuartzCore.h>

static CMSampleBufferRef planar_sample(OSType format)
{
    CVPixelBufferRef pixel = NULL;
    if (CVPixelBufferCreate(kCFAllocatorDefault, 16, 16, format, NULL, &pixel) != kCVReturnSuccess || !pixel)
        return NULL;
    CVPixelBufferLockBaseAddress(pixel, 0);
    for (size_t plane = 0; plane < CVPixelBufferGetPlaneCount(pixel); plane++) {
        void *base = CVPixelBufferGetBaseAddressOfPlane(pixel, plane);
        size_t rows = CVPixelBufferGetHeightOfPlane(pixel, plane);
        size_t stride = CVPixelBufferGetBytesPerRowOfPlane(pixel, plane);
        memset(base, plane == 0 ? 0x90 : 0x80, rows * stride);
    }
    CVPixelBufferUnlockBaseAddress(pixel, 0);
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

static int gray_of(id contents)
{
    if (!contents || CFGetTypeID((__bridge CFTypeRef)contents) != CGImageGetTypeID())
        return -1;
    unsigned char pixel[4] = {0, 0, 0, 0};
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixel, 1, 1, 8, 4, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    CGContextDrawImage(context, CGRectMake(0, 0, 1, 1), (__bridge CGImageRef)contents);
    CGContextRelease(context);
    return pixel[0] == pixel[1] && pixel[1] == pixel[2] ? pixel[0] : -2;
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
        OSType format;
        const char *name;
    } formats[] = {
        {kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, "420v"},
        {kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, "420f"},
    };
    for (size_t index = 0; index < sizeof formats / sizeof formats[0]; index++) {
        @autoreleasepool {
            AVSampleBufferDisplayLayer *layer = [[AVSampleBufferDisplayLayer alloc] init];
            CMSampleBufferRef sample = planar_sample(formats[index].format);
            revenant_expect_true([NSString stringWithFormat:@"a %s sample buffer is made", formats[index].name],
                                 (sample != NULL) != flip, @"no sample buffer");
            if (!sample)
                continue;
            [layer enqueueSampleBuffer:sample];
            CFRelease(sample);
            spin();
            revenant_expect_true([NSString stringWithFormat:@"a %s frame is drawn", formats[index].name],
                                 (layer.contents != nil && layer.status != AVQueuedSampleBufferRenderingStatusFailed) != flip,
                                 [NSString stringWithFormat:@"contents %d status %ld", layer.contents != nil, (long)layer.status]);
            int expected = formats[index].format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange ? 144 : 149;
            int gray = gray_of(layer.contents);
            revenant_expect_true([NSString stringWithFormat:@"a %s frame with neutral chroma is a gray of %d", formats[index].name, expected],
                                 (gray >= expected - 2 && gray <= expected + 2) != flip,
                                 [NSString stringWithFormat:@"gray %d", gray]);
        }
    }
}
