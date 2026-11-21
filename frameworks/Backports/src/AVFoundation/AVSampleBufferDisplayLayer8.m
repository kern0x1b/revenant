#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <QuartzCore/QuartzCore.h>
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
    NSUInteger generation;
    BOOL showsPixels;
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

static NSString *revenant_contents_gravity(id gravity)
{
    if ([gravity isEqualToString:AVLayerVideoGravityResizeAspectFill])
        return kCAGravityResizeAspectFill;
    if ([gravity isEqualToString:AVLayerVideoGravityResize])
        return kCAGravityResize;
    return kCAGravityResizeAspect;
}

static void revenant_release_pixels(void *info, const void *data, size_t size)
{
    free((void *)data);
}

static int revenant_clamp_byte(int value)
{
    return value < 0 ? 0 : (value > 255 ? 255 : value);
}

static CGImageRef revenant_copy_planar_image(CVPixelBufferRef image, CMFormatDescriptionRef description, BOOL fullRange)
{
    size_t width = CVPixelBufferGetWidth(image);
    size_t height = CVPixelBufferGetHeight(image);
    if (!width || !height || CVPixelBufferGetPlaneCount(image) != 2)
        return NULL;
    CFTypeRef matrix = CVBufferGetAttachment(image, CFSTR("YCbCrMatrix"), NULL);
    if (!matrix && description)
        matrix = CMFormatDescriptionGetExtension(description, CFSTR("YCbCrMatrix"));
    BOOL highDefinition = YES;
    if (matrix) {
        if (CFGetTypeID(matrix) != CFStringGetTypeID())
            return NULL;
        if (CFEqual(matrix, CFSTR("ITU_R_601_4")))
            highDefinition = NO;
        else if (!CFEqual(matrix, CFSTR("ITU_R_709_2")))
            return NULL;
    }
    int redChroma = highDefinition ? (fullRange ? 403 : 459) : (fullRange ? 359 : 409);
    int greenBlue = highDefinition ? (fullRange ? 48 : 55) : (fullRange ? 88 : 100);
    int greenRed = highDefinition ? (fullRange ? 120 : 136) : (fullRange ? 183 : 208);
    int blueChroma = highDefinition ? (fullRange ? 475 : 541) : (fullRange ? 454 : 516);
    size_t stride = width * 4;
    unsigned char *pixels = malloc(stride * height);
    if (!pixels)
        return NULL;
    if (CVPixelBufferLockBaseAddress(image, kCVPixelBufferLock_ReadOnly) != kCVReturnSuccess) {
        free(pixels);
        return NULL;
    }
    const unsigned char *luma = CVPixelBufferGetBaseAddressOfPlane(image, 0);
    const unsigned char *chroma = CVPixelBufferGetBaseAddressOfPlane(image, 1);
    size_t lumaStride = CVPixelBufferGetBytesPerRowOfPlane(image, 0);
    size_t chromaStride = CVPixelBufferGetBytesPerRowOfPlane(image, 1);
    BOOL readable = luma && chroma;
    for (size_t y = 0; readable && y < height; y++) {
        const unsigned char *lumaRow = luma + y * lumaStride;
        const unsigned char *chromaRow = chroma + (y / 2) * chromaStride;
        unsigned char *out = pixels + y * stride;
        for (size_t x = 0; x < width; x++) {
            int cb = chromaRow[(x / 2) * 2] - 128;
            int cr = chromaRow[(x / 2) * 2 + 1] - 128;
            int scaled = fullRange ? lumaRow[x] * 256 : (lumaRow[x] - 16) * 298;
            out[x * 4] = (unsigned char)revenant_clamp_byte((scaled + blueChroma * cb + 128) >> 8);
            out[x * 4 + 1] = (unsigned char)revenant_clamp_byte((scaled - greenBlue * cb - greenRed * cr + 128) >> 8);
            out[x * 4 + 2] = (unsigned char)revenant_clamp_byte((scaled + redChroma * cr + 128) >> 8);
            out[x * 4 + 3] = 255;
        }
    }
    CVPixelBufferUnlockBaseAddress(image, kCVPixelBufferLock_ReadOnly);
    if (!readable) {
        free(pixels);
        return NULL;
    }
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, pixels, stride * height, revenant_release_pixels);
    if (!provider) {
        free(pixels);
        return NULL;
    }
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGImageRef frame = CGImageCreate(width, height, 8, 32, stride, space,
                                     (CGBitmapInfo)(kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst),
                                     provider, NULL, false, kCGRenderingIntentDefault);
    CGColorSpaceRelease(space);
    CGDataProviderRelease(provider);
    return frame;
}

