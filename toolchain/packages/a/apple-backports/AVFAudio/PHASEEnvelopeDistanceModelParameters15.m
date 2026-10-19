#import "RevenantAVFAudio.h"
#import <PHASE/PHASE.h>

@implementation PHASEEnvelopeDistanceModelParameters {
    PHASEEnvelope *_revenant_envelope;
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
        _revenant_envelope = envelope;
    }
    return self;
}

- (PHASEEnvelope *)envelope
{
    return _revenant_envelope;
}

@end
