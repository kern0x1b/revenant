#import "CharonAVSampleBufferRender.h"

#import <AudioToolbox/AudioToolbox.h>
#import <CoreMedia/CoreMedia.h>

@interface CharonAVPendingBuffer : NSObject
{
@public
    CMSampleBufferRef sampleBuffer;
    CMTime presentation;
}
@end

@implementation CharonAVPendingBuffer
@end

static void charon_queueReturnedBuffer(void *userData, AudioQueueRef queue, AudioQueueBufferRef buffer);

@interface AVSampleBufferAudioRenderer ()
{
@private
    CMTimebaseRef _timebase;
    AudioQueueRef _queue;
    AudioStreamBasicDescription _format;
    NSMutableArray *_pending;
    AudioQueueBufferRef *_spares;
    NSUInteger _spareCount;
    NSUInteger _spareCapacity;
    AVQueuedSampleBufferRenderingStatus _status;
    NSError *_error;
    AVAudioTimePitchAlgorithm _audioTimePitchAlgorithm;
    float _volume;
    BOOL _muted;
    BOOL _running;
    float _lastRate;
    float _lastNonZeroRate;
    dispatch_queue_t _workQueue;
    dispatch_queue_t _requestQueue;
    void (^_requestBlock)(void);
}
@end

@implementation AVSampleBufferAudioRenderer

@dynamic allowedAudioSpatializationFormats;
@dynamic audioOutputDeviceUniqueID;

- (instancetype)init
{
    if (!(self = [super init]))
        return nil;
    if (CMTimebaseCreateWithMasterClock(kCFAllocatorDefault, CMClockGetHostTimeClock(), &_timebase) != noErr)
        return nil;
    _pending = [[NSMutableArray alloc] init];
    _workQueue = dispatch_queue_create("charon.samplebuffer.render", DISPATCH_QUEUE_SERIAL);
    _status = AVQueuedSampleBufferRenderingStatusUnknown;
    _volume = 1.0f;
    _audioTimePitchAlgorithm = AVAudioTimePitchAlgorithmTimeDomain;
    return self;
}

- (void)dealloc
{
    [self charon_releaseQueue];
    free(_spares);
}

- (CMTimebaseRef)timebase
{
    return _timebase;
}

#pragma mark - the media data

- (BOOL)isReadyForMoreMediaData
{
    @synchronized (self) {
        return _pending.count == 0;
    }
}

- (void)enqueueSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    if (!sampleBuffer)
        [NSException raise:NSInvalidArgumentException
                    format:@"-[AVSampleBufferAudioRenderer enqueueSampleBuffer:] was given no sample buffer"];
    CMTime presentation = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer);
    if (CMTIME_IS_NUMERIC(presentation)) {
        CharonAVPendingBuffer *pending = [[CharonAVPendingBuffer alloc] init];
        pending->sampleBuffer = (CMSampleBufferRef)CFRetain(sampleBuffer);
        pending->presentation = presentation;
        @synchronized (self) {
            [_pending addObject:pending];
            if (_status == AVQueuedSampleBufferRenderingStatusUnknown)
                _status = AVQueuedSampleBufferRenderingStatusRendering;
        }
    }
    @synchronized (self) {
        [self charon_drainPending];
    }
    [self charon_reportReadiness];
}

- (void)flush
{
    @synchronized (self) {
        if (_queue)
            [self charon_resetQueue];
        [_pending removeAllObjects];
        _running = NO;
    }
    [self charon_reportReadiness];
}

- (void)flushFromSourceTime:(CMTime)time completionHandler:(void (^)(BOOL flushSucceeded))completionHandler
{
    @synchronized (self) {
        if (_queue) {
            NSUInteger dropped = 0;
            for (CharonAVPendingBuffer *pending in [_pending copy]) {
                if (!CMTIME_IS_NUMERIC(time) || CMTimeCompare(pending->presentation, time) >= 0) {
                    [_pending removeObject:pending];
                    dropped++;
                }
            }
            if (dropped) {
                [self charon_resetQueue];
                _running = NO;
            }
            [self charon_drainPending];
        } else {
            [_pending removeAllObjects];
        }
    }
    [self charon_reportReadiness];
    if (completionHandler)
        completionHandler(YES);
}

