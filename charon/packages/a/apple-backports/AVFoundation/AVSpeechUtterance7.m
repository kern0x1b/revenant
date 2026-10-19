#import <AVFAudio/AVSpeechSynthesis.h>

// AVSpeechUtterance is a data class: the text, the voice and the four numbers that shape how the text is
// spoken, held as the caller set them. Nothing here speaks; the engine that does is AVSpeechSynthesizer,
// a later slice. What this class answers is what the release's own class answers, measured against the
// host (tests/backports/host/avf-speech/run.sh) and not typed from the header:
//
//   * +speechUtteranceWithString: and -initWithString: give the defaults - rate 0.5, pitch 1, volume 1,
//     both delays 0. A plain -init does not: it leaves every number at zero.
//   * rate and volume floor at 0: a negative or NaN value becomes 0. pitchMultiplier floors at 0.5: a
//     negative, zero or NaN value becomes 0.5. None of the three has a ceiling - 2 stays 2.
//   * the string is retained, not copied: a caller who appends to its NSMutableString sees the change.
//   * a copy shares the string and the voice and copies every number.

@implementation AVSpeechUtterance {
    NSString *_speechString;
    AVSpeechSynthesisVoice *_voice;
    float _rate;
    float _pitchMultiplier;
    float _volume;
    NSTimeInterval _preUtteranceDelay;
    NSTimeInterval _postUtteranceDelay;
}

// The SDK header also declares two later properties on this class, and clang synthesises an ivar and
// accessors for any declared property this implementation leaves out: without these lines the port would
// answer nil and NO for them silently. @dynamic says the port does not carry them, so the selectors are
// unrecognized, as they are on a release that lacks them (checks.m asserts this).
@dynamic attributedSpeechString;             // iOS 10
@dynamic prefersAssistiveTechnologySettings; // iOS 14

+ (instancetype)speechUtteranceWithString:(NSString *)string
{
    return [[self alloc] initWithString:string];
}

- (instancetype)initWithString:(NSString *)string
{
    if ((self = [super init])) {
        _speechString = string;
        _rate = AVSpeechUtteranceDefaultSpeechRate;
        _pitchMultiplier = 1.0f;
        _volume = 1.0f;
    }
    return self;
}

// NaN fails both comparisons, so it takes the floor as well as a negative value does.
- (void)setRate:(float)rate
{
    _rate = (rate >= 0.0f) ? rate : 0.0f;
}

- (void)setPitchMultiplier:(float)pitchMultiplier
{
    _pitchMultiplier = (pitchMultiplier >= 0.5f) ? pitchMultiplier : 0.5f;
}

- (void)setVolume:(float)volume
{
    _volume = (volume >= 0.0f) ? volume : 0.0f;
}

- (NSString *)speechString
{
    return _speechString;
}

- (float)rate
{
    return _rate;
}

- (float)pitchMultiplier
{
    return _pitchMultiplier;
}

- (float)volume
{
    return _volume;
}

- (AVSpeechSynthesisVoice *)voice
{
    return _voice;
}

- (void)setVoice:(AVSpeechSynthesisVoice *)voice
{
    _voice = voice;
}

- (NSTimeInterval)preUtteranceDelay
{
    return _preUtteranceDelay;
}

- (void)setPreUtteranceDelay:(NSTimeInterval)preUtteranceDelay
{
    _preUtteranceDelay = preUtteranceDelay;
}

- (NSTimeInterval)postUtteranceDelay
{
    return _postUtteranceDelay;
}

- (void)setPostUtteranceDelay:(NSTimeInterval)postUtteranceDelay
{
    _postUtteranceDelay = postUtteranceDelay;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    AVSpeechUtterance *copy = [[[self class] allocWithZone:zone] initWithString:_speechString];
    copy->_voice = _voice;
    copy->_rate = _rate;
    copy->_pitchMultiplier = _pitchMultiplier;
    copy->_volume = _volume;
    copy->_preUtteranceDelay = _preUtteranceDelay;
    copy->_postUtteranceDelay = _postUtteranceDelay;
    return copy;
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_speechString forKey:@"speechString"];
    [coder encodeObject:_voice forKey:@"voice"];
    [coder encodeFloat:_rate forKey:@"rate"];
    [coder encodeFloat:_pitchMultiplier forKey:@"pitchMultiplier"];
    [coder encodeFloat:_volume forKey:@"volume"];
    [coder encodeDouble:_preUtteranceDelay forKey:@"preUtteranceDelay"];
    [coder encodeDouble:_postUtteranceDelay forKey:@"postUtteranceDelay"];
}

// The voice is decoded as NSObject until AVSpeechSynthesisVoice is carried: naming that class here now
// would make this image import a class the 6.1.3 release does not have.
- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        _speechString = [coder decodeObjectOfClass:[NSString class] forKey:@"speechString"];
        _voice = [coder decodeObjectOfClass:[NSObject class] forKey:@"voice"];
        _rate = [coder decodeFloatForKey:@"rate"];
        _pitchMultiplier = [coder decodeFloatForKey:@"pitchMultiplier"];
        _volume = [coder decodeFloatForKey:@"volume"];
        _preUtteranceDelay = [coder decodeDoubleForKey:@"preUtteranceDelay"];
        _postUtteranceDelay = [coder decodeDoubleForKey:@"postUtteranceDelay"];
    }
    return self;
}

@end
