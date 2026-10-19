#import <AVFoundation/AVFoundation.h>
#include <math.h>
#import "check.h"

// AVAudioConverter over real AudioConverterServices (AudioConverterNew/ConvertComplexBuffer):
// converts a known Float32 tone down to Int16 and back up to Float32, both directions through
// -convertToBuffer:fromBuffer:error: (same sample rate, no codec - AudioConverterConvertComplexBuffer's
// own documented restriction). The error this round trip can introduce is Int16 quantization and
// nothing else, and that error has a known upper bound stated here BEFORE the run, not fitted to
// it afterwards: AVAudioPCMFormatInt16 maps the float range [-1, 1] to the int16 range
// [-32768, 32767], so no sample can be moved by more than one int16 step either converting down or
// back up - 1/32768 = 0.0000305175... per hop, twice for a round trip, so the round trip's own
// bound is 2/32768 = 0.00006103515625. If the measured error exceeds that, the converter is doing
// something other than quantization - resampling, clipping, a wrong format - and the check must
// fail, not the bound move. Measured on an iPhone4,1 (6.1.3): max error 0.0000152587890625, about
// half the bound and almost exactly 1/65536 (half an int16 step) - what round-to-nearest
// quantization predicts for a full-scale sine tone.
//
// The first run of this test failed every conversion with OSStatus -50 (paramErr), the same shape
// of failure AVAudioEngine's own AudioUnitRender/Output-scope-format trap was
// (facts/AVFoundation/AVAudioEngine.md): a freshly allocated AVAudioPCMBuffer already owns real,
// calloc'd sample memory at its full frameCapacity, but its AudioBufferList's mDataByteSize starts
// at 0, mirroring the real class - it tracks frameLength, not capacity, and AudioConverterServices
// reads mDataByteSize as how much room it has to write into. Fixed in AVAudioConverter.m: both
// convert methods claim the output buffer's full intended byte range via -setFrameLength: before
// calling into AudioConverterServices, not after.

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
        charon_check(maxError > 0.0f, "the round trip actually quantized something (not an accidental no-op copy)", nil);
        charon_check(maxError <= kRoundTripBound, "measured error stays within the quantization bound named before the run", nil);

        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures ? 1 : 0;
}