#pragma mark - the media data request

- (void)requestMediaDataWhenReadyOnQueue:(dispatch_queue_t)queue usingBlock:(void (^)(void))block
{
    @synchronized (self) {
        _requestQueue = queue ? queue : dispatch_get_main_queue();
        _requestBlock = block;
    }
    [self charon_reportReadiness];
}

- (void)stopRequestingMediaData
{
    @synchronized (self) {
        _requestBlock = nil;
        _requestQueue = NULL;
    }
}

- (void)charon_reportReadiness
{
    dispatch_queue_t queue = NULL;
    void (^block)(void) = nil;
    @synchronized (self) {
        if (!_requestBlock || _pending.count != 0)
            return;
        queue = _requestQueue;
        block = _requestBlock;
    }
    dispatch_async(queue, ^{
        block();
    });
}

#pragma mark - the output

- (AVQueuedSampleBufferRenderingStatus)status
{
    return _status;
}

- (NSError *)error
{
    return _error;
}

- (AVAudioTimePitchAlgorithm)audioTimePitchAlgorithm
{
    return _audioTimePitchAlgorithm;
}

- (void)setAudioTimePitchAlgorithm:(AVAudioTimePitchAlgorithm)audioTimePitchAlgorithm
{
    if (audioTimePitchAlgorithm == _audioTimePitchAlgorithm)
        return;
    _audioTimePitchAlgorithm = audioTimePitchAlgorithm;
}

- (float)volume
{
    return _volume;
}

- (void)setVolume:(float)volume
{
    _volume = volume;
    [self charon_applyVolume];
}

- (BOOL)isMuted
{
    return _muted;
}

- (void)setMuted:(BOOL)muted
{
    _muted = muted;
    [self charon_applyVolume];
}

- (void)charon_applyVolume
{
    AudioQueueRef queue = NULL;
    @synchronized (self) {
        queue = _queue;
    }
    if (!queue)
        return;
    AudioQueueParameterValue volume = _muted ? 0.0f : _volume;
    AudioQueueSetParameter(queue, kAudioQueueParam_Volume, volume);
}

- (void)charon_renderSynchronizerDidChangeRate
{
    float now = (float)CMTimebaseGetRate(_timebase);
    float was = _lastRate;
    _lastRate = now;
    if (now == was)
        return;
    if (was != 0.0f && now == 0.0f) {
        _lastNonZeroRate = was;
        return;
    }
    if (was == 0.0f && now != 0.0f && now == _lastNonZeroRate)
        return;
    CMTime flushedAt = kCMTimeInvalid;
    @synchronized (self) {
        if (!_pending.count)
            return;
        flushedAt = ((CharonAVPendingBuffer *)[_pending firstObject])->presentation;
        if (_queue)
            [self charon_resetQueue];
        [_pending removeAllObjects];
        _running = NO;
    }
    [[NSNotificationCenter defaultCenter]
        postNotificationName:AVSampleBufferAudioRendererWasFlushedAutomaticallyNotification
                      object:self
                    userInfo:@{ AVSampleBufferAudioRendererFlushTimeKey: [NSValue valueWithCMTime:flushedAt] }];
    [self charon_reportReadiness];
}

#pragma mark - the queue

- (void)charon_drainPending
{
    if (!_pending.count)
        return;
    double rate = CMTimebaseGetRate(_timebase);
    if (rate <= 0.0)
        return;
    if (!_queue && ![self charon_openQueueFor:(CharonAVPendingBuffer *)[_pending firstObject]])
        return;
    while (_pending.count) {
        CharonAVPendingBuffer *pending = [_pending objectAtIndex:0];
        AudioQueueBufferRef buffer = [self charon_bufferForBytes:(UInt32)[self charon_bytesOf:pending]];
        if (!buffer)
            break;
        if (![self charon_fill:buffer from:pending] || ![self charon_enqueue:buffer at:pending->presentation]) {
            break;
        }
        [_pending removeObjectAtIndex:0];
    }
}

