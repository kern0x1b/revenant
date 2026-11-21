#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <objc/runtime.h>

@interface RevenantDisplayLayerState : NSObject
{
@public
    AVQueuedSampleBufferRenderingStatus status;
    NSError *error;
    BOOL readyForDisplay;
    BOOL preventsCapture;
    BOOL preventsDisplaySleep;
    CMTimebaseRef ownTimebase;
}
@end

@implementation RevenantDisplayLayerState

- (void)dealloc
{
    if (ownTimebase)
        CFRelease(ownTimebase);
}

@end

static char revenant_state_key;

static RevenantDisplayLayerState *revenant_state(AVSampleBufferDisplayLayer *layer)
{
    RevenantDisplayLayerState *state = objc_getAssociatedObject(layer, &revenant_state_key);
    if (state)
        return state;
    @synchronized (layer) {
        state = objc_getAssociatedObject(layer, &revenant_state_key);
        if (!state) {
            state = [[RevenantDisplayLayerState alloc] init];
            objc_setAssociatedObject(layer, &revenant_state_key, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    return state;
}

static BOOL revenant_attachment(CMSampleBufferRef sample, CFStringRef key)
{
    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sample, false);
    if (!attachments || CFArrayGetCount(attachments) == 0)
        return NO;
    CFDictionaryRef values = CFArrayGetValueAtIndex(attachments, 0);
    return CFDictionaryGetValue(values, key) == kCFBooleanTrue;
}

static void revenant_note_enqueued(AVSampleBufferDisplayLayer *layer, BOOL displayable)
{
    RevenantDisplayLayerState *state = revenant_state(layer);
    BOOL statusChanges, readyChanges;
    @synchronized (state) {
        statusChanges = state->status == AVQueuedSampleBufferRenderingStatusUnknown;
        readyChanges = displayable && !state->readyForDisplay;
    }
    if (statusChanges)
        [layer willChangeValueForKey:@"status"];
    if (readyChanges)
        [layer willChangeValueForKey:@"readyForDisplay"];
    @synchronized (state) {
        if (statusChanges)
            state->status = AVQueuedSampleBufferRenderingStatusRendering;
        if (readyChanges)
            state->readyForDisplay = YES;
    }
    if (readyChanges)
        [layer didChangeValueForKey:@"readyForDisplay"];
    if (statusChanges)
        [layer didChangeValueForKey:@"status"];
}

static void revenant_note_flushed(AVSampleBufferDisplayLayer *layer)
{
    RevenantDisplayLayerState *state = revenant_state(layer);
    BOOL statusChanges, readyChanges;
    @synchronized (state) {
        statusChanges = state->status != AVQueuedSampleBufferRenderingStatusUnknown;
        readyChanges = state->readyForDisplay;
    }
    if (statusChanges)
        [layer willChangeValueForKey:@"status"];
    if (readyChanges)
        [layer willChangeValueForKey:@"readyForDisplay"];
    @synchronized (state) {
        state->status = AVQueuedSampleBufferRenderingStatusUnknown;
        state->error = nil;
        state->readyForDisplay = NO;
    }
    if (readyChanges)
        [layer didChangeValueForKey:@"readyForDisplay"];
    if (statusChanges)
        [layer didChangeValueForKey:@"status"];
}

static void (*revenant_system_enqueue)(id, SEL, CMSampleBufferRef);
static void (*revenant_system_flush)(id, SEL);
static void (*revenant_system_flush_and_remove)(id, SEL);

static void revenant_enqueue(AVSampleBufferDisplayLayer *self, SEL _cmd, CMSampleBufferRef sampleBuffer)
{
    if (!sampleBuffer)
        [NSException raise:NSInvalidArgumentException
                    format:@"-[AVSampleBufferDisplayLayer enqueueSampleBuffer:] was given no sample buffer"];
    revenant_system_enqueue(self, _cmd, sampleBuffer);
    revenant_note_enqueued(self, !revenant_attachment(sampleBuffer, kCMSampleAttachmentKey_DoNotDisplay));
}

static void revenant_flush(AVSampleBufferDisplayLayer *self, SEL _cmd)
{
    revenant_system_flush(self, _cmd);
    revenant_note_flushed(self);
}

static void revenant_flush_and_remove_image(AVSampleBufferDisplayLayer *self, SEL _cmd)
{
    revenant_system_flush_and_remove(self, _cmd);
    revenant_note_flushed(self);
}

static IMP revenant_wrap(Class cls, SEL selector, IMP replacement)
{
    Method method = class_getInstanceMethod(cls, selector);
    if (!method)
        return NULL;
    IMP original = method_getImplementation(method);
    method_setImplementation(method, replacement);
    return original;
}

@interface RevenantDisplayLayerInstall : NSObject
@end

@implementation RevenantDisplayLayerInstall

+ (void)load
{
    Class layer = objc_getClass("AVSampleBufferDisplayLayer");
    if (!layer)
        return;
    revenant_system_enqueue = (void (*)(id, SEL, CMSampleBufferRef))revenant_wrap(layer, @selector(enqueueSampleBuffer:), (IMP)revenant_enqueue);
    revenant_system_flush = (void (*)(id, SEL))revenant_wrap(layer, @selector(flush), (IMP)revenant_flush);
    revenant_system_flush_and_remove = (void (*)(id, SEL))revenant_wrap(layer, @selector(flushAndRemoveImage), (IMP)revenant_flush_and_remove_image);
}

@end

@implementation AVSampleBufferDisplayLayer (RevenantQueuedRendering)

- (CMTimebaseRef)timebase
{
    CMTimebaseRef current = self.controlTimebase;
    if (current)
        return current;
    RevenantDisplayLayerState *state = revenant_state(self);
    @synchronized (state) {
        current = self.controlTimebase;
        if (!current && !state->ownTimebase)
            CMTimebaseCreateWithMasterClock(kCFAllocatorDefault, CMClockGetHostTimeClock(), &state->ownTimebase);
        if (!current && state->ownTimebase)
            self.controlTimebase = state->ownTimebase;
        return self.controlTimebase;
    }
}

- (AVQueuedSampleBufferRenderingStatus)status
{
    RevenantDisplayLayerState *state = revenant_state(self);
    @synchronized (state) {
        return state->status;
    }
}

- (NSError *)error
{
    RevenantDisplayLayerState *state = revenant_state(self);
    @synchronized (state) {
        return state->error;
    }
}

- (BOOL)isReadyForDisplay
{
    RevenantDisplayLayerState *state = revenant_state(self);
    @synchronized (state) {
        return state->readyForDisplay;
    }
}

- (BOOL)hasSufficientMediaDataForReliablePlaybackStart
{
    RevenantDisplayLayerState *state = revenant_state(self);
    @synchronized (state) {
        return state->readyForDisplay;
    }
}

- (BOOL)requiresFlushToResumeDecoding
{
    return self.status == AVQueuedSampleBufferRenderingStatusFailed;
}

- (BOOL)outputObscuredDueToInsufficientExternalProtection
{
    return NO;
}

- (BOOL)preventsCapture
{
    RevenantDisplayLayerState *state = revenant_state(self);
    @synchronized (state) {
        return state->preventsCapture;
    }
}

- (void)setPreventsCapture:(BOOL)preventsCapture
{
    RevenantDisplayLayerState *state = revenant_state(self);
    @synchronized (state) {
        state->preventsCapture = preventsCapture;
    }
}

- (BOOL)preventsDisplaySleepDuringVideoPlayback
{
    RevenantDisplayLayerState *state = revenant_state(self);
    @synchronized (state) {
        return state->preventsDisplaySleep;
    }
}

- (void)setPreventsDisplaySleepDuringVideoPlayback:(BOOL)preventsDisplaySleep
{
    RevenantDisplayLayerState *state = revenant_state(self);
    @synchronized (state) {
        state->preventsDisplaySleep = preventsDisplaySleep;
    }
}

- (id)sampleBufferRenderer
{
    return nil;
}

@end
