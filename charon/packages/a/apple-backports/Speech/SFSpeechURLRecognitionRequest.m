#import <Speech/Speech.h>

// The request of iOS 10 for a recording on disk. The URL is kept as given; the header makes init unavailable, so the
// only way in is initWithURL:, and the defaults are the ones of SFSpeechRecognitionRequest.
@implementation SFSpeechURLRecognitionRequest

- (instancetype)initWithURL:(NSURL *)URL
{
    if ((self = [super init])) {
        _URL = [URL copy];
    }
    return self;
}

@end
