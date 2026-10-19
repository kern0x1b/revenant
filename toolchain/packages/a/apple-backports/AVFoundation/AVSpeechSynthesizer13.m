#import <AVFAudio/AVSpeechSynthesis.h>
#import <objc/runtime.h>

static const char charon_uses_application_audio_session_key;

@implementation AVSpeechSynthesizer (CharonSpeechSynthesizer13)

- (BOOL)usesApplicationAudioSession
{
    NSNumber *uses = objc_getAssociatedObject(self, &charon_uses_application_audio_session_key);
    return uses ? uses.boolValue : NO;
}

- (void)setUsesApplicationAudioSession:(BOOL)usesApplicationAudioSession
{
    objc_setAssociatedObject(self, &charon_uses_application_audio_session_key, @(usesApplicationAudioSession),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
