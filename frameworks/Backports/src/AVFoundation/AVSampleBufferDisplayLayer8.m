#import "RevenantAVSampleBufferRender.h"

#import <AVFoundation/AVFoundation.h>
#import <CoreImage/CoreImage.h>
#import <CoreMedia/CoreMedia.h>
#import <QuartzCore/QuartzCore.h>

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
    dispatch_queue_t _requestQueue;
    void (^_requestBlock)(void);
}
- (instancetype)initRevenantLayer;
@end

static NSString *revenant_contents_gravity(id gravity)
{
    if ([gravity isEqualToString:AVLayerVideoGravityResizeAspectFill])
        return kCAGravityResizeAspectFill;
    if ([gravity isEqualToString:AVLayerVideoGravityResize])
        return kCAGravityResize;
    return kCAGravityResizeAspect;
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
    return self;
}

- (void)dealloc
{
    if (_timebase)
        CFRelease(_timebase);
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
    if (controlTimebase == _controlTimebase)
        return;
    if (_controlTimebase)
        CFRelease(_controlTimebase);
    _controlTimebase = controlTimebase ? CFRetain(controlTimebase) : NULL;
    if (_controlTimebase)
        CMTimebaseSetMasterTimebase(_timebase, _controlTimebase);
    else
        CMTimebaseSetMasterClock(_timebase, CMClockGetHostTimeClock());
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
    if (_status == AVQueuedSampleBufferRenderingStatusFailed)
        return;
    CVPixelBufferRef image = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (image) {
        CIImage *ci = [CIImage imageWithCVPixelBuffer:image];
        CGImageRef frame = ci ? [_context createCGImage:ci fromRect:ci.extent] : NULL;
        if (frame) {
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            self.contents = (__bridge id)frame;
            [CATransaction commit];
            CGImageRelease(frame);
            _readyForDisplay = YES;
        }
    }
    if (_status == AVQueuedSampleBufferRenderingStatusUnknown)
        _status = AVQueuedSampleBufferRenderingStatusRendering;
    void (^block)(void) = _requestBlock;
    if (block) {
        _requestBlock = nil;
        dispatch_async(_requestQueue ?: dispatch_get_main_queue(), block);
    }
}

- (void)flush
{
    _readyForDisplay = NO;
    _error = nil;
    _status = AVQueuedSampleBufferRenderingStatusUnknown;
}

- (void)flushAndRemoveImage
{
    [self flush];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.contents = nil;
    [CATransaction commit];
}

- (void)requestMediaDataWhenReadyOnQueue:(dispatch_queue_t)queue usingBlock:(void (^)(void))block
{
    if (!block)
        [NSException raise:NSInvalidArgumentException
                    format:@"-[AVSampleBufferDisplayLayer requestMediaDataWhenReadyOnQueue:usingBlock:] was given no block"];
    _requestQueue = queue;
    _requestBlock = [block copy];
    dispatch_async(queue ?: dispatch_get_main_queue(), ^{
        void (^pending)(void) = self->_requestBlock;
        if (pending) {
            self->_requestBlock = nil;
            pending();
        }
    });
}

- (void)stopRequestingMediaData
{
    _requestBlock = nil;
    _requestQueue = NULL;
}

@end
