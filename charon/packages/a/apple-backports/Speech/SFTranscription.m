#import <Speech/Speech.h>

@implementation SFTranscription {
    NSString *_formattedString;
    NSArray<SFTranscriptionSegment *> *_segments;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (id)copyWithZone:(NSZone *)zone
{
    SFTranscription *copy = [[[self class] allocWithZone:zone] init];
    copy->_formattedString = _formattedString;
    copy->_segments = _segments;
    return copy;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        NSSet *segmentClasses = [NSSet setWithObjects:[NSArray class], [SFTranscriptionSegment class], nil];
        _formattedString = [coder decodeObjectOfClass:[NSString class] forKey:@"formattedString"];
        _segments = [coder decodeObjectOfClasses:segmentClasses forKey:@"segments"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_formattedString forKey:@"formattedString"];
    [coder encodeObject:_segments forKey:@"segments"];
}

@end
