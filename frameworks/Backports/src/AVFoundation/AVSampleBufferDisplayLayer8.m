#import "RevenantAVSampleBufferRender.h"

#import <AVFoundation/AVFoundation.h>
#import <CoreImage/CoreImage.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <QuartzCore/QuartzCore.h>

@interface RevenantAVDisplayBuffer : NSObject
{
@public
    CMSampleBufferRef sample;
    CMTime presentation;
    BOOL display;
}
@end

@implementation RevenantAVDisplayBuffer

- (void)dealloc
{
    if (sample)
        CFRelease(sample);
}

@end

@interface AVSampleBufferDisplayLayer ()
{
@private
    CMTimebaseRef _timebase;
    CMTimebaseRef _controlTimebase;
    id _videoGravity;
    AVQueuedSampleBufferRenderingStatus _status;
    NSError *_error;
    BOOL _readyForDisplay;
    BOOL _preventsCapture;
    BOOL _preventsDisplaySleep;
    CIContext *_context;
    dispatch_queue_t _workQueue;
    dispatch_source_t _displaySource;
    NSMutableArray *_pending;
    NSUInteger _generation;
    dispatch_queue_t _requestQueue;
    void (^_requestBlock)(void);
    BOOL _requestActive;
}
- (BOOL)revenant_setupFromLayer:(id)layer;
- (void)revenant_presentDueFrames;
- (void)revenant_armDisplayTimer;
- (void)revenant_prepareBuffer:(RevenantAVDisplayBuffer *)buffer generation:(NSUInteger)generation;
- (void)revenant_invokeRequestIfNeeded;
- (void)revenant_failWithDescription:(NSString *)description;
@end

static const NSUInteger revenant_pending_limit = 3;

static NSString *revenant_contents_gravity(id gravity)
{
    if ([gravity isEqualToString:AVLayerVideoGravityResizeAspectFill])
        return kCAGravityResizeAspectFill;
    if ([gravity isEqualToString:AVLayerVideoGravityResize])
        return kCAGravityResize;
    return kCAGravityResizeAspect;
}

static BOOL revenant_attachment(CMSampleBufferRef sample, CFStringRef key)
{
    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sample, false);
    if (!attachments || CFArrayGetCount(attachments) == 0)
        return NO;
    CFDictionaryRef values = CFArrayGetValueAtIndex(attachments, 0);
    return CFDictionaryGetValue(values, key) == kCFBooleanTrue;
}

static CGImageRef revenant_copy_image(CMSampleBufferRef sample, CIContext *context)
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
    if (!frame && context) {
        CIImage *ci = [CIImage imageWithCVPixelBuffer:image];
        frame = ci ? [context createCGImage:ci fromRect:ci.extent] : NULL;
    }
    return frame;
}

@implementation AVSampleBufferDisplayLayer

- (BOOL)revenant_setupFromLayer:(id)layer
{
    if (CMTimebaseCreateWithMasterClock(kCFAllocatorDefault, CMClockGetHostTimeClock(), &_timebase) != noErr)
        return NO;
    _videoGravity = [AVLayerVideoGravityResizeAspect copy];
    _status = AVQueuedSampleBufferRenderingStatusUnknown;
    _context = [CIContext contextWithOptions:nil];
    _pending = [[NSMutableArray alloc] init];
    _workQueue = dispatch_queue_create("revenant.samplebuffer.display", DISPATCH_QUEUE_SERIAL);
    _displaySource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _workQueue);
    dispatch_resume(_displaySource);
    __weak AVSampleBufferDisplayLayer *weakSelf = self;
    dispatch_source_set_event_handler(_displaySource, ^{
        AVSampleBufferDisplayLayer *owner = weakSelf;
        if (owner)
            [owner revenant_presentDueFrames];
    });
    CMTimebaseAddTimerDispatchSource(_timebase, _displaySource);
    if ([layer isKindOfClass:[AVSampleBufferDisplayLayer class]]) {
        AVSampleBufferDisplayLayer *source = layer;
        id gravity = [source->_videoGravity copy];
        if (gravity)
            _videoGravity = gravity;
        _preventsCapture = source->_preventsCapture;
        _preventsDisplaySleep = source->_preventsDisplaySleep;
        if (source->_controlTimebase) {
            _controlTimebase = (CMTimebaseRef)CFRetain(source->_controlTimebase);
            CMTimebaseSetMasterTimebase(_timebase, _controlTimebase);
        }
    }
    return YES;
}

- (instancetype)init
{
    if (!(self = [super init]))
        return nil;
    if (![self revenant_setupFromLayer:nil])
        return nil;
    return self;
}

- (instancetype)initWithLayer:(id)layer
{
    if (!(self = [super initWithLayer:layer]))
        return nil;
    if (![self revenant_setupFromLayer:layer])
        return nil;
    return self;
}

