#import "CharonAVAudioBuffer.h"

// The base class of the pair, under a Charon-owned name - see CharonAVAudioBuffer.h for why
// `AVAudioBuffer` itself is not it: the real name is already a different, incompatible private
// class on this release. Never instantiated directly; only AVAudioPCMBuffer, in its own object
// file, is a real subclass.

@implementation CharonAudioBuffer {
@private
    CharonAudioBufferImpl *_charon;
    AVAudioFormat *_charon_format;   // a real ivar, ARC-retained - see the struct's own comment in the header
}

// Both accessors are ordinary instance methods, callable from AVAudioPCMBuffer as any inherited
// method would be, even though `_charon` itself stays private to this @implementation.
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
    // Only AVAudioPCMBuffer is a real subclass in this port; the base class is never
    // instantiated directly, matching the real framework's own abstract-in-practice AVAudioBuffer.
    return nil;
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    return nil;
}

@end
