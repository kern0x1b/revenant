#import "CharonAVAudioBuffer.h"

// AVAudioPCMBuffer owns a Core Audio AudioBufferList the same way the real class does: one
// malloc'd AudioBufferList, one calloc'd (so a freshly made buffer reads as silence rather than
// whatever heap garbage was there) chunk of sample memory per AudioBuffer, freed together in
// AVAudioBuffer8.m's -dealloc.
//
// The one thing this port never builds silently: a graph that runs and produces nothing. Nothing
// here decides that on its own, since a buffer of zero samples is a legitimate buffer - but every
// byte a caller writes through floatChannelData/int16ChannelData is read back through the same
// pointer, never copied into a separate "real" location the way a stub would, so what a caller
// wrote is what -audioBufferList reports.

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
            list->mBuffers[i].mDataByteSize = 0;   // frameLength starts at 0, mirroring the real class
            list->mBuffers[i].mData = frameCapacity ? calloc(1, asbd->mBytesPerFrame * frameCapacity) : NULL;
        }

        CharonAudioBufferImpl *impl = [self charon_allocate];
        [self charon_setFormat:format];
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

- (void)charon_syncFrameLength
{
    CharonAudioBufferImpl *impl = [self charon_allocate];
    for (UInt32 i = 0; i < impl->bufferList->mNumberBuffers; i++)
        impl->bufferList->mBuffers[i].mDataByteSize = impl->frameLength * impl->bytesPerFramePerBuffer;
}

- (AVAudioFrameCount)frameCapacity
{
    CharonAudioBufferImpl *impl = [self charon_impl];
    return impl ? impl->frameCapacity : 0;
}

- (AVAudioFrameCount)frameLength
{
    CharonAudioBufferImpl *impl = [self charon_impl];
    return impl ? impl->frameLength : 0;
}

- (void)setFrameLength:(AVAudioFrameCount)frameLength
{
    CharonAudioBufferImpl *impl = [self charon_impl];
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
    CharonAudioBufferImpl *impl = [self charon_impl];
    return impl ? impl->stride : 0;
}

- (float *const *)floatChannelData
{
    CharonAudioBufferImpl *impl = [self charon_impl];
    return (impl && [self.format commonFormat] == AVAudioPCMFormatFloat32) ? (float *const *)impl->channelPointers : NULL;
}

- (int16_t *const *)int16ChannelData
{
    CharonAudioBufferImpl *impl = [self charon_impl];
    return (impl && [self.format commonFormat] == AVAudioPCMFormatInt16) ? (int16_t *const *)impl->channelPointers : NULL;
}

- (int32_t *const *)int32ChannelData
{
    CharonAudioBufferImpl *impl = [self charon_impl];
    return (impl && [self.format commonFormat] == AVAudioPCMFormatInt32) ? (int32_t *const *)impl->channelPointers : NULL;
}

- (id)copyWithZone:(NSZone *)zone
{
    CharonAudioBufferImpl *impl = [self charon_impl];
    if (!impl)
        return nil;
    AVAudioPCMBuffer *copy = [[AVAudioPCMBuffer allocWithZone:zone] initWithPCMFormat:self.format frameCapacity:impl->frameCapacity];
    CharonAudioBufferImpl *other = [copy charon_impl];
    other->frameLength = impl->frameLength;
    for (UInt32 i = 0; i < impl->bufferList->mNumberBuffers; i++)
        memcpy(other->bufferList->mBuffers[i].mData, impl->bufferList->mBuffers[i].mData, impl->bufferList->mBuffers[i].mDataByteSize);
    [copy charon_syncFrameLength];
    return copy;
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    return [self copyWithZone:zone];
}

- (NSString *)description
{
    CharonAudioBufferImpl *impl = [self charon_impl];
    return [NSString stringWithFormat:@"<AVAudioPCMBuffer %p: %@, frameLength %u / %u>", self, self.format,
                                      (unsigned)impl->frameLength, (unsigned)impl->frameCapacity];
}

@end
