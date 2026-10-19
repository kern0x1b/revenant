#import <Speech/Speech.h>

// The task of iOS 10. No recognizer makes one on this device (SFSpeechRecognizer answers nil), so a task is never started,
// and a fresh one is not finishing and not cancelled, which is what the host answers for a fresh task (case 13). The state,
// the error, finish and cancel are not carried: the host ends the process when they are read or sent to a fresh task, so
// nothing measures the answers they should give (facts/Speech/recognizer.md).
@implementation SFSpeechRecognitionTask

// The state and the error are declared but not carried, for the reason in SFSpeechRecognizer.m: @dynamic keeps them absent
// (facts/Speech/recognizer.md).
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
