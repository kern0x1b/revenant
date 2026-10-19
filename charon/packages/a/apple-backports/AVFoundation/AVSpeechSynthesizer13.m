#import <AVFAudio/AVSpeechSynthesis.h>
#import <objc/runtime.h>

// The application audio session flag, which iOS 13 added to the synthesizer as a category beside its class in
// AVSpeechSynthesizer7.m, one release per object file (backports.lua's minimums()). The header (AVSpeechSynthesis.h)
// says NO makes the synthesizer use a session of its own, and that the default is YES. The host answers NO on a fresh
// synthesizer (macOS 27.0.1, measured with the avf-speech harness), so the port answers NO too: the header's YES is
// the one contradiction written down in facts/AVFoundation/AVSpeech.md, and the iOS default is not measured here. The
// flag is the value the caller set, held per synthesizer and read back as it was given. On 6.1.3 nothing reads it: the
// release has no such flag, and whether its speech uses the application's session is stated in the facts file.
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
