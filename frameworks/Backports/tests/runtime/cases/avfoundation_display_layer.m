#import "../app/revenant_check.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreGraphics/CoreGraphics.h>
#import <QuartzCore/QuartzCore.h>

@interface RevenantDisplayLayerObserver : NSObject
{
@public
    int status;
    int ready;
    int offMain;
    BOOL reentered;
    AVSampleBufferDisplayLayer *reenterLayer;
    CMSampleBufferRef reenterSample;
}
@end

@implementation RevenantDisplayLayerObserver

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (![NSThread isMainThread])
        offMain++;
    if (reenterLayer && !reentered) {
        reentered = YES;
        [reenterLayer enqueueSampleBuffer:reenterSample];
    }
    if ([keyPath isEqualToString:@"status"])
        status++;
    else if ([keyPath isEqualToString:@"readyForDisplay"])
        ready++;
}

@end

static CMSampleBufferRef revenant_sample(BOOL display)
{
    CVPixelBufferRef pixel = NULL;
    NSDictionary *attributes = @{(__bridge id)kCVPixelBufferIOSurfacePropertiesKey: @{}};
    if (CVPixelBufferCreate(kCFAllocatorDefault, 16, 16, kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef)attributes, &pixel) != kCVReturnSuccess || !pixel)
        return NULL;
    CVPixelBufferLockBaseAddress(pixel, 0);
    memset(CVPixelBufferGetBaseAddress(pixel), 0x80, CVPixelBufferGetDataSize(pixel));
    CVPixelBufferUnlockBaseAddress(pixel, 0);
    CMSampleBufferRef sample = NULL;
    CMVideoFormatDescriptionRef format = NULL;
    if (CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixel, &format) == noErr) {
        CMSampleTimingInfo timing = {kCMTimeInvalid, kCMTimeZero, kCMTimeInvalid};
        CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixel, true, NULL, NULL, format, &timing, &sample);
        CFRelease(format);
    }
    CVPixelBufferRelease(pixel);
    if (sample) {
        CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sample, true);
        if (attachments && CFArrayGetCount(attachments) > 0) {
            CFMutableDictionaryRef values = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
            CFDictionarySetValue(values, kCMSampleAttachmentKey_DisplayImmediately, kCFBooleanTrue);
            if (!display)
                CFDictionarySetValue(values, kCMSampleAttachmentKey_DoNotDisplay, kCFBooleanTrue);
        }
    }
    return sample;
}

static void spin_run_loop(void)
{
    for (int index = 0; index < 10; index++) {
        @autoreleasepool {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
        }
    }
}

static NSString *state_of(AVSampleBufferDisplayLayer *layer)
{
    return [NSString stringWithFormat:@"status %ld ready %d", (long)layer.status, (int)layer.isReadyForDisplay];
}

static BOOL released_after(int touch)
{
    __weak AVSampleBufferDisplayLayer *weakLayer = nil;
    @autoreleasepool {
        AVSampleBufferDisplayLayer *temporary = [[AVSampleBufferDisplayLayer alloc] init];
        if (touch == 1)
            (void)temporary.status;
        if (touch == 2)
            (void)temporary.timebase;
        weakLayer = temporary;
    }
    for (int index = 0; index < 15 && weakLayer; index++) {
        @autoreleasepool {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
        }
    }
    return weakLayer == nil;
}

