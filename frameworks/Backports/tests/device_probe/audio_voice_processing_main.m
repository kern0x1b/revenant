#import <AVFoundation/AVFoundation.h>
#include <math.h>
#import "check.h"

// The microphone side of the AVAudioEngine backport on a phone: voice processing on the input node (a VoiceProcessingIO
// unit behind the output node), an input tap fed by the microphone, a mixer tap fed by the player, the mute and bypass
// flags, and the completion type of a scheduled buffer. What the microphone hears is not checked: the room decides it,
// and the probe only needs the samples to flow in the format asked for.

@interface Collector : NSObject
@property (nonatomic) NSUInteger frames;
@property (nonatomic) NSUInteger chunks;
@property (nonatomic) double sum;
@property (nonatomic) double peak;
@property (nonatomic) double rate;
@property (nonatomic) NSUInteger channels;
@property (nonatomic) NSUInteger chunkFrames;
- (void)add:(AVAudioPCMBuffer *)buffer;
- (void)reset;
@end

@implementation Collector {
    NSLock *_lock;
}
- (instancetype)init
{
    if ((self = [super init]))
        _lock = [NSLock new];
    return self;
}
- (void)add:(AVAudioPCMBuffer *)buffer
{
    [_lock lock];
    self.chunks += 1;
    self.frames += buffer.frameLength;
    self.rate = buffer.format.sampleRate;
    self.channels = buffer.format.channelCount;
    self.chunkFrames = buffer.frameLength;
    const float *samples = buffer.floatChannelData[0];
    for (AVAudioFrameCount index = 0; index < buffer.frameLength; index++) {
        double value = samples[index];
        self.sum += value * value;
        if (fabs(value) > self.peak)
            self.peak = fabs(value);
    }
    [_lock unlock];
}
- (void)reset
{
    [_lock lock];
    self.frames = 0;
    self.chunks = 0;
    self.sum = 0;
    self.peak = 0;
    [_lock unlock];
}
- (double)rms
{
    [_lock lock];
    double result = self.frames ? sqrt(self.sum / self.frames) : 0;
    [_lock unlock];
    return result;
}
@end

