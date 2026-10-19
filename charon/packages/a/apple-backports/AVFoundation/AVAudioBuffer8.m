#import "CharonAVAudioBuffer.h"

@implementation CharonAudioBuffer {
@private
    CharonAudioBufferImpl *_charon;
    AVAudioFormat *_charon_format;
}

- (CharonAudioBufferImpl *)charon_impl
{
    return _charon;
}

- (void)charon_setFormat:(AVAudioFormat *)format
{
    _charon_format = format;
}

- (CharonAudioBufferImpl *)charon_allocate
{
    if (!_charon)
        _charon = calloc(1, sizeof(CharonAudioBufferImpl));
    return _charon;
}

- (void)dealloc
{
    if (_charon) {
        if (_charon->bufferList) {
            for (UInt32 i = 0; i < _charon->bufferList->mNumberBuffers; i++)
                free(_charon->bufferList->mBuffers[i].mData);
            free(_charon->bufferList);
        }
        free(_charon->channelPointers);
        free(_charon);
    }
}

- (AVAudioFormat *)format
{
    return _charon_format;
}

- (const AudioBufferList *)audioBufferList
{
    return _charon ? _charon->bufferList : NULL;
}

- (AudioBufferList *)mutableAudioBufferList
{
    return _charon ? _charon->bufferList : NULL;
}

- (id)copyWithZone:(NSZone *)zone
{
    return nil;
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    return nil;
}

@end
