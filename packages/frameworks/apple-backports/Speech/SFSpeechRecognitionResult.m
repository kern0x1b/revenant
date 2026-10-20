#import <Speech/Speech.h>

@implementation SFSpeechRecognitionResult {
    SFTranscription *_bestTranscription;
    NSArray<SFTranscription *> *_transcriptions;
    BOOL _final;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _transcriptions = @[];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    SFSpeechRecognitionResult *copy = [[[self class] allocWithZone:zone] init];
    copy->_bestTranscription = _bestTranscription;
    copy->_transcriptions = _transcriptions;
    copy->_final = _final;
    return copy;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        NSSet *transcriptionClasses = [NSSet setWithObjects:[NSArray class], [SFTranscription class], nil];
        _bestTranscription = [coder decodeObjectOfClass:[SFTranscription class] forKey:@"bestTranscription"];
        _transcriptions = [coder decodeObjectOfClasses:transcriptionClasses forKey:@"transcriptions"];
        _final = [coder decodeBoolForKey:@"final"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_bestTranscription forKey:@"bestTranscription"];
    [coder encodeObject:_transcriptions forKey:@"transcriptions"];
    [coder encodeBool:_final forKey:@"final"];
}

@end