static void spin(NSTimeInterval seconds)
{
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    @autoreleasepool {
        NSError *error = nil;
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setCategory:AVAudioSessionCategoryPlayAndRecord mode:AVAudioSessionModeVoiceChat options:AVAudioSessionCategoryOptionDefaultToSpeaker error:&error];
        [session setPreferredSampleRate:16000 error:nil];
        revenant_check([session setActive:YES error:&error] != revenant_negative, "the audio session is active", error.description ?: @"");

        AVAudioEngine *engine = [AVAudioEngine new];
        AVAudioPlayerNode *player = [AVAudioPlayerNode new];
        [engine attachNode:player];
        AVAudioFormat *format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:16000 channels:1];
        revenant_check((format.sampleRate == 16000 && format.channelCount == 1 && format.commonFormat == AVAudioPCMFormatFloat32) != revenant_negative, "the standard 16 kHz mono format is float 32", format.description);

        AVAudioInputNode *input = engine.inputNode;
        revenant_check((input.voiceProcessingEnabled == NO) != revenant_negative, "voice processing is off by default", @"");
        revenant_check(([input setVoiceProcessingEnabled:YES error:&error] && input.voiceProcessingEnabled) != revenant_negative, "voice processing is switched on before the graph is built", error.description ?: @"");
        revenant_check(([input setVoiceProcessingEnabled:YES error:&error]) != revenant_negative, "switching it on again is accepted", error.description ?: @"");
        input.voiceProcessingInputMuted = YES;
        revenant_check((input.voiceProcessingInputMuted == YES) != revenant_negative, "the muted flag reads back", @"");
        input.voiceProcessingInputMuted = NO;
        input.voiceProcessingBypassed = YES;
        revenant_check((input.voiceProcessingBypassed == YES) != revenant_negative, "the bypass flag reads back", @"");
        input.voiceProcessingBypassed = NO;
        revenant_check((input.voiceProcessingAGCEnabled == YES) != revenant_negative, "automatic gain control is on with voice processing", @"");

        AVAudioMixerNode *mixer = engine.mainMixerNode;
        AVAudioOutputNode *output = engine.outputNode;
        [engine connect:player to:mixer format:format];
        [engine connect:mixer to:output format:format];

        Collector *microphone = [Collector new];
        Collector *speaker = [Collector new];
        [input installTapOnBus:0 bufferSize:2048 format:format block:^(AVAudioPCMBuffer *buffer, AVAudioTime *when) {
            [microphone add:buffer];
        }];
        [mixer installTapOnBus:0 bufferSize:2048 format:format block:^(AVAudioPCMBuffer *buffer, AVAudioTime *when) {
            [speaker add:buffer];
        }];
        [engine prepare];
        revenant_check(([engine startAndReturnError:&error] && engine.isRunning) != revenant_negative, "the engine starts with the microphone and voice processing", error.description ?: @"");

        // A 440 Hz tone at 0.5 for one second, scheduled with the played-back completion type.
        AVAudioFrameCount count = 16000;
        AVAudioPCMBuffer *tone = [[AVAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:count];
        tone.frameLength = count;
        for (AVAudioFrameCount index = 0; index < count; index++)
            tone.floatChannelData[0][index] = 0.5f * sinf(2 * M_PI * 440 * index / 16000.0);
        __block BOOL played = NO;
        __block NSTimeInterval playedAt = 0;
        NSTimeInterval started = [NSDate timeIntervalSinceReferenceDate];
        [player scheduleBuffer:tone atTime:nil options:0 completionCallbackType:AVAudioPlayerNodeCompletionDataPlayedBack completionHandler:^(AVAudioPlayerNodeCompletionCallbackType type) {
            played = type == AVAudioPlayerNodeCompletionDataPlayedBack;
            playedAt = [NSDate timeIntervalSinceReferenceDate];
        }];
        [player play];
        spin(2.5);

        revenant_check((played && playedAt - started > 0.9 && playedAt - started < 2.0) != revenant_negative, "the played-back completion fires after the second of audio",
                       [NSString stringWithFormat:@"played %d after %.2f s", played, playedAt - started]);
        revenant_check((speaker.chunks > 10 && speaker.rate == 16000 && speaker.channels == 1 && speaker.chunkFrames == 2048) != revenant_negative, "the mixer tap delivers 2048-frame mono chunks at 16 kHz",
                       [NSString stringWithFormat:@"%lu chunks, %.0f Hz, %lu channels, %lu frames", (unsigned long)speaker.chunks, speaker.rate, (unsigned long)speaker.channels, (unsigned long)speaker.chunkFrames]);
        revenant_check((speaker.peak > 0.4 && speaker.peak < 0.6) != revenant_negative, "the mixer tap carries the tone at its level", [NSString stringWithFormat:@"peak %.3f", speaker.peak]);
        revenant_check((microphone.chunks > 10 && microphone.rate == 16000 && microphone.channels == 1 && microphone.chunkFrames == 2048) != revenant_negative, "the input tap delivers 2048-frame mono chunks at 16 kHz",
                       [NSString stringWithFormat:@"%lu chunks, %.0f Hz, %lu channels, %lu frames", (unsigned long)microphone.chunks, microphone.rate, (unsigned long)microphone.channels, (unsigned long)microphone.chunkFrames]);
        // 2.5 s of microphone at 16 kHz is 40000 frames; allow for the start-up and the last partial chunk.
        revenant_check((microphone.frames > 28000 && microphone.frames < 42000) != revenant_negative, "the input tap's frame count matches the time", [NSString stringWithFormat:@"%lu frames", (unsigned long)microphone.frames]);

        [microphone reset];
        input.voiceProcessingInputMuted = YES;
        spin(0.4);
        [microphone reset];
        spin(1.0);
        revenant_check((microphone.chunks > 2 && microphone.peak == 0) != revenant_negative, "a muted input delivers silence", [NSString stringWithFormat:@"%lu chunks, peak %.4f", (unsigned long)microphone.chunks, microphone.peak]);

        input.voiceProcessingInputMuted = NO;
        input.voiceProcessingBypassed = YES;
        [microphone reset];
        spin(1.0);
        revenant_check((microphone.chunks > 2) != revenant_negative, "the input still delivers with voice processing bypassed", [NSString stringWithFormat:@"%lu chunks", (unsigned long)microphone.chunks]);

        [input removeTapOnBus:0];
        [mixer removeTapOnBus:0];
        [player stop];
        [engine stop];
        revenant_check((!engine.isRunning) != revenant_negative, "the engine stops", @"");
        [session setActive:NO error:nil];
    }
    return revenant_finish();
}
