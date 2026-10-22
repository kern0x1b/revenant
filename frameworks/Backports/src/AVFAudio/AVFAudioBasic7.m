#import <AVFAudio/AVFAudio.h>
#import <objc/runtime.h>

static const char revenant_input_muted_key;
static const char revenant_sandbox_safe_key;

@implementation AVSpeechSynthesizer (RevenantBasic7)

- (BOOL)prefersAssistiveTechnologySettings
{
    return NO;
}

- (void)setPrefersAssistiveTechnologySettings:(BOOL)prefers
{
}

@end

@implementation AVSpeechUtterance (RevenantBasic7)

- (NSAttributedString *)attributedSpeechString
{
    return [[NSAttributedString alloc] initWithString:self.speechString];
}

- (NSDictionary *)audioFileSettings
{
    return @{};
}

@end

@implementation AVSpeechSynthesisVoice (RevenantBasic7)

- (NSString *)gender
{
    return AVSpeechSynthesisVoiceGenderUnspecified;
}

- (BOOL)isStandard
{
    return YES;
}

@end

@implementation AVAudioTime (RevenantBasic7)

- (BOOL)isHostTimeValid
{
    return YES;
}

- (BOOL)isSampleTimeValid
{
    return YES;
}

@end

@implementation AVAudioSession (RevenantBasic7)

- (BOOL)isInputMuted
{
    return [objc_getAssociatedObject(self, &revenant_input_muted_key) boolValue];
}

- (void)setInputMuted:(BOOL)muted
{
    objc_setAssociatedObject(self, &revenant_input_muted_key, @(muted), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isSandboxSafe
{
    return [objc_getAssociatedObject(self, &revenant_sandbox_safe_key) boolValue];
}

- (void)setSandboxSafe:(BOOL)safe
{
    objc_setAssociatedObject(self, &revenant_sandbox_safe_key, @(safe), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

