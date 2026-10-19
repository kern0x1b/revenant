#import <AVFAudio/AVSpeechSynthesis.h>
#import <objc/runtime.h>

static const char charon_output_channels_key;

@implementation AVSpeechSynthesizer (CharonSpeechSynthesizer10)

- (NSArray<AVAudioSessionChannelDescription *> *)outputChannels
{
    return objc_getAssociatedObject(self, &charon_output_channels_key);
}

- (void)setOutputChannels:(NSArray<AVAudioSessionChannelDescription *> *)outputChannels
{
    objc_setAssociatedObject(self, &charon_output_channels_key, outputChannels, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
