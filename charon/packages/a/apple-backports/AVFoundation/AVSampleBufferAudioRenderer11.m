// AVSampleBufferAudioRenderer11.m - AVSampleBufferAudioRenderer as of 11.0, on an AudioQueue.
//
// Neither the class nor the AVQueuedSampleBufferRendering protocol it conforms to is on 6.1.3, and the
// port brings both (the protocol's own metadata comes from the source modules/apple/backports.lua writes
// for an implemented protocol row, so nothing here declares it). What this class plays with is the
// release's own AudioQueue: AudioToolbox on 6.1.3 armv7 exports 337 symbols of which 43 match
// "AudioQueue", and the media path below uses _AudioQueueNewOutput, _AudioQueueAllocateBuffer,
// _AudioQueueEnqueueBufferWithParameters, _AudioQueueFlush, _AudioQueueStart, _AudioQueueDispose,
// _AudioQueueGetCurrentTime, _AudioQueueFreeBuffer and _AudioQueueSetParameter - all of them in that
// list, read from the image's own export trie.
//
// THE TIMESTAMP IS THE WHOLE POINT, and this is the correction to the previous reading of this row:
// AudioQueueEnqueueBufferWithParameters takes an inStartTime whose mSampleTime is a queue-relative sample
// (AudioQueue.h:1189, and its note at :1181, which says the sample time is measured from the instant the queue
// started), so a buffer CAN be scheduled for the time its presentation timestamp names. The mapping is
// read off the queue itself at the instant of the enqueue: -AudioQueueGetCurrentTime answers the queue's
// sample time and the host time of that instant together, and the synchronizer's clock answers its own
// time, so the frames between two CMTimes follow from the format's sample rate and the clock's rate.
// Measured on this Mac, that is all the substrate there is to measure: CoreAudio reports the hardware not
// running ('who?' for kAudioHardwarePropertyDevices) and AudioQueueNewOutput fails, so no audio reaches an
// output here and nothing about what this plays can be listened to on this machine. What was measured
// instead is in tests/backports/host/avf-samplerender11 and in facts/AVFoundation/SampleBufferRender11.md.
//
// WHERE THE FORMAT COMES FROM. The 11.0 initialiser -initWithAudioFormatDescription:bufferCapacity: is in
// neither the 16.4 SDK this package compiles against nor this Mac's SDK, and the only selector matching
// "initWithAudioFormatDescription" in the 11.0 arm64 cache is the private _initWithAudioFormatDescription:,
// so a client on this port constructs a renderer with -init as a client does on this Mac, and the format
// arrives with the first media: CMAudioFormatDescriptionGetStreamBasicDescription on the format
// description a client hands -enqueueSampleBuffer: is what the queue is built from. Measured on the host
// for -init: status Unknown, error nil, isReadyForMoreMediaData YES, a timebase of its own, volume 1.0,
// not muted, audioTimePitchAlgorithm TimeDomain.
//
// A RATE OTHER THAN 1.0 IS HONOURED BY THE MAPPING, and that is all it is: the queue plays at the rate
// the format names, and a rate on the clock is the spacing of the start times, so the media is heard
// faster or slower with its pitch following. The port carries no time-pitch unit to hold the pitch
// (measured: 6.1.3's AVFAudio has none, and -audioTimePitchAlgorithm has no effect here for that reason),
// and the header's own wording for the rate is "play at the natural rate of the media", which is what the
// mapping is.
//
// ONE RELEASE PER OBJECT. Every symbol this file defines first appears in the 11.0 image: the class symbol
// (tools/cache-index/first-rung.lua _OBJC_CLASS_$_AVSampleBufferAudioRenderer answers 11.0) and nothing
// else. Every member the 16.4 header declares for this class at another release - -currentTime,
// -setRate:time:atHostTime:, -hasSufficientMediaDataForReliablePlaybackStart,
// -delaysRateChangeUntilHasSufficientMediaData, -allowedAudioSpatializationFormats - is 12.0 or later and
// is not here; what the port answers for each of them is in the facts page.
#import "CharonAVSampleBufferRender.h"

#import <AudioToolbox/AudioToolbox.h>
#import <CoreMedia/CoreMedia.h>

// A buffer a client has handed over and the queue has not taken yet. The queue is what bounds a renderer,
// so a renderer whose queue could not be made holds its media here, which is also why
// -isReadyForMoreMediaData reads NO as soon as there is any: the header describes the property as
// reporting whether the renderer can take another sample buffer (the header), and a renderer holding media it cannot hand on
// is not ready for more. Measured on the host on a machine with no output device: isReadyForMoreMediaData
// is YES at init and NO from the first enqueue on, and stays NO.
@interface CharonAVPendingBuffer : NSObject
{
@public
    CMSampleBufferRef sampleBuffer;     // retained
    CMTime presentation;
}
@end

