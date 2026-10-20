#import <AVFAudio/AVSpeechSynthesis.h>
#import <objc/runtime.h>

static const char revenant_uses_application_audio_session_key;

@implementation AVSpeechSynthesizer (RevenantSpeechSynthesizer13)

- (BOOL)usesApplicationAudioSession
{
    NSNumber *uses = objc_getAssociatedObject(self, &revenant_uses_application_audio_session_key);
    return uses ? uses.boolValue : NO;
}

- (void)setUsesApplicationAudioSession:(BOOL)usesApplicationAudioSession
{
    objc_setAssociatedObject(self, &revenant_uses_application_audio_session_key, @(usesApplicationAudioSession),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