static CGImageRef revenant_copy_image(CMSampleBufferRef sample)
{
    CVPixelBufferRef image = CMSampleBufferGetImageBuffer(sample);
    if (!image)
        return NULL;
    CGImageRef frame = NULL;
    OSType format = CVPixelBufferGetPixelFormatType(image);
    CGBitmapInfo info = 0;
    BOOL direct = NO;
    if (format == kCVPixelFormatType_32BGRA) {
        info = (CGBitmapInfo)(kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst);
        direct = YES;
    } else if (format == kCVPixelFormatType_32ARGB) {
        info = (CGBitmapInfo)(kCGBitmapByteOrder32Big | kCGImageAlphaNoneSkipFirst);
        direct = YES;
    }
    if (direct && CVPixelBufferLockBaseAddress(image, kCVPixelBufferLock_ReadOnly) == kCVReturnSuccess) {
        void *base = CVPixelBufferGetBaseAddress(image);
        size_t width = CVPixelBufferGetWidth(image);
        size_t height = CVPixelBufferGetHeight(image);
        size_t stride = CVPixelBufferGetBytesPerRow(image);
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        CGContextRef bitmap = base ? CGBitmapContextCreate(base, width, height, 8, stride, space, info) : NULL;
        if (bitmap) {
            frame = CGBitmapContextCreateImage(bitmap);
            CGContextRelease(bitmap);
        }
        CGColorSpaceRelease(space);
        CVPixelBufferUnlockBaseAddress(image, kCVPixelBufferLock_ReadOnly);
    }
    if (!frame && format == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
        frame = revenant_copy_planar_image(image, CMSampleBufferGetFormatDescription(sample), NO);
    else if (!frame && format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
        frame = revenant_copy_planar_image(image, CMSampleBufferGetFormatDescription(sample), YES);
    return frame;
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
        state->generation++;
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

static void revenant_show(AVSampleBufferDisplayLayer *layer, CGImageRef image, NSUInteger generation)
{
    RevenantDisplayLayerState *state = revenant_state(layer);
    @synchronized (state) {
        if (state->generation != generation)
            return;
        state->showsPixels = YES;
    }
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    layer.contentsGravity = revenant_contents_gravity(layer.videoGravity);
    layer.contents = (__bridge id)image;
    [CATransaction commit];
}

static void revenant_present_pixels(AVSampleBufferDisplayLayer *layer, CMSampleBufferRef sample)
{
    CGImageRef image = revenant_copy_image(sample);
    if (!image)
        return;
    RevenantDisplayLayerState *state = revenant_state(layer);
    NSUInteger generation;
    @synchronized (state) {
        generation = state->generation;
    }
    CMTime presentation = CMSampleBufferGetPresentationTimeStamp(sample);
    CMTimebaseRef timebase = layer.controlTimebase;
    double delay = 0;
    if (!revenant_attachment(sample, kCMSampleAttachmentKey_DisplayImmediately) && timebase && CMTIME_IS_NUMERIC(presentation)) {
        double wait = CMTimeGetSeconds(CMTimeSubtract(presentation, CMTimebaseGetTime(timebase)));
        double rate = CMTimebaseGetRate(timebase);
        if (wait > 0)
            delay = rate > 0 ? wait / rate : -1;
    }
    if (delay < 0) {
        CGImageRelease(image);
        return;
    }
    dispatch_time_t when = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC));
    dispatch_after(when, dispatch_get_main_queue(), ^{
        revenant_show(layer, image, generation);
        CGImageRelease(image);
    });
}

static void revenant_remove_pixels(AVSampleBufferDisplayLayer *layer)
{
    RevenantDisplayLayerState *state = revenant_state(layer);
    BOOL had;
    @synchronized (state) {
        had = state->showsPixels;
        state->showsPixels = NO;
    }
    if (!had)
        return;
    dispatch_async(dispatch_get_main_queue(), ^{
        RevenantDisplayLayerState *current = revenant_state(layer);
        BOOL again;
        @synchronized (current) {
            again = current->showsPixels;
        }
        if (again)
            return;
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        layer.contents = nil;
        [CATransaction commit];
    });
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
    BOOL displayable = !revenant_attachment(sampleBuffer, kCMSampleAttachmentKey_DoNotDisplay);
    revenant_note_enqueued(self, displayable);
    if (displayable && CMSampleBufferGetImageBuffer(sampleBuffer))
        revenant_present_pixels(self, sampleBuffer);
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
    revenant_remove_pixels(self);
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