@implementation CharonAVPendingBuffer
@end

static void charon_queueReturnedBuffer(void *userData, AudioQueueRef queue, AudioQueueBufferRef buffer);

@interface AVSampleBufferAudioRenderer ()
{
@private
    CMTimebaseRef _timebase;             // the renderer's own clock until a synchronizer drives it
    AudioQueueRef _queue;                // nil until the first media names a format
    AudioStreamBasicDescription _format;
    NSMutableArray *_pending;            // the CharonAVPendingBuffer entries not yet handed to the queue
    AudioQueueBufferRef *_spares;        // the queue's buffers it has played and handed back
    NSUInteger _spareCount;
    NSUInteger _spareCapacity;
    AVQueuedSampleBufferRenderingStatus _status;
    NSError *_error;
    AVAudioTimePitchAlgorithm _audioTimePitchAlgorithm;
    float _volume;
    BOOL _muted;
    BOOL _running;                       // whether the queue has been started
    float _lastRate;                     // the rate the last change came from
    float _lastNonZeroRate;              // the rate in force before the last pause, which a resume matches
    dispatch_queue_t _workQueue;         // the queue's callback is a realtime one, so its work is not
    dispatch_queue_t _requestQueue;      // where -requestMediaDataWhenReadyOnQueue: asked to be called
    void (^_requestBlock)(void);
}
@end

@implementation AVSampleBufferAudioRenderer

// NOT BUILT IN THIS OBJECT, AND SAID SO RATHER THAN CLAIMED.
//
// clang synthesises an ivar and a pair of accessors for every property the SDK's @interface declares and
// this @implementation does not mention, whatever the property's API_AVAILABLE says and whatever release
// is being built. Measured on this object's own code at the package's flags: `nm -a` over
// AVSampleBufferAudioRenderer11.o carries -allowedAudioSpatializationFormats, -setAllowedAudioSpatializationFormats:,
// -audioOutputDeviceUniqueID, -setAudioOutputDeviceUniqueID: and the two ivars behind them, identically at
// -target armv7-apple-ios6.0 and at -target armv7-apple-ios4.3. Both are members the registry rows answer
// absent - one is 15.0, the other is API_UNAVAILABLE(ios) in the SDK's own header - and a synthesised
// accessor is a name the port claims and does not carry, which is what check_registry reads as
// "listed as absent, but what is built answers it".
//
// Why nothing caught it here, measured rather than assumed: -fsyntax-only emits no code and so cannot show
// auto-synthesis at all, which is the only thing that went wrong in this series' own verification; the
// package's -Werror=objc-missing-property-synthesis is the warning for the OPPOSITE condition (a property
// that is not synthesised, which happens under -fno-objc-default-synthesize-properties) and never fires for
// one that was synthesised silently; and -Wincomplete-implementation did fire for the two METHODS another
// release's object carries (-currentTime at 12.0, -setRate:time:atHostTime: at 14.5) but cannot fire for a
// property, because auto-synthesis satisfies the declaration. The protocol's own
// hasSufficientMediaDataForReliablePlaybackStart needs no @dynamic: a property a protocol declares is not
// synthesised (measured: no accessor of that name in any of the four objects, and
// -Wobjc-protocol-property-synthesis says so at compile time).
//
// @dynamic leaves respondsToSelector: answering NO, which is the truth, and tests/backports/host/
// avf-samplerender11 asks each of these two of the built class.
@dynamic allowedAudioSpatializationFormats;
@dynamic audioOutputDeviceUniqueID;

// ---------------------------------------------------------------------------------------------
// the clock

- (instancetype)init
{
    if (!(self = [super init]))
        return nil;
    // A renderer has a timebase before it is added to anything, which is what the host answers for -init
    // (measured: a non-nil -timebase on a renderer that was never added anywhere), and it is the same
    // two-step create the synchronizer uses because it is the only one 6.1.3 exports.
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
        // Measured on the host: -enqueueSampleBuffer: raises for a NULL buffer, and every answer this class
        // gives afterwards on a renderer the host considers unusable is not an answer to read.
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
                // The header says a renderer begins with status AVQueuedSampleBufferRenderingStatusUnknown, and that
                // enqueueing sample buffers with -enqueueSampleBuffer: moves it to the Rendering or Failed status (the header).
                _status = AVQueuedSampleBufferRenderingStatusRendering;
        }
    }
    // A buffer whose presentation timestamp is not a number has no place on a timeline: the header plays
    // every buffer at the time its output timestamp names on the timebase. Measured on the
    // host for a buffer with no frames: nothing is raised and the status is unchanged.
    @synchronized (self) {
        [self charon_drainPending];
    }
    [self charon_reportReadiness];
}

