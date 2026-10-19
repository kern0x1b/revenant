#import <Speech/Speech.h>

// One segment of a transcription, iOS 10. A fresh segment answers as the host answers a fresh one: no substring and no
// alternatives, an empty range, and zero for the times and the confidence (facts/Speech/recognition-data.md).
@implementation SFTranscriptionSegment {
    NSString *_substring;
    NSRange _substringRange;
    NSTimeInterval _timestamp;
    NSTimeInterval _duration;
    float _confidence;
    NSArray<NSString *> *_alternativeSubstrings;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (id)copyWithZone:(NSZone *)zone
{
    SFTranscriptionSegment *copy = [[[self class] allocWithZone:zone] init];
    copy->_substring = _substring;
    copy->_substringRange = _substringRange;
    copy->_timestamp = _timestamp;
    copy->_duration = _duration;
    copy->_confidence = _confidence;
    copy->_alternativeSubstrings = _alternativeSubstrings;
    return copy;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        _substring = [coder decodeObjectOfClass:[NSString class] forKey:@"substring"];
        _substringRange = [[coder decodeObjectOfClass:[NSValue class] forKey:@"substringRange"] rangeValue];
        _timestamp = [coder decodeDoubleForKey:@"timestamp"];
        _duration = [coder decodeDoubleForKey:@"duration"];
        _confidence = [coder decodeFloatForKey:@"confidence"];
        NSSet *stringClasses = [NSSet setWithObjects:[NSArray class], [NSString class], nil];
        _alternativeSubstrings = [coder decodeObjectOfClasses:stringClasses forKey:@"alternativeSubstrings"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_substring forKey:@"substring"];
    [coder encodeObject:[NSValue valueWithRange:_substringRange] forKey:@"substringRange"];
    [coder encodeDouble:_timestamp forKey:@"timestamp"];
    [coder encodeDouble:_duration forKey:@"duration"];
    [coder encodeFloat:_confidence forKey:@"confidence"];
    [coder encodeObject:_alternativeSubstrings forKey:@"alternativeSubstrings"];
}

@end
