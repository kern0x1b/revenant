#import <AVFoundation/AVFoundation.h>
#include <math.h>
#import "check.h"

static const AVAudioFrameCount kFrames = 512;
static const float kSampleRate = 44100.0f;
static const float kRoundTripBound = 2.0f / 32768.0f;

int main(void)
{
    @autoreleasepool {
        AVAudioFormat *floatFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32 sampleRate:kSampleRate channels:1 interleaved:NO];
        AVAudioFormat *int16Format = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16 sampleRate:kSampleRate channels:1 interleaved:NO];

        AVAudioConverter *down = [[AVAudioConverter alloc] initFromFormat:floatFormat toFormat:int16Format];
        CHECK(down != nil, "AVAudioConverter Float32->Int16 constructs");
        AVAudioConverter *up = [[AVAudioConverter alloc] initFromFormat:int16Format toFormat:floatFormat];
        CHECK(up != nil, "AVAudioConverter Int16->Float32 constructs");

        AVAudioPCMBuffer *source = [[AVAudioPCMBuffer alloc] initWithPCMFormat:floatFormat frameCapacity:kFrames];
        float *const *sourceChannels = [source floatChannelData];
        for (AVAudioFrameCount i = 0; i < kFrames; i++)
            sourceChannels[0][i] = sinf(2.0f * (float)M_PI * 440.0f * (float)i / kSampleRate) * 0.9f;
        [source setFrameLength:kFrames];

        AVAudioPCMBuffer *quantized = [[AVAudioPCMBuffer alloc] initWithPCMFormat:int16Format frameCapacity:kFrames];
        NSError *error = nil;
        BOOL downOK = [down convertToBuffer:quantized fromBuffer:source error:&error];
        CHECK(downOK, "Float32 -> Int16 conversion succeeds");
        CHECK([quantized frameLength] == kFrames, "Int16 buffer receives every frame");

        AVAudioPCMBuffer *roundTripped = [[AVAudioPCMBuffer alloc] initWithPCMFormat:floatFormat frameCapacity:kFrames];
        BOOL upOK = [up convertToBuffer:roundTripped fromBuffer:quantized error:&error];
        CHECK(upOK, "Int16 -> Float32 conversion succeeds");
        CHECK([roundTripped frameLength] == kFrames, "Float32 buffer receives every frame back");

        float *const *roundTrippedChannels = [roundTripped floatChannelData];
        float maxError = 0;
        for (AVAudioFrameCount i = 0; i < kFrames; i++) {
            float delta = fabsf(roundTrippedChannels[0][i] - sourceChannels[0][i]);
            if (delta > maxError)
                maxError = delta;
        }
        printf("round-trip bound named in advance: %.8f\n", kRoundTripBound);
        printf("measured max |round-tripped - source|: %.8f\n", maxError);
        revenant_check(maxError > 0.0f, "the round trip actually quantized something (not an accidental no-op copy)", nil);
        revenant_check(maxError <= kRoundTripBound, "measured error stays within the quantization bound named before the run", nil);

        printf("checks=%d failures=%d\n", revenant_checks, revenant_failures);
    }
    return revenant_failures ? 1 : 0;
}
