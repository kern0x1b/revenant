#import <AVFAudio/AVFAudio.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation AVAudioSession (RevenantSecondaryAudioHint)

- (BOOL)secondaryAudioShouldBeSilencedHint
{
    return self.otherAudioPlaying;
}

@end
