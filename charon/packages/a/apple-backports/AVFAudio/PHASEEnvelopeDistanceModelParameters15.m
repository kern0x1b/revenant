#import "CharonAVFAudio.h"
#import <PHASE/PHASE.h>

// PHASEEnvelopeDistanceModelParameters: a distance model whose curve is a PHASEEnvelope.
//
// The header says what the envelope means here, and it is worth saying in the port's own words
// because it is the whole contract (PHASEDistanceModel.h:108-113): an envelope here has x values that are
// distance and y values that are gain, and the property reads the same way.
//
// There is nothing to translate here - PHASE arrived in iOS 15 and the port's releases are 6.1.3 and
// 4.3, so no release has a PHASEDistanceModel to convert. What there is to carry is the holding of an
// envelope, and the fact that the class is only made the one way the header allows: -init and +new are
// NS_UNAVAILABLE and -initWithEnvelope: is the designated initializer, because a distance model with
// no envelope has no distance model in it.

@implementation PHASEEnvelopeDistanceModelParameters {
    PHASEEnvelope *_charon_envelope;
}

// -init and +new are NS_UNAVAILABLE as well, and the host raises for them the way it does for the envelope
// (measured: "-[PHASEEnvelopeDistanceModelParameters init]: unrecognized selector sent to instance"), so they do the same.
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
    // [super init] is not available here and not a shortcut around it: the superclass,
    // PHASEDistanceModelParameters, marks -init NS_UNAVAILABLE and declares no designated
    // initializer to chain to, so a designated initializer on this class has to allocate the superclass
    // directly. It inherits no state - its only member is its own fadeOutParameters - and all this
    // class holds is the envelope below.
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
