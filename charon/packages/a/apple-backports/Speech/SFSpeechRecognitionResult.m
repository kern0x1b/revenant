#import <Speech/Speech.h>

// The result of iOS 10 that a recognizer hands over. No recognizer runs here, so a result is one an application made.
// A fresh result is not final and has no transcription. The host raises an exception when it reads the transcriptions of a
// fresh result; the port answers an empty array instead, because an API must never crash its caller
// (facts/Speech/recognition-data.md).
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
