#import "../app/revenant_check.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <QuartzCore/QuartzCore.h>

static CMSampleBufferRef revenant_sample(CMTime presentation, BOOL immediate, BOOL display)
{
    CVPixelBufferRef pixel = NULL;
    if (CVPixelBufferCreate(kCFAllocatorDefault, 4, 4, kCVPixelFormatType_32BGRA, NULL, &pixel) != kCVReturnSuccess || !pixel)
        return NULL;
    CVPixelBufferLockBaseAddress(pixel, 0);
    memset(CVPixelBufferGetBaseAddress(pixel), 0x80, CVPixelBufferGetDataSize(pixel));
    CVPixelBufferUnlockBaseAddress(pixel, 0);
    CMSampleBufferRef sample = NULL;
    CMVideoFormatDescriptionRef format = NULL;
    if (CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixel, &format) == noErr) {
        CMSampleTimingInfo timing = {kCMTimeInvalid, presentation, kCMTimeInvalid};
        CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixel, true, NULL, NULL, format, &timing, &sample);
        CFRelease(format);
    }
    CVPixelBufferRelease(pixel);
    if (sample) {
        CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sample, true);
        if (attachments && CFArrayGetCount(attachments) > 0) {
            CFMutableDictionaryRef values = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
            if (immediate)
                CFDictionarySetValue(values, kCMSampleAttachmentKey_DisplayImmediately, kCFBooleanTrue);
            if (!display)
                CFDictionarySetValue(values, kCMSampleAttachmentKey_DoNotDisplay, kCFBooleanTrue);
        }
    }
    return sample;
}

static void revenant_spin(void)
{
    for (int index = 0; index < 40; index++) {
        @autoreleasepool {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
        }
    }
}

REVENANT_CASE(avfoundation_display_layer)
{
    @autoreleasepool {
        AVSampleBufferDisplayLayer *layer = [[AVSampleBufferDisplayLayer alloc] init];
        CMTimebaseRef timebase = layer.timebase;
        revenant_expect_true(@"the layer owns a timebase", (timebase != NULL) != (BOOL)negative, @"no timebase");

        CMSampleBufferRef early = revenant_sample(CMTimeMake(2, 1), NO, YES);
        CMSampleBufferRef later = revenant_sample(CMTimeMake(3, 1), NO, YES);
        CMSampleBufferRef last = revenant_sample(CMTimeMake(4, 1), NO, YES);
        [layer enqueueSampleBuffer:early];
        [layer enqueueSampleBuffer:later];
        [layer enqueueSampleBuffer:last];
        CFRelease(early);
        CFRelease(later);
        CFRelease(last);
        revenant_spin();
        revenant_expect_true(@"a frame two seconds away is not drawn before its timestamp",
                             (layer.contents == nil) != (BOOL)negative, @"the frame was drawn early");
        revenant_expect_true(@"a full pending queue is not ready for more media",
                             (!layer.isReadyForMoreMediaData) != (BOOL)negative, @"the layer stayed ready");

        CMTimebaseSetTime(timebase, CMTimeMake(2, 1));
        revenant_spin();
        revenant_expect_true(@"the frame is drawn once the timebase reaches its timestamp",
                             (layer.contents != nil) != (BOOL)negative, @"the frame was not drawn");

        [layer flushAndRemoveImage];
        revenant_spin();
        revenant_expect_true(@"flushAndRemoveImage leaves no image",
                             (layer.contents == nil) != (BOOL)negative, @"an image survived the flush");
        revenant_expect_true(@"a flushed layer is ready for media again",
                             (layer.isReadyForMoreMediaData && layer.status == AVQueuedSampleBufferRenderingStatusUnknown) != (BOOL)negative,
                             [NSString stringWithFormat:@"ready %d status %ld", (int)layer.isReadyForMoreMediaData, (long)layer.status]);

        CMSampleBufferRef hidden = revenant_sample(kCMTimeZero, YES, NO);
        [layer enqueueSampleBuffer:hidden];
        CFRelease(hidden);
        revenant_spin();
        revenant_expect_true(@"a DoNotDisplay frame does not change the contents",
                             (layer.contents == nil) != (BOOL)negative, @"a hidden frame was drawn");

        CMSampleBufferRef now = revenant_sample(kCMTimeZero, YES, YES);
        [layer enqueueSampleBuffer:now];
        CFRelease(now);
        revenant_spin();
        revenant_expect_true(@"a DisplayImmediately frame is drawn without waiting for the timebase",
                             (layer.contents != nil && layer.isReadyForDisplay) != (BOOL)negative, @"the immediate frame was not drawn");
    }

    @autoreleasepool {
        AVSampleBufferDisplayLayer *scrubbed = [[AVSampleBufferDisplayLayer alloc] init];
        CMTimebaseRef control = NULL;
        CMTimebaseCreateWithMasterClock(kCFAllocatorDefault, CMClockGetHostTimeClock(), &control);
        scrubbed.controlTimebase = control;
        CMSampleBufferRef frame = revenant_sample(CMTimeMake(2, 1), NO, YES);
        [scrubbed enqueueSampleBuffer:frame];
        CFRelease(frame);
        revenant_spin();
        revenant_expect_true(@"a frame at 2 s is not drawn while the control timebase is at 0",
                             (scrubbed.contents == nil) != (BOOL)negative, @"the frame was drawn early");
        CMTimebaseSetTime(control, CMTimeMake(2, 1));
        revenant_spin();
        revenant_expect_true(@"a jump of a paused control timebase to the frame's time draws it",
                             (scrubbed.contents != nil) != (BOOL)negative, @"the frame was not drawn");
        scrubbed.controlTimebase = NULL;
        CFRelease(control);
    }

    __weak AVSampleBufferDisplayLayer *weakLayer = nil;
    @autoreleasepool {
        AVSampleBufferDisplayLayer *temporary = [[AVSampleBufferDisplayLayer alloc] init];
        weakLayer = temporary;
        revenant_expect_true(@"a live layer has a weak reference", (weakLayer != nil) != (BOOL)negative, @"weak reference was nil");
    }
    revenant_expect_true(@"the timebase timer does not retain its layer",
                         (weakLayer == nil) != (BOOL)negative, @"the layer leaked after its pool ended");
}
