#import <Speech/Speech.h>
#import <AVFoundation/AVFoundation.h>

@implementation SFSpeechAudioBufferRecognitionRequest

- (AVAudioFormat *)nativeAudioFormat
{
    return [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16 sampleRate:16000 channels:1 interleaved:YES];
}

- (void)appendAudioPCMBuffer:(AVAudioPCMBuffer *)audioPCMBuffer
{
}

- (void)appendAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
}

- (void)endAudio
{
}

@end