- (BOOL)charon_openQueueFor:(CharonAVPendingBuffer *)pending
{
    CMAudioFormatDescriptionRef format = CMSampleBufferGetFormatDescription(pending->sampleBuffer);
    if (!format) {
        [self charon_failWithReason:@"the sample buffer carries no format description"];
        return NO;
    }
    const AudioStreamBasicDescription *asbd = CMAudioFormatDescriptionGetStreamBasicDescription(format);
    if (!asbd) {
        [self charon_failWithReason:@"the sample buffer's format description carries no stream format"];
        return NO;
    }
    if (asbd->mFormatID != kAudioFormatLinearPCM) {
        [self charon_failWithReason:[NSString stringWithFormat:@"the sample buffer is in format %u, which is not linear PCM",
                                     (unsigned)asbd->mFormatID]];
        return NO;
    }
    _format = *asbd;
    OSStatus status = AudioQueueNewOutput(&_format, charon_queueReturnedBuffer, (__bridge void *)self,
                                          NULL, NULL, 0, &_queue);
    if (status != noErr || !_queue) {
        _queue = NULL;
        [self charon_failWithReason:[NSString stringWithFormat:@"AudioQueueNewOutput answered %d", (int)status]];
        return NO;
    }
    [self charon_applyVolume];
    return YES;
}

- (UInt32)charon_bytesOf:(CharonAVPendingBuffer *)pending
{
    const AudioStreamBasicDescription *asbd =
        CMAudioFormatDescriptionGetStreamBasicDescription(CMSampleBufferGetFormatDescription(pending->sampleBuffer));
    UInt32 bytesPerFrame = asbd ? asbd->mBytesPerFrame : 0;
    if (!bytesPerFrame)
        return 1;
    UInt64 bytes = (UInt64)CMSampleBufferGetNumSamples(pending->sampleBuffer) * bytesPerFrame;
    if (bytes > UINT32_MAX)
        bytes = UINT32_MAX;
    return (UInt32)(bytes ? bytes : 1);
}

- (AudioQueueBufferRef)charon_bufferForBytes:(UInt32)bytes
{
    for (NSUInteger index = _spareCount; index > 0; index--) {
        AudioQueueBufferRef spare = _spares[index - 1];
        if (spare->mAudioDataBytesCapacity < bytes)
            continue;
        _spares[--_spareCount] = _spares[index - 1];
        _spares[index - 1] = NULL;
        return spare;
    }
    AudioQueueBufferRef buffer = NULL;
    if (AudioQueueAllocateBuffer(_queue, bytes, &buffer) != noErr || !buffer)
        return NULL;
    return buffer;
}

- (void)charon_keepSpare:(AudioQueueBufferRef)buffer
{
    if (_spareCount == _spareCapacity) {
        NSUInteger capacity = _spareCapacity ? _spareCapacity * 2 : 4;
        AudioQueueBufferRef *grown = realloc(_spares, capacity * sizeof *grown);
        if (!grown)
            return;
        _spares = grown;
        _spareCapacity = capacity;
    }
    _spares[_spareCount++] = buffer;
}

- (BOOL)charon_fill:(AudioQueueBufferRef)buffer from:(CharonAVPendingBuffer *)pending
{
    const AudioStreamBasicDescription *asbd =
        CMAudioFormatDescriptionGetStreamBasicDescription(CMSampleBufferGetFormatDescription(pending->sampleBuffer));
    if (!asbd || !asbd->mBytesPerFrame || !asbd->mChannelsPerFrame)
        return NO;
    size_t needed = 0;
    OSStatus status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(pending->sampleBuffer,
                                                                                 &needed, NULL, 0,
                                                                                 NULL, NULL, 0, NULL);
    if (status || !needed)
        return NO;
    AudioBufferList *source = calloc(1, needed);
    if (!source) {
        [self charon_failWithReason:@"the audio buffer list for the sample buffer could not be allocated"];
        return NO;
    }
    CMBlockBufferRef block = NULL;
    status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(pending->sampleBuffer,
                                                                     NULL, source, needed,
                                                                     NULL, NULL, 0, &block);
    if (status == noErr && source->mNumberBuffers == asbd->mChannelsPerFrame) {
        UInt32 written = 0;
        for (UInt32 channel = 0; channel < source->mNumberBuffers; channel++) {
            const AudioBuffer *from = &source->mBuffers[channel];
            UInt32 at = channel * asbd->mBytesPerFrame;
            UInt32 room = at < buffer->mAudioDataBytesCapacity
                        ? buffer->mAudioDataBytesCapacity - at : 0;
            UInt32 bytes = from->mDataByteSize < room ? from->mDataByteSize : room;
            if (from->mData && bytes)
                memcpy(buffer->mAudioData + at, from->mData, bytes);
            written += bytes;
        }
        buffer->mAudioDataByteSize = written;
    } else if (status == noErr) {
        [self charon_failWithReason:[NSString stringWithFormat:@"the sample buffer holds %u audio buffers for %u channels",
                                     (unsigned)source->mNumberBuffers, (unsigned)asbd->mChannelsPerFrame]];
        status = kCMSampleBufferError_InvalidSampleData;
    }
    if (block)
        CFRelease(block);
    free(source);
    if (status != noErr) {
        if (_error == nil)
            [self charon_failWithReason:[NSString stringWithFormat:@"CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer answered %d", (int)status]];
        return NO;
    }
    return YES;
}