- (void)dealloc
{
    _requestBlock = nil;
    _requestQueue = NULL;
    if (_timebase) {
        if (_displaySource) {
            CMTimebaseSetTimerDispatchSourceNextFireTime(_timebase, _displaySource, kCMTimeInvalid, 0);
            CMTimebaseRemoveTimerDispatchSource(_timebase, _displaySource);
            dispatch_source_cancel(_displaySource);
            dispatch_source_set_event_handler(_displaySource, NULL);
        }
        CFRelease(_timebase);
    }
    if (_controlTimebase)
        CFRelease(_controlTimebase);
}

#pragma mark - the clock

- (CMTimebaseRef)timebase
{
    return _timebase;
}

- (CMTimebaseRef)controlTimebase
{
    return _controlTimebase;
}

- (void)setControlTimebase:(CMTimebaseRef)controlTimebase
{
    @synchronized (self) {
        if (controlTimebase == _controlTimebase)
            return;
        if (_controlTimebase)
            CFRelease(_controlTimebase);
        _controlTimebase = controlTimebase ? (CMTimebaseRef)CFRetain(controlTimebase) : NULL;
        if (_controlTimebase)
            CMTimebaseSetMasterTimebase(_timebase, _controlTimebase);
        else
            CMTimebaseSetMasterClock(_timebase, CMClockGetHostTimeClock());
    }
    [self revenant_armDisplayTimer];
}

#pragma mark - the timer

- (void)revenant_armDisplayTimer
{
    CMTime next = kCMTimeInvalid;
    @synchronized (self) {
        for (RevenantAVDisplayBuffer *buffer in _pending) {
            if (CMTIME_IS_NUMERIC(buffer->presentation)
                && (!CMTIME_IS_VALID(next) || CMTimeCompare(buffer->presentation, next) < 0))
                next = buffer->presentation;
        }
    }
    CMTimebaseSetTimerDispatchSourceNextFireTime(_timebase, _displaySource, next, 0);
}

- (void)revenant_presentDueFrames
{
    NSMutableArray *expired = [[NSMutableArray alloc] init];
    NSMutableArray *due = [[NSMutableArray alloc] init];
    NSUInteger generation = 0;
    @synchronized (self) {
        generation = _generation;
        if (_pending.count == 0 || _status == AVQueuedSampleBufferRenderingStatusFailed) {
            CMTimebaseSetTimerDispatchSourceNextFireTime(_timebase, _displaySource, kCMTimeInvalid, 0);
            return;
        }
        CMTime now = CMTimebaseGetTime(_timebase);
        for (RevenantAVDisplayBuffer *buffer in _pending) {
            if (CMTIME_IS_NUMERIC(buffer->presentation) && CMTimeCompare(buffer->presentation, now) > 0)
                continue;
            [expired addObject:buffer];
            if (buffer->display)
                [due addObject:buffer];
        }
        [_pending removeObjectsInArray:expired];
    }
    RevenantAVDisplayBuffer *latest = nil;
    for (RevenantAVDisplayBuffer *buffer in due) {
        if (!latest || (CMTIME_IS_NUMERIC(buffer->presentation) && CMTimeCompare(buffer->presentation, latest->presentation) > 0))
            latest = buffer;
    }
    if (latest) {
        [self revenant_prepareBuffer:latest generation:generation];
        [self revenant_invokeRequestIfNeeded];
    }
    [self revenant_armDisplayTimer];
}

- (void)revenant_invokeRequestIfNeeded
{
    void (^block)(void) = nil;
    dispatch_queue_t queue = NULL;
    @synchronized (self) {
        if (!_requestBlock || _requestActive || _pending.count >= revenant_pending_limit)
            return;
        if (_status == AVQueuedSampleBufferRenderingStatusFailed)
            return;
        _requestActive = YES;
        block = _requestBlock;
        queue = _requestQueue;
    }
    dispatch_async(queue ?: dispatch_get_main_queue(), ^{
        void (^pending)(void);
        @synchronized (self) {
            pending = _requestBlock;
        }
        if (pending)
            pending();
        @synchronized (self) {
            _requestActive = NO;
        }
    });
}

- (void)revenant_prepareBuffer:(RevenantAVDisplayBuffer *)buffer generation:(NSUInteger)generation
{
    @synchronized (self) {
        if (generation != _generation || _status == AVQueuedSampleBufferRenderingStatusFailed)
            return;
    }
    CGImageRef frame = revenant_copy_image(buffer->sample, _context);
    if (!frame) {
        [self revenant_failWithDescription:@"AVSampleBufferDisplayLayer could not create an image from a sample buffer"];
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        @synchronized (self) {
            if (generation != _generation) {
                CGImageRelease(frame);
                return;
            }
        }
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        self.contents = (__bridge id)frame;
        [CATransaction commit];
        CGImageRelease(frame);
        [self willChangeValueForKey:@"readyForDisplay"];
        @synchronized (self) {
            _readyForDisplay = YES;
        }
        [self didChangeValueForKey:@"readyForDisplay"];
    });
}

