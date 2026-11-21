#import "../app/revenant_check.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>

@interface RevenantDisplayLayerObserver : NSObject
{
@public
    int status;
    int ready;
}
@end

@implementation RevenantDisplayLayerObserver

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
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

static NSString *state_of(AVSampleBufferDisplayLayer *layer)
{
    return [NSString stringWithFormat:@"status %ld ready %d", (long)layer.status, (int)layer.isReadyForDisplay];
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

    __weak AVSampleBufferDisplayLayer *weakLayer = nil;
    @autoreleasepool {
        AVSampleBufferDisplayLayer *temporary = [[AVSampleBufferDisplayLayer alloc] init];
        (void)temporary.timebase;
        (void)temporary.status;
        weakLayer = temporary;
    }
    revenant_expect_true(@"a layer that held state and a timebase is released with its pool", (weakLayer == nil) != flip,
                         @"the layer leaked after its pool ended");
}
