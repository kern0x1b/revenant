#import <Speech/Speech.h>

@implementation SFSpeechURLRecognitionRequest

- (instancetype)initWithURL:(NSURL *)URL
{
    if ((self = [super init])) {
        _URL = [URL copy];
    }
    return self;
}

@end
