#import <Speech/Speech.h>

@implementation SFSpeechRecognitionTask

@dynamic state, error;

- (BOOL)isFinishing
{
    return NO;
}

- (BOOL)isCancelled
{
    return NO;
}

@end
