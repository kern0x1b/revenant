#import <Speech/Speech.h>
#import <AVFoundation/AVFoundation.h>

// The request of iOS 10 for audio that an application streams in. The port captures no audio and no recognizer runs, so the
// audio appended is not kept and nothing reads it: the appends and the end of audio are accepted and do nothing. The native
// format is the one the host gives a fresh instance, 16 kHz, one channel, 16-bit integers (facts/Speech/recognition-data.md).
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