- (void)revenant_failWithDescription:(NSString *)description
{
    [self willChangeValueForKey:@"status"];
    @synchronized (self) {
        _status = AVQueuedSampleBufferRenderingStatusFailed;
        _error = [NSError errorWithDomain:AVFoundationErrorDomain code:AVErrorUnknown
                                 userInfo:@{NSLocalizedDescriptionKey: description}];
    }
    [self didChangeValueForKey:@"status"];
}

#pragma mark - the layer

- (id)videoGravity
{
    return _videoGravity;
}

- (void)setVideoGravity:(id)videoGravity
{
    _videoGravity = [videoGravity copy];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.contentsGravity = revenant_contents_gravity(_videoGravity);
    [CATransaction commit];
}

- (BOOL)isReadyForDisplay
{
    return _readyForDisplay;
}

- (BOOL)preventsCapture
{
    return _preventsCapture;
}

- (void)setPreventsCapture:(BOOL)preventsCapture
{
    _preventsCapture = preventsCapture;
}

- (BOOL)preventsDisplaySleepDuringVideoPlayback
{
    return _preventsDisplaySleep;
}

- (void)setPreventsDisplaySleepDuringVideoPlayback:(BOOL)preventsDisplaySleep
{
    _preventsDisplaySleep = preventsDisplaySleep;
}

- (BOOL)outputObscuredDueToInsufficientExternalProtection
{
    return NO;
}

- (id)sampleBufferRenderer
{
    return nil;
}

#pragma mark - the media data

- (AVQueuedSampleBufferRenderingStatus)status
{
    return _status;
}

- (NSError *)error
{
    return _error;
}

- (BOOL)requiresFlushToResumeDecoding
{
    return _status == AVQueuedSampleBufferRenderingStatusFailed;
}

- (BOOL)isReadyForMoreMediaData
{
    @synchronized (self) {
        return _pending.count < revenant_pending_limit && _status != AVQueuedSampleBufferRenderingStatusFailed;
    }
}

- (BOOL)hasSufficientMediaDataForReliablePlaybackStart
{
    return _readyForDisplay;
}

- (void)enqueueSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    if (!sampleBuffer)
        [NSException raise:NSInvalidArgumentException
                    format:@"-[AVSampleBufferDisplayLayer enqueueSampleBuffer:] was given no sample buffer"];
    BOOL immediate = revenant_attachment(sampleBuffer, kCMSampleAttachmentKey_DisplayImmediately);
    BOOL display = !revenant_attachment(sampleBuffer, kCMSampleAttachmentKey_DoNotDisplay);
    RevenantAVDisplayBuffer *buffer = [[RevenantAVDisplayBuffer alloc] init];
    buffer->sample = (CMSampleBufferRef)CFRetain(sampleBuffer);
    buffer->presentation = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer);
    buffer->display = display;
    NSUInteger generation = 0;
    [self willChangeValueForKey:@"status"];
    @synchronized (self) {
        if (_status == AVQueuedSampleBufferRenderingStatusFailed) {
            [self didChangeValueForKey:@"status"];
            return;
        }
        if (_status == AVQueuedSampleBufferRenderingStatusUnknown)
            _status = AVQueuedSampleBufferRenderingStatusRendering;
        generation = _generation;
        if (!immediate)
            [_pending addObject:buffer];
    }
    [self didChangeValueForKey:@"status"];
    if (immediate) {
        if (display)
            dispatch_async(_workQueue, ^{
                [self revenant_prepareBuffer:buffer generation:generation];
            });
    } else {
        [self revenant_armDisplayTimer];
    }
}

- (void)flush
{
    [self willChangeValueForKey:@"status"];
    [self willChangeValueForKey:@"readyForDisplay"];
    @synchronized (self) {
        [_pending removeAllObjects];
        _error = nil;
        _readyForDisplay = NO;
        _status = AVQueuedSampleBufferRenderingStatusUnknown;
        _generation++;
    }
    [self didChangeValueForKey:@"readyForDisplay"];
    [self didChangeValueForKey:@"status"];
    CMTimebaseSetTimerDispatchSourceNextFireTime(_timebase, _displaySource, kCMTimeInvalid, 0);
    [self revenant_invokeRequestIfNeeded];
}

- (void)flushAndRemoveImage
{
    [self flush];
    dispatch_async(dispatch_get_main_queue(), ^{
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        self.contents = nil;
        [CATransaction commit];
    });
}

- (void)requestMediaDataWhenReadyOnQueue:(dispatch_queue_t)queue usingBlock:(void (^)(void))block
{
    if (!block)
        [NSException raise:NSInvalidArgumentException
                    format:@"-[AVSampleBufferDisplayLayer requestMediaDataWhenReadyOnQueue:usingBlock:] was given no block"];
    @synchronized (self) {
        _requestQueue = queue;
        _requestBlock = [block copy];
    }
    [self revenant_invokeRequestIfNeeded];
}

- (void)stopRequestingMediaData
{
    @synchronized (self) {
        _requestBlock = nil;
        _requestQueue = NULL;
    }
}

@end
