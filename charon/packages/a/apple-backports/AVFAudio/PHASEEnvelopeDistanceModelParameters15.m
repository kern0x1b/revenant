#import "CharonAVFAudio.h"
#import <PHASE/PHASE.h>

@implementation PHASEEnvelopeDistanceModelParameters {
    PHASEEnvelope *_charon_envelope;
}

- (instancetype)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

+ (instancetype)new
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (instancetype)initWithEnvelope:(PHASEEnvelope *)envelope
{
    if ((self = [PHASEEnvelopeDistanceModelParameters alloc])) {
        _charon_envelope = envelope;
    }
    return self;
}

- (PHASEEnvelope *)envelope
{
    return _charon_envelope;
}

@end
