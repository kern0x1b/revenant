#import <AVFAudio/AVSpeechSynthesis.h>

@implementation AVSpeechUtterance {
    NSString *_speechString;
    AVSpeechSynthesisVoice *_voice;
    float _rate;
    float _pitchMultiplier;
    float _volume;
    NSTimeInterval _preUtteranceDelay;
    NSTimeInterval _postUtteranceDelay;
}

@dynamic attributedSpeechString;
@dynamic prefersAssistiveTechnologySettings;

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
