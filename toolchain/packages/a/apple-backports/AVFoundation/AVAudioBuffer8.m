#import "RevenantAVAudioBuffer.h"

@implementation RevenantAudioBuffer {
@private
    RevenantAudioBufferImpl *_revenant;
    AVAudioFormat *_revenant_format;
}

- (RevenantAudioBufferImpl *)revenant_impl
{
    return _revenant;
}

- (void)revenant_setFormat:(AVAudioFormat *)format
{
    _revenant_format = format;
}

- (RevenantAudioBufferImpl *)revenant_allocate
{
    if (!_revenant)
        _revenant = calloc(1, sizeof(RevenantAudioBufferImpl));
    return _revenant;
}

- (void)dealloc
{
    if (_revenant) {
        if (_revenant->bufferList) {
            for (UInt32 i = 0; i < _revenant->bufferList->mNumberBuffers; i++)
                free(_revenant->bufferList->mBuffers[i].mData);
            free(_revenant->bufferList);
        }
        free(_revenant->channelPointers);
        free(_revenant);
    }
}

- (AVAudioFormat *)format
{
    return _revenant_format;
}

- (const AudioBufferList *)audioBufferList
{
    return _revenant ? _revenant->bufferList : NULL;
}

- (AudioBufferList *)mutableAudioBufferList
{
    return _revenant ? _revenant->bufferList : NULL;
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
