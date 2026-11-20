#import "RevenantAVAudioTap.h"
#include <math.h>

// The ring holds mono float samples in the tap's rate. A power of two, so the indexes wrap with a mask.
static const uint32_t RevenantTapRingSize = 1 << 17;

@implementation RevenantTapPump {
    AVAudioFormat *_format;
    AVAudioFrameCount _bufferSize;
    AVAudioNodeTapBlock _block;
    dispatch_queue_t _queue;
    float *_ring;
    volatile uint32_t _write;
    volatile uint32_t _read;
    volatile int32_t _draining;
    volatile int32_t _stopped;
    double _sourceRate;
    // The linear resampler's state: the position of the next output sample in the current chunk (-1 is the previous chunk's
    // last sample) and that last sample.
    double _position;
    float _previous;
}

- (instancetype)initWithFormat:(AVAudioFormat *)format bufferSize:(AVAudioFrameCount)bufferSize block:(AVAudioNodeTapBlock)block
{
    if ((self = [super init])) {
        _format = format;
        _bufferSize = bufferSize > 0 ? bufferSize : 4096;
        _block = [block copy];
        _queue = dispatch_queue_create("org.revenant.avaudiotap", DISPATCH_QUEUE_SERIAL);
        _ring = calloc(RevenantTapRingSize, sizeof(float));
        _sourceRate = format.sampleRate;
    }
    return self;
}

- (void)dealloc
{
    free(_ring);
}

- (AVAudioFormat *)format
{
    return _format;
}

- (double)sourceRate
{
    return _sourceRate;
}

- (void)setSourceRate:(double)sourceRate
{
    _sourceRate = sourceRate > 0 ? sourceRate : _format.sampleRate;
}

- (void)stop
{
    __atomic_store_n(&_stopped, 1, __ATOMIC_RELEASE);
}

- (void)pushSample:(float)value
{
    uint32_t write = __atomic_load_n(&_write, __ATOMIC_RELAXED);
    uint32_t read = __atomic_load_n(&_read, __ATOMIC_ACQUIRE);
    if (write - read >= RevenantTapRingSize)
        return;
    _ring[write & (RevenantTapRingSize - 1)] = value;
    __atomic_store_n(&_write, write + 1, __ATOMIC_RELEASE);
}

- (void)pushFrames:(const float *)mono count:(UInt32)count
{
    double target = _format.sampleRate;
    if (count == 0 || __atomic_load_n(&_stopped, __ATOMIC_ACQUIRE))
        return;
    if (_sourceRate == target || target <= 0) {
        for (UInt32 index = 0; index < count; index++)
            [self pushSample:mono[index]];
    } else {
        double ratio = _sourceRate / target;
        double position = _position;
        while (position < (double)count - 1) {
            int index = (int)floor(position);
            double fraction = position - index;
            float a = index < 0 ? _previous : mono[index];
            float b = mono[index + 1];
            [self pushSample:(float)(a * (1 - fraction) + b * fraction)];
            position += ratio;
        }
        _position = position - count;
        _previous = mono[count - 1];
    }
    [self wake];
}

- (void)writeInt16:(const int16_t *)samples frames:(UInt32)frames stride:(UInt32)stride muted:(BOOL)muted
{
    float chunk[512];
    UInt32 done = 0;
    while (done < frames) {
        UInt32 count = MIN(512u, frames - done);
        for (UInt32 index = 0; index < count; index++)
            chunk[index] = muted ? 0.0f : (float)samples[(done + index) * stride] / 32768.0f;
        [self pushFrames:chunk count:count];
        done += count;
    }
}

- (void)writeFloat:(const float *)samples frames:(UInt32)frames stride:(UInt32)stride
{
    if (stride == 1) {
        [self pushFrames:samples count:frames];
        return;
    }
    float chunk[512];
    UInt32 done = 0;
    while (done < frames) {
        UInt32 count = MIN(512u, frames - done);
        for (UInt32 index = 0; index < count; index++)
            chunk[index] = samples[(done + index) * stride];
        [self pushFrames:chunk count:count];
        done += count;
    }
}