- (BOOL)charon_enqueue:(AudioQueueBufferRef)buffer at:(CMTime)presentation
{
    if (!_running) {
        OSStatus started = AudioQueueStart(_queue, NULL);
        if (started != noErr) {
            [self charon_failWithReason:[NSString stringWithFormat:@"AudioQueueStart answered %d", (int)started]];
            AudioQueueFreeBuffer(_queue, buffer);
            return NO;
        }
        _running = YES;
    }
    AudioTimeStamp anchor = {0};
    if (AudioQueueGetCurrentTime(_queue, NULL, &anchor, NULL) != noErr
        || !(anchor.mFlags & kAudioTimeStampSampleTimeValid)) {
        [self charon_failWithReason:@"the audio queue did not answer its own current time"];
        AudioQueueFreeBuffer(_queue, buffer);
        return NO;
    }
    CMTime now = CMTimebaseGetTime(_timebase);
    double rate = CMTimebaseGetRate(_timebase);
    double frames = CMTimeGetSeconds(CMTimeSubtract(presentation, now)) * _format.mSampleRate / rate;
    AudioTimeStamp start = {0};
    start.mFlags = kAudioTimeStampSampleTimeValid;
    start.mSampleTime = anchor.mSampleTime + (SInt64)llround(frames);
    AudioTimeStamp actual = {0};
    OSStatus status = AudioQueueEnqueueBufferWithParameters(_queue, buffer, 0, NULL, 0, 0, 0, NULL,
                                                            &start, &actual);
    if (status != noErr) {
        [self charon_failWithReason:[NSString stringWithFormat:@"AudioQueueEnqueueBufferWithParameters answered %d", (int)status]];
        AudioQueueFreeBuffer(_queue, buffer);
        return NO;
    }
    return YES;
}

static void charon_queueReturnedBuffer(void *userData, AudioQueueRef queue, AudioQueueBufferRef buffer)
{
    AVSampleBufferAudioRenderer *renderer = (__bridge AVSampleBufferAudioRenderer *)userData;
    (void)queue;
    dispatch_async(renderer->_workQueue, ^{
        @synchronized (renderer) {
            if (renderer->_queue)
                [renderer charon_keepSpare:buffer];
            [renderer charon_drainPending];
        }
        [renderer charon_reportReadiness];
    });
}

- (void)charon_resetQueue
{
    OSStatus status = AudioQueueReset(_queue);
    if (status != noErr)
        [self charon_failWithReason:[NSString stringWithFormat:@"AudioQueueReset answered %d", (int)status]];
}

- (void)charon_releaseQueue
{
    if (_queue) {
        AudioQueueDispose(_queue, true);
        _queue = NULL;
    }
    _running = NO;
    _spareCount = 0;
}

- (void)charon_failWithReason:(NSString *)reason
{
    _status = AVQueuedSampleBufferRenderingStatusFailed;
    if (!_error)
        _error = [[NSError alloc] initWithDomain:AVFoundationErrorDomain
                                            code:AVErrorUnknown
                                        userInfo:@{ NSLocalizedDescriptionKey: reason }];
}

@end
