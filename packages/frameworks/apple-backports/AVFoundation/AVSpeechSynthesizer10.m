#import <AVFAudio/AVSpeechSynthesis.h>
#import <objc/runtime.h>

static const char revenant_output_channels_key;

@implementation AVSpeechSynthesizer (RevenantSpeechSynthesizer10)

- (NSArray<AVAudioSessionChannelDescription *> *)outputChannels
{
    return objc_getAssociatedObject(self, &revenant_output_channels_key);
}

- (void)setOutputChannels:(NSArray<AVAudioSessionChannelDescription *> *)outputChannels
{
    objc_setAssociatedObject(self, &revenant_output_channels_key, outputChannels, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
