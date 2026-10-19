#import "RevenantAVAudioBuffer.h"

@implementation AVAudioPCMBuffer

- (instancetype)initWithPCMFormat:(AVAudioFormat *)format frameCapacity:(AVAudioFrameCount)frameCapacity
{
    if ((self = [super init])) {
        const AudioStreamBasicDescription *asbd = [format streamDescription];
        if (!asbd || asbd->mBytesPerFrame == 0 || asbd->mFormatID != kAudioFormatLinearPCM)
            return nil;
        UInt64 byteCapacity = (UInt64)frameCapacity * asbd->mBytesPerFrame;
        if (byteCapacity > UINT32_MAX)
            return nil;

        BOOL interleaved = [format isInterleaved];
        AVAudioChannelCount channels = [format channelCount];
        UInt32 numberOfBuffers = interleaved ? 1 : channels;
        UInt32 channelsPerBuffer = interleaved ? channels : 1;

        AudioBufferList *list = calloc(1, offsetof(AudioBufferList, mBuffers) + numberOfBuffers * sizeof(AudioBuffer));
        list->mNumberBuffers = numberOfBuffers;
        for (UInt32 i = 0; i < numberOfBuffers; i++) {
            list->mBuffers[i].mNumberChannels = channelsPerBuffer;
            list->mBuffers[i].mDataByteSize = 0;
            list->mBuffers[i].mData = frameCapacity ? calloc(1, asbd->mBytesPerFrame * frameCapacity) : NULL;
        }

        RevenantAudioBufferImpl *impl = [self revenant_allocate];
        [self revenant_setFormat:format];
        impl->bufferList = list;
        impl->frameCapacity = frameCapacity;
        impl->frameLength = 0;
        impl->stride = interleaved ? channels : 1;
        impl->bytesPerFramePerBuffer = asbd->mBytesPerFrame;

        AVAudioCommonFormat common = [format commonFormat];
        if (common == AVAudioPCMFormatFloat32 || common == AVAudioPCMFormatInt16 || common == AVAudioPCMFormatInt32) {
            impl->channelPointerCount = channels;
            impl->channelPointers = calloc(channels, sizeof(void *));
            for (AVAudioChannelCount c = 0; c < channels; c++) {
                if (interleaved) {
                    uint8_t *base = list->mBuffers[0].mData;
                    impl->channelPointers[c] = base + c * (asbd->mBitsPerChannel / 8);
                } else {
                    impl->channelPointers[c] = list->mBuffers[c].mData;
                }
            }
        }
    }
    return self;
}

- (void)revenant_syncFrameLength
{
    RevenantAudioBufferImpl *impl = [self revenant_allocate];
    for (UInt32 i = 0; i < impl->bufferList->mNumberBuffers; i++)
        impl->bufferList->mBuffers[i].mDataByteSize = impl->frameLength * impl->bytesPerFramePerBuffer;
}

- (AVAudioFrameCount)frameCapacity
{
    RevenantAudioBufferImpl *impl = [self revenant_impl];
    return impl ? impl->frameCapacity : 0;
}

- (AVAudioFrameCount)frameLength
{
    RevenantAudioBufferImpl *impl = [self revenant_impl];
    return impl ? impl->frameLength : 0;
}

- (void)setFrameLength:(AVAudioFrameCount)frameLength
{
    RevenantAudioBufferImpl *impl = [self revenant_impl];
    if (!impl)
        return;
    if (frameLength > impl->frameCapacity)
        [NSException raise:NSInvalidArgumentException format:@"frameLength %u exceeds frameCapacity %u", (unsigned)frameLength, (unsigned)impl->frameCapacity];
    impl->frameLength = frameLength;
    for (UInt32 i = 0; i < impl->bufferList->mNumberBuffers; i++)
        impl->bufferList->mBuffers[i].mDataByteSize = frameLength * impl->bytesPerFramePerBuffer;
}

- (NSUInteger)stride
{
    RevenantAudioBufferImpl *impl = [self revenant_impl];
    return impl ? impl->stride : 0;
}

- (float *const *)floatChannelData
{
    RevenantAudioBufferImpl *impl = [self revenant_impl];
    return (impl && [self.format commonFormat] == AVAudioPCMFormatFloat32) ? (float *const *)impl->channelPointers : NULL;
}

- (int16_t *const *)int16ChannelData
{
    RevenantAudioBufferImpl *impl = [self revenant_impl];
    return (impl && [self.format commonFormat] == AVAudioPCMFormatInt16) ? (int16_t *const *)impl->channelPointers : NULL;
}

- (int32_t *const *)int32ChannelData
{
    RevenantAudioBufferImpl *impl = [self revenant_impl];
    return (impl && [self.format commonFormat] == AVAudioPCMFormatInt32) ? (int32_t *const *)impl->channelPointers : NULL;
}

- (id)copyWithZone:(NSZone *)zone
{
    RevenantAudioBufferImpl *impl = [self revenant_impl];
    if (!impl)
        return nil;
    AVAudioPCMBuffer *copy = [[AVAudioPCMBuffer allocWithZone:zone] initWithPCMFormat:self.format frameCapacity:impl->frameCapacity];
    RevenantAudioBufferImpl *other = [copy revenant_impl];
    other->frameLength = impl->frameLength;
    for (UInt32 i = 0; i < impl->bufferList->mNumberBuffers; i++)
        memcpy(other->bufferList->mBuffers[i].mData, impl->bufferList->mBuffers[i].mData, impl->bufferList->mBuffers[i].mDataByteSize);
    [copy revenant_syncFrameLength];
    return copy;
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    return [self copyWithZone:zone];
}

- (NSString *)description
{
    RevenantAudioBufferImpl *impl = [self revenant_impl];
    return [NSString stringWithFormat:@"<AVAudioPCMBuffer %p: %@, frameLength %u / %u>", self, self.format,
                                      (unsigned)impl->frameLength, (unsigned)impl->frameCapacity];
}

@end