REVENANT_CASE(avfoundation_display_layer)
{
    BOOL flip = (BOOL)negative;
    @autoreleasepool {
        AVSampleBufferDisplayLayer *layer = [[AVSampleBufferDisplayLayer alloc] init];
        RevenantDisplayLayerObserver *observer = [[RevenantDisplayLayerObserver alloc] init];
        [layer addObserver:observer forKeyPath:@"status" options:0 context:NULL];
        [layer addObserver:observer forKeyPath:@"readyForDisplay" options:0 context:NULL];

        revenant_expect_true(@"a new layer has status Unknown, no error and is not ready for display",
                             (layer.status == AVQueuedSampleBufferRenderingStatusUnknown && layer.error == nil && !layer.isReadyForDisplay
                              && !layer.requiresFlushToResumeDecoding && !layer.hasSufficientMediaDataForReliablePlaybackStart
                              && !layer.outputObscuredDueToInsufficientExternalProtection) != flip,
                             state_of(layer));

        CMSampleBufferRef shown = revenant_sample(YES);
        revenant_expect_true(@"a sample buffer for the test is made", (shown != NULL) != flip, @"no sample buffer");
        if (shown) {
            [layer enqueueSampleBuffer:shown];
            revenant_expect_true(@"an enqueued frame to display makes the status Rendering and the layer ready for display",
                                 (layer.status == AVQueuedSampleBufferRenderingStatusRendering && layer.isReadyForDisplay
                                  && layer.hasSufficientMediaDataForReliablePlaybackStart) != flip,
                                 state_of(layer));
            revenant_expect_true(@"status and readyForDisplay each notify an observer once",
                                 (observer->status == 1 && observer->ready == 1) != flip,
                                 [NSString stringWithFormat:@"status %d ready %d", observer->status, observer->ready]);
            [layer enqueueSampleBuffer:shown];
            revenant_expect_true(@"a second frame notifies nobody",
                                 (observer->status == 1 && observer->ready == 1) != flip,
                                 [NSString stringWithFormat:@"status %d ready %d", observer->status, observer->ready]);
            [layer flush];
            revenant_expect_true(@"flush returns the layer to Unknown and not ready, and notifies",
                                 (layer.status == AVQueuedSampleBufferRenderingStatusUnknown && !layer.isReadyForDisplay
                                  && observer->status == 2 && observer->ready == 2) != flip,
                                 [NSString stringWithFormat:@"%@, notified status %d ready %d", state_of(layer), observer->status, observer->ready]);
            [layer enqueueSampleBuffer:shown];
            [layer flushAndRemoveImage];
            revenant_expect_true(@"flushAndRemoveImage returns the layer to Unknown and not ready",
                                 (layer.status == AVQueuedSampleBufferRenderingStatusUnknown && !layer.isReadyForDisplay) != flip,
                                 state_of(layer));
            CFRelease(shown);
        }

        CMSampleBufferRef hidden = revenant_sample(NO);
        if (hidden) {
            [layer enqueueSampleBuffer:hidden];
            revenant_expect_true(@"a DoNotDisplay frame makes the status Rendering and leaves the layer not ready for display",
                                 (layer.status == AVQueuedSampleBufferRenderingStatusRendering && !layer.isReadyForDisplay) != flip,
                                 state_of(layer));
            CFRelease(hidden);
        }

        AVSampleBufferDisplayLayer *drawn = [[AVSampleBufferDisplayLayer alloc] init];
        CMSampleBufferRef frame = revenant_sample(YES);
        CMSampleBufferRef skipped = revenant_sample(NO);
        if (frame && skipped) {
            [drawn enqueueSampleBuffer:skipped];
            spin_run_loop();
            BOOL skippedDraws = drawn.contents != nil;
            [drawn enqueueSampleBuffer:frame];
            spin_run_loop();
            BOOL drawsFrame = drawn.contents != nil;
            [drawn flush];
            spin_run_loop();
            BOOL keepsAfterFlush = drawn.contents != nil;
            [drawn flushAndRemoveImage];
            spin_run_loop();
            BOOL clearsAfterRemove = drawn.contents == nil;
            printf("display layer fact: uncompressed frame drawn %d, skipped frame drawn %d, kept after flush %d, cleared by flushAndRemoveImage %d\n",
                   drawsFrame, skippedDraws, keepsAfterFlush, clearsAfterRemove);
            revenant_expect_true(@"an uncompressed frame to display becomes the layer's contents and a DoNotDisplay frame does not",
                                 (drawsFrame && !skippedDraws) != flip, @"the contents did not follow the frames");
            revenant_expect_true(@"flush keeps the image and flushAndRemoveImage removes it",
                                 (keepsAfterFlush && clearsAfterRemove) != flip, @"the image outlived flushAndRemoveImage or went at flush");
        }
        if (frame)
            CFRelease(frame);
        if (skipped)
            CFRelease(skipped);

        AVSampleBufferDisplayLayer *busy = [[AVSampleBufferDisplayLayer alloc] init];
        RevenantDisplayLayerObserver *busyObserver = [[RevenantDisplayLayerObserver alloc] init];
        CMSampleBufferRef busySample = revenant_sample(YES);
        if (busySample) {
            [busy addObserver:busyObserver forKeyPath:@"status" options:0 context:NULL];
            [busy addObserver:busyObserver forKeyPath:@"readyForDisplay" options:0 context:NULL];
            busyObserver->reenterLayer = busy;
            busyObserver->reenterSample = busySample;
            dispatch_group_t group = dispatch_group_create();
            for (int worker = 0; worker < 4; worker++) {
                dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    for (int count = 0; count < 20; count++)
                        [busy enqueueSampleBuffer:busySample];
                });
            }
            dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
            for (int index = 0; index < 5; index++)
                spin_run_loop();
            printf("display layer fact: four queues enqueued, observer saw status %d ready %d off the main thread %d\n",
                   busyObserver->status, busyObserver->ready, busyObserver->offMain);
            revenant_expect_true(@"enqueues from four queues, one of them from inside an observer, notify status and readyForDisplay once each, on the main thread",
                                 (busyObserver->status == 1 && busyObserver->ready == 1 && busyObserver->offMain == 0) != flip,
                                 [NSString stringWithFormat:@"status %d ready %d off main %d", busyObserver->status, busyObserver->ready, busyObserver->offMain]);
            [busy removeObserver:busyObserver forKeyPath:@"status"];
            [busy removeObserver:busyObserver forKeyPath:@"readyForDisplay"];
            busyObserver->reenterLayer = nil;
            CFRelease(busySample);
        }

        AVSampleBufferDisplayLayer *later = [[AVSampleBufferDisplayLayer alloc] init];
        later.frame = CGRectMake(0, 0, 16, 16);
        CMTimebaseRef clock = NULL;
        CMTimebaseCreateWithMasterClock(kCFAllocatorDefault, CMClockGetHostTimeClock(), &clock);
        CMTimebaseSetTime(clock, CMClockGetTime(CMClockGetHostTimeClock()));
        CMTimebaseSetRate(clock, 1.0);
        later.controlTimebase = clock;
        CVPixelBufferRef pixel = NULL;
        NSDictionary *attributes = @{(__bridge id)kCVPixelBufferIOSurfacePropertiesKey: @{}};
        CVPixelBufferCreate(kCFAllocatorDefault, 16, 16, kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef)attributes, &pixel);
        CMSampleBufferRef timed = NULL;
        if (pixel) {
            CVPixelBufferLockBaseAddress(pixel, 0);
            uint8_t *bytes = CVPixelBufferGetBaseAddress(pixel);
            for (size_t offset = 0; offset < CVPixelBufferGetDataSize(pixel); offset += 4) {
                bytes[offset] = 0;
                bytes[offset + 1] = 0;
                bytes[offset + 2] = 255;
                bytes[offset + 3] = 255;
            }
            CVPixelBufferUnlockBaseAddress(pixel, 0);
            CMVideoFormatDescriptionRef description = NULL;
            CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixel, &description);
            CMSampleTimingInfo timing = {kCMTimeInvalid, CMTimeAdd(CMClockGetTime(CMClockGetHostTimeClock()), CMTimeMake(3, 10)), kCMTimeInvalid};
            CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixel, true, NULL, NULL, description, &timing, &timed);
            if (description)
                CFRelease(description);
        }
        if (timed) {
            [later enqueueSampleBuffer:timed];
            CVPixelBufferLockBaseAddress(pixel, 0);
            memset(CVPixelBufferGetBaseAddress(pixel), 0xFF, CVPixelBufferGetDataSize(pixel));
            CVPixelBufferUnlockBaseAddress(pixel, 0);
            CFRelease(timed);
            CVPixelBufferRelease(pixel);
            spin_run_loop();
            BOOL waits = later.contents == nil;
            for (int index = 0; index < 40 && later.contents == nil; index++)
                spin_run_loop();
            BOOL arrived = later.contents != nil;
            unsigned char shown[4] = {0, 0, 0, 0};
            if (arrived) {
                CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
                CGContextRef context = CGBitmapContextCreate(shown, 1, 1, 8, 4, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
                CGContextTranslateCTM(context, -8, -8);
                [later renderInContext:context];
                CGContextRelease(context);
                CGColorSpaceRelease(space);
            }
            printf("display layer fact: timed frame waited %d, arrived %d, centre rgba %u %u %u %u after its buffer was overwritten and released\n",
                   waits, arrived, shown[0], shown[1], shown[2], shown[3]);
            revenant_expect_true(@"a frame due later waits, and shows the colour it had when it was enqueued after its pixel buffer was overwritten and released",
                                 (waits && arrived && shown[0] > 200 && shown[1] < 50 && shown[2] < 50) != flip,
                                 [NSString stringWithFormat:@"waits %d arrived %d rgb %u %u %u", waits, arrived, shown[0], shown[1], shown[2]]);
        }
        if (clock)
            CFRelease(clock);

        BOOL raised = NO;
        @try {
            [layer enqueueSampleBuffer:NULL];
        } @catch (NSException *exception) {
            raised = [exception.name isEqualToString:NSInvalidArgumentException];
        }
        revenant_expect_true(@"enqueueSampleBuffer: with no sample buffer raises NSInvalidArgumentException", raised != flip, @"nothing was raised");

        AVSampleBufferDisplayLayer *other = [[AVSampleBufferDisplayLayer alloc] init];
        revenant_expect_true(@"the state belongs to the layer: another layer is still Unknown",
                             (other.status == AVQueuedSampleBufferRenderingStatusUnknown && !other.isReadyForDisplay) != flip,
                             state_of(other));

        CMTimebaseRef timebase = other.timebase;
        revenant_expect_true(@"timebase is a timebase, the same each time, and the layer's control timebase",
                             (timebase != NULL && timebase == other.timebase && timebase == other.controlTimebase) != flip,
                             [NSString stringWithFormat:@"%p %p %p", timebase, other.timebase, other.controlTimebase]);
        CMTimebaseRef control = NULL;
        CMTimebaseCreateWithMasterClock(kCFAllocatorDefault, CMClockGetHostTimeClock(), &control);
        other.controlTimebase = control;
        revenant_expect_true(@"a control timebase the caller sets is the layer's timebase",
                             (other.timebase == control) != flip, [NSString stringWithFormat:@"%p against %p", other.timebase, control]);

        layer.preventsCapture = YES;
        layer.preventsDisplaySleepDuringVideoPlayback = YES;
        revenant_expect_true(@"preventsCapture and preventsDisplaySleepDuringVideoPlayback hold what is set, per layer",
                             (layer.preventsCapture && layer.preventsDisplaySleepDuringVideoPlayback && !other.preventsCapture
                              && !other.preventsDisplaySleepDuringVideoPlayback) != flip,
                             @"values differ");

        [layer removeObserver:observer forKeyPath:@"status"];
        [layer removeObserver:observer forKeyPath:@"readyForDisplay"];
    }

    BOOL plain = released_after(0), stateful = released_after(1), timed = released_after(2);
    printf("display layer fact: released after its pool: untouched %d, with status read %d, with timebase made %d\n", plain, stateful, timed);
    revenant_expect_true(@"a layer that held state or a timebase is released whenever an untouched system layer is",
                         (!plain || (stateful && timed)) != flip,
                         [NSString stringWithFormat:@"untouched %d, status %d, timebase %d", plain, stateful, timed]);
    fflush(stdout);
}
