#import <Speech/Speech.h>

@implementation SFSpeechRecognitionRequest

- (instancetype)init
{
    if ((self = [super init])) {
        _shouldReportPartialResults = YES;
        _contextualStrings = @[];
    }
    return self;
}

@end