- (void)flush
{
    // The header says this discards the pending enqueued sample buffers, and that more can be appended
    // after -flush (the header). The status is left alone: measured, a flush on a renderer that
    // holds no media leaves it Unknown, and a renderer that has rendered is still one that has.
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
    // The header describes the flush as dropping enqueued buffers with presentation time stamps at or
    // after the given time, and notes that a flush can fail when the source time is too close to, or before, the current
    // time (the header). Measured on the host, on a renderer holding no media, for an earlier time and
    // for one in the future alike: the handler is called with YES and nothing is raised, kCMTimeInvalid
    // included.
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
                // The queue's own buffers carry no timestamp of their own, so the ones already handed over
                // cannot be dropped one at a time and they go with the reset.
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
    // When this method runs more than once, only the most recent call takes effect (the header), so the
    // previous request is dropped rather than run beside this one.
    @synchronized (self) {
        _requestQueue = queue ? queue : dispatch_get_main_queue();
        _requestBlock = block;
    }
    [self charon_reportReadiness];
}

- (void)stopRequestingMediaData
{
    // The header permits calling it from either side of the block boundary, which is
    // what dropping the block outright is.
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
    // Every arrival is a dispatch, so the block runs again once the renderer is ready again, as the header
    // describes for obtaining more media. Measured on the host: it runs at all for
    // a renderer that holds no media, and stops on -stopRequestingMediaData.
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
    // The header gives the default for applications linked on iOS 15.0 or macOS 12.0 and later as
    // AVAudioTimePitchAlgorithmTimeDomain, which is what this Mac's own renderer answers for -init
    // (measured: "TimeDomain") and the constant the port carries in AVFoundationConstants70.m. The
    // algorithm has no effect on the audio this class renders, because the release carries no time-pitch
    // unit to apply it with; what was measured instead is in facts/AVFoundation/SampleBufferRender11.md.
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
    // Measured on the host, and it is not a clamp: -setVolume: 2.0 leaves -volume reading 2.0 and
    // -setVolume: -1.0 leaves it reading -1.0. The property is "Indicates the current audio volume of the
    // AVSampleBufferAudioRenderer" and its own two documented points are 0.0 for silence and 1.0 for the
    // full volume of the media; what the release's queue does with a value outside that range is the
    // release's business, and -AudioQueueSetParameter answers 0 for one (measured on this Mac).
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

// Volume and muting are the queue's own parameters, so they take effect on the queue and not on the media.
// The value goes by value on this platform (AudioQueue.h:1392), which is the one thing about this call
// that differs from the macOS spelling of the same function.
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

// The one thing the synchronizer says to a renderer it drives: its rate changed. The header is exact about
// which rate changes flush the media and which do not: a normal pause (non-zero to 0.0) and the
// resume back to the same non-zero rate - so a pause and its matching resume are the one
// pair that changes nothing, and every other rate change flushes and says so with the notification the
// header names for it.
- (void)charon_renderSynchronizerDidChangeRate
{
    float now = (float)CMTimebaseGetRate(_timebase);
    float was = _lastRate;
    _lastRate = now;
    if (now == was)
        return;
    if (was != 0.0f && now == 0.0f) {
        _lastNonZeroRate = was;          // a pause: the header says nothing is flushed
        return;
    }
    if (was == 0.0f && now != 0.0f && now == _lastNonZeroRate)
        return;                          // its resume: nothing is flushed either
    CMTime flushedAt = kCMTimeInvalid;
    @synchronized (self) {
        if (!_pending.count)
            // Measured on the host, for a renderer holding no media: no notification arrives, and a renderer
            // that flushed nothing has nothing to report.
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

// The queue is built from the format the first media names, and it is the queue that says when the client
// may hand over more: -AudioQueueAllocateBuffer fails when the queue has no memory for another buffer, so
// asking it is what -isReadyForMoreMediaData means and no buffer count is invented anywhere in this file.
- (void)charon_drainPending
{
    if (!_pending.count)
        return;
    double rate = CMTimebaseGetRate(_timebase);
    if (rate <= 0.0)
        return;     // the clock is stopped, so there is no start time to give a buffer yet
    if (!_queue && ![self charon_openQueueFor:(CharonAVPendingBuffer *)[_pending firstObject]])
        return;
    while (_pending.count) {
        CharonAVPendingBuffer *pending = [_pending objectAtIndex:0];
        AudioQueueBufferRef buffer = [self charon_bufferForBytes:(UInt32)[self charon_bytesOf:pending]];
        if (!buffer)
            break;
        if (![self charon_fill:buffer from:pending] || ![self charon_enqueue:buffer at:pending->presentation]) {
            // The buffer stays at the head of the queue: a renderer that could not hand it over still holds
            // it, which is what -isReadyForMoreMediaData answers for. Found by the differential, which
            // flagged the row (the unmutated port answered YES there where the host answers NO).
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
        // The queue plays what it is given, and what it can be given is what the release's own
        // -CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer lays out as audio, which is linear PCM.
        // The header says this class decompresses compressed audio as well, and this release has nothing
        // the port can decode it with that could be measured on this machine: what is missing, and what the
        // port answers instead, is in facts/AVFoundation/SampleBufferRender11.md.
        [self charon_failWithReason:[NSString stringWithFormat:@"the sample buffer is in format %u, which is not linear PCM",
                                     (unsigned)asbd->mFormatID]];
        return NO;
    }
    _format = *asbd;
    OSStatus status = AudioQueueNewOutput(&_format, charon_queueReturnedBuffer, (__bridge void *)self,
                                          NULL, NULL, 0, &_queue);
    if (status != noErr || !_queue) {
        // An output queue this release could not make is a renderer that cannot render, and the header's
        // answer for that is status Failed with an error rather than a renderer that says it is rendering.
        // This is what this Mac answers for every renderer, because CoreAudio reports its hardware not
        // running ('who?') and AudioQueueNewOutput fails - facts/AVFoundation/SampleBufferRender11.md.
        _queue = NULL;
        [self charon_failWithReason:[NSString stringWithFormat:@"AudioQueueNewOutput answered %d", (int)status]];
        return NO;
    }
    [self charon_applyVolume];
    return YES;
}

// How many bytes of audio the buffer at the head of the queue has to hold.
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

// A buffer the queue has already given back and that is big enough for the media at hand, or a new one from
// the queue. Nothing here decides how many there should be: the queue's own refusal is the bound.
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

// The audio out of the sample buffer and into the queue's buffer, through the release's own
// CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer (exported by 6.1.3's CoreMedia, measured, and the
// same two-call shape CMSampleBufferCopyPCMDataIntoAudioBufferList already uses in this package): the
// sample buffer alone decides how its own data is laid out, and this renderer copies out of the list the
// release fills in.
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
        // Each channel's bytes go where that channel lives in the queue's buffer, which is mBytesPerFrame
        // apart for interleaved and for non-interleaved formats alike.
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

// The whole of the timestamp mapping: a presentation time on the synchronizer's clock becomes a
// queue-relative sample time, read off the queue at the instant of the enqueue.
- (BOOL)charon_enqueue:(AudioQueueBufferRef)buffer at:(CMTime)presentation
{
    if (!_running) {
        // A queue that will not start cannot be given a buffer with a start time, so the status is what
        // says so rather than a failure that only shows up as silence.
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
        // Without a queue time there is nothing to count frames from, and a buffer whose start time the
        // queue cannot place is worse than one that says so.
        // Measured on this Mac, where there is no audio device for the queue to run: the queue is made,
        // started and given a buffer, and -AudioQueueGetCurrentTime answers -66678 with no valid time in
        // it, because the queue's time comes from the device's clock (facts/AVFoundation/
        // SampleBufferRender11.md). Without that time there is nothing to count frames from and nothing to
        // place the buffer at.
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

// The queue hands a buffer back when it has finished playing it, which is what makes the renderer ready for
// more. Its callback runs in a realtime thread, so the work it does happens on this class's own queue.
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

    // AudioQueueReset is the release's own reset, which AudioQueue.h:1327 documents as flushing any queued
    // buffer and dropping every buffer from its scheduled use. AudioQueueFlush on this platform is only the
// sequence of encoded buffers (AudioQueue.h:1303). A reset that fails is a flush that did not happen, so its
// status goes where the header says a failed renderer's does: into -error, with the status that says so.
// The buffers it hands back stay ours - they are ours until -AudioQueueFreeBuffer - and the callbacks it
// invokes for them put them back on the spare list, which is why nothing is dropped here.
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
    // AVErrorUnknown is the release's own code for an error with no more specific one, and
    // AVFoundationErrorDomain is its own symbol (tools/cache-index/first-rung.lua _AVFoundationErrorDomain
    // answers 4.0).
    _status = AVQueuedSampleBufferRenderingStatusFailed;
    if (!_error)
        _error = [[NSError alloc] initWithDomain:AVFoundationErrorDomain
                                            code:AVErrorUnknown
                                        userInfo:@{ NSLocalizedDescriptionKey: reason }];
}

@end
