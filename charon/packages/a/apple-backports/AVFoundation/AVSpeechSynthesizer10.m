#import <AVFAudio/AVSpeechSynthesis.h>
#import <objc/runtime.h>

// The output channels, which iOS 10 added to the synthesizer as a category beside its class in AVSpeechSynthesizer7.m,
// one release per object file (backports.lua's minimums()). The header (AVSpeechSynthesis.h) says the speech is
// replicated to each channel of the channel descriptions it names, and that nil, its default, leaves the choice to the
// system. 6.1.3's VoiceServices has no per-channel routing (facts/AVFoundation/AVSpeech.md), so nothing reads the value on
// this release: it is the value the caller set, held per synthesizer and read back as it was given, the way the
// header's own accessor answers. Measured on the host: nil on a fresh synthesizer, @[] and nil read back as set, and an
// array of the host's own AVAudioSessionChannelDescription objects reads back as the same array.
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
