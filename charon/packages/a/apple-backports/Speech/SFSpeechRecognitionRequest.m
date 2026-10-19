#import <Speech/Speech.h>

// The request of iOS 10 that a recognizer takes. An application fills one in and hands it over, and this release has no
// recognizer to take it, so the request keeps the values it is given. A fresh instance answers as the host answers one
// (facts/Speech/recognition-data.md).
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
