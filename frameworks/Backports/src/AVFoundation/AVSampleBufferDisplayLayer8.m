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
    dispatch_queue_t _requestQueue;
    void (^_requestBlock)(void);
}
- (instancetype)initRevenantLayer;
- (void)revenant_presentDueFrames;
- (void)revenant_armDisplayTimer;
- (void)revenant_showBuffer:(RevenantAVDisplayBuffer *)buffer;
@end

static NSString *revenant_contents_gravity(id gravity)
{
    if ([gravity isEqualToString:AVLayerVideoGravityResizeAspectFill])
        return kCAGravityResizeAspectFill;
    if ([gravity isEqualToString:AVLayerVideoGravityResize])
        return kCAGravityResize;
    return kCAGravityResizeAspect;
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
        info = (CGBitmapInfo)(kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
        direct = YES;
    } else if (format == kCVPixelFormatType_32ARGB) {
        info = (CGBitmapInfo)(kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedFirst);
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

- (instancetype)initRevenantLayer
{
    if (!(self = [super init]))
        return nil;
    if (CMTimebaseCreateWithMasterClock(kCFAllocatorDefault, CMClockGetHostTimeClock(), &_timebase) != noErr)
        return nil;
    _videoGravity = [AVLayerVideoGravityResizeAspect copy];
    _status = AVQueuedSampleBufferRenderingStatusUnknown;
    _context = [CIContext contextWithOptions:nil];
    _pending = [[NSMutableArray alloc] init];
    _workQueue = dispatch_queue_create("revenant.samplebuffer.display", DISPATCH_QUEUE_SERIAL);
    _displaySource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _workQueue);
    dispatch_resume(_displaySource);
    dispatch_source_set_event_handler(_displaySource, ^{
        [self revenant_presentDueFrames];
    });
    CMTimebaseAddTimerDispatchSource(_timebase, _displaySource);
    return self;
}

- (instancetype)init
{
    return [self initRevenantLayer];
}

- (instancetype)initWithLayer:(id)layer
{
    if (!(self = [super initWithLayer:layer]))
        return nil;
    if (CMTimebaseCreateWithMasterClock(kCFAllocatorDefault, CMClockGetHostTimeClock(), &_timebase) != noErr)
        return nil;
    _videoGravity = [AVLayerVideoGravityResizeAspect copy];
    _status = AVQueuedSampleBufferRenderingStatusUnknown;
    _context = [CIContext contextWithOptions:nil];
    _pending = [[NSMutableArray alloc] init];
    _workQueue = dispatch_queue_create("revenant.samplebuffer.display", DISPATCH_QUEUE_SERIAL);
    _displaySource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _workQueue);
    dispatch_resume(_displaySource);
    dispatch_source_set_event_handler(_displaySource, ^{
        [self revenant_presentDueFrames];
    });
    CMTimebaseAddTimerDispatchSource(_timebase, _displaySource);
    return self;
}

- (void)dealloc
{
    if (_timebase) {
        if (_displaySource) {
            CMTimebaseSetTimerDispatchSourceNextFireTime(_timebase, _displaySource, kCMTimeInvalid, 0);
            CMTimebaseRemoveTimerDispatchSource(_timebase, _displaySource);
            dispatch_source_cancel(_displaySource);
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
    NSMutableArray *due = [[NSMutableArray alloc] init];
    @synchronized (self) {
        if (_pending.count == 0 || _status == AVQueuedSampleBufferRenderingStatusFailed) {
            CMTimebaseSetTimerDispatchSourceNextFireTime(_timebase, _displaySource, kCMTimeInvalid, 0);
            return;
        }
        CMTime now = CMTimebaseGetTime(_timebase);
        for (RevenantAVDisplayBuffer *buffer in _pending) {
            if (CMTIME_IS_NUMERIC(buffer->presentation) && CMTimeCompare(buffer->presentation, now) > 0)
                continue;
            [due addObject:buffer];
        }
        [_pending removeObjectsInArray:due];
    }
    if (due.count) {
        RevenantAVDisplayBuffer *latest = [due lastObject];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self revenant_showBuffer:latest];
        });
    }
    [self revenant_armDisplayTimer];
}

- (void)revenant_showBuffer:(RevenantAVDisplayBuffer *)buffer
{
    CGImageRef frame = revenant_copy_image(buffer->sample, _context);
    if (!frame)
        return;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.contents = (__bridge id)frame;
    [CATransaction commit];
    CGImageRelease(frame);
    @synchronized (self) {
        _readyForDisplay = YES;
    }
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
    return YES;
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
    BOOL immediate = NO;
    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, false);
    if (attachments && CFArrayGetCount(attachments) > 0) {
        CFDictionaryRef values = CFArrayGetValueAtIndex(attachments, 0);
        immediate = CFDictionaryGetValue(values, kCMSampleAttachmentKey_DisplayImmediately) == kCFBooleanTrue;
    }
    RevenantAVDisplayBuffer *buffer = [[RevenantAVDisplayBuffer alloc] init];
    buffer->sample = (CMSampleBufferRef)CFRetain(sampleBuffer);
    buffer->presentation = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer);
    void (^request)(void) = nil;
    @synchronized (self) {
        if (_status == AVQueuedSampleBufferRenderingStatusFailed)
            return;
        if (_status == AVQueuedSampleBufferRenderingStatusUnknown)
            _status = AVQueuedSampleBufferRenderingStatusRendering;
        request = _requestBlock;
        _requestBlock = nil;
        if (!immediate)
            [_pending addObject:buffer];
    }
    if (immediate)
        dispatch_async(dispatch_get_main_queue(), ^{
            [self revenant_showBuffer:buffer];
        });
    else
        [self revenant_armDisplayTimer];
    if (request)
        dispatch_async(_requestQueue ?: dispatch_get_main_queue(), request);
}

- (void)flush
{
    @synchronized (self) {
        [_pending removeAllObjects];
        _error = nil;
        _readyForDisplay = NO;
        _status = AVQueuedSampleBufferRenderingStatusUnknown;
    }
    CMTimebaseSetTimerDispatchSourceNextFireTime(_timebase, _displaySource, kCMTimeInvalid, 0);
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
    dispatch_async(queue ?: dispatch_get_main_queue(), ^{
        void (^pending)(void);
        @synchronized (self) {
            pending = _requestBlock;
            _requestBlock = nil;
        }
        if (pending)
            pending();
    });
}

- (void)stopRequestingMediaData
{
    @synchronized (self) {
        _requestBlock = nil;
        _requestQueue = NULL;
    }
}

@end