- (void)wake
{
    if (__atomic_exchange_n(&_draining, 1, __ATOMIC_ACQ_REL) != 0)
        return;
    dispatch_async(_queue, ^{
        [self drain];
    });
}

- (void)drain
{
    for (;;) {
        uint32_t read = __atomic_load_n(&_read, __ATOMIC_RELAXED);
        uint32_t write = __atomic_load_n(&_write, __ATOMIC_ACQUIRE);
        if (write - read < _bufferSize) {
            __atomic_store_n(&_draining, 0, __ATOMIC_RELEASE);
            // Samples that arrived between the check and the flag would wait for the next write, so look once more.
            if (__atomic_load_n(&_write, __ATOMIC_ACQUIRE) - read >= _bufferSize && __atomic_exchange_n(&_draining, 1, __ATOMIC_ACQ_REL) == 0)
                continue;
            return;
        }
        AVAudioPCMBuffer *buffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:_format frameCapacity:_bufferSize];
        if (buffer == nil) {
            __atomic_store_n(&_read, read + _bufferSize, __ATOMIC_RELEASE);
            continue;
        }
        buffer.frameLength = _bufferSize;
        NSUInteger stride = buffer.stride;
        AVAudioChannelCount channels = _format.channelCount;
        float *const *floats = buffer.floatChannelData;
        int16_t *const *ints = buffer.int16ChannelData;
        for (AVAudioFrameCount index = 0; index < _bufferSize; index++) {
            float value = _ring[(read + index) & (RevenantTapRingSize - 1)];
            for (AVAudioChannelCount channel = 0; channel < channels; channel++) {
                if (floats)
                    floats[channel][index * stride] = value;
                else if (ints)
                    ints[channel][index * stride] = (int16_t)(fmaxf(-1.0f, fminf(1.0f, value)) * 32767.0f);
            }
        }
        __atomic_store_n(&_read, read + _bufferSize, __ATOMIC_RELEASE);
        if (!__atomic_load_n(&_stopped, __ATOMIC_ACQUIRE))
            _block(buffer, nil);
    }
}

@end

OSStatus RevenantInputRenderCallback(void *refCon, AudioUnitRenderActionFlags *flags, const AudioTimeStamp *timeStamp,
                                     UInt32 bus, UInt32 frames, AudioBufferList *data)
{
    RevenantInputState *state = refCon;
    if (state == NULL || state->unit == NULL || state->scratch == NULL || frames > state->scratchFrames)
        return noErr;
    AudioBufferList list;
    list.mNumberBuffers = 1;
    list.mBuffers[0].mNumberChannels = 1;
    list.mBuffers[0].mDataByteSize = frames * sizeof(int16_t);
    list.mBuffers[0].mData = state->scratch;
    OSStatus status = AudioUnitRender(state->unit, flags, timeStamp, bus, frames, &list);
    if (status != noErr)
        return status;
    RevenantTapPump *pump = (__bridge RevenantTapPump *)state->pump;
    if (pump != nil)
        [pump writeInt16:state->scratch frames:frames stride:1 muted:state->muted != 0];
    return noErr;
}

// A post-render notify on a node's audio unit: hands the node's output to the pump that its tap installed.
OSStatus RevenantTapRenderNotify(void *refCon, AudioUnitRenderActionFlags *flags, const AudioTimeStamp *timeStamp,
                                 UInt32 bus, UInt32 frames, AudioBufferList *data)
{
    if (!(*flags & kAudioUnitRenderAction_PostRender) || data == NULL || data->mNumberBuffers == 0 || data->mBuffers[0].mData == NULL)
        return noErr;
    RevenantTapPump *pump = (__bridge RevenantTapPump *)refCon;
    AVAudioFormat *format = pump.format;
    if (format.commonFormat == AVAudioPCMFormatInt16) {
        UInt32 channels = data->mBuffers[0].mNumberChannels ?: 1;
        [pump writeInt16:data->mBuffers[0].mData frames:frames stride:channels muted:NO];
    } else {
        UInt32 channels = data->mBuffers[0].mNumberChannels ?: 1;
        [pump writeFloat:data->mBuffers[0].mData frames:frames stride:channels];
    }
    return noErr;
}
