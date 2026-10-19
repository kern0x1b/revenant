#import <AVFoundation/AVFoundation.h>
#include <dlfcn.h>
#include <objc/message.h>
#include <math.h>
#import "check.h"

static void setForcedOfflineOutput(BOOL offline)
{
    Class cls = NSClassFromString(@"CharonAudioEngineTestSupport");
    SEL sel = NSSelectorFromString(@"setForcedOfflineOutput:");
    ((void (*)(Class, SEL, BOOL))objc_msgSend)(cls, sel, offline);
}

static OSStatus pullOutput(AudioBufferList *ioData, AVAudioFrameCount frames, AVAudioEngine *engine)
{
    Class cls = NSClassFromString(@"CharonAudioEngineTestSupport");
    SEL sel = NSSelectorFromString(@"pullOutput:frames:fromEngine:");
    return ((OSStatus (*)(Class, SEL, AudioBufferList *, AVAudioFrameCount, AVAudioEngine *))objc_msgSend)(cls, sel, ioData, frames, engine);
}

static const AVAudioFrameCount kFrames = 512;
static const float kSampleRate = 44100.0f;

static float *runGraph(void (^configure)(AVAudioUnitEQ *eq), float *sourceOut)
{
    setForcedOfflineOutput(YES);
    AVAudioEngine *engine = [[AVAudioEngine alloc] init];
    AVAudioFormat *format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:kSampleRate channels:1];

    AVAudioPlayerNode *player = [[AVAudioPlayerNode alloc] init];
    AVAudioUnitEQ *eq = [[AVAudioUnitEQ alloc] initWithNumberOfBands:2];
    [engine attachNode:player];
    [engine attachNode:eq];
    [engine connect:player to:eq format:format];
    [engine connect:eq to:[engine mainMixerNode] format:format];

    configure(eq);

    NSError *error = nil;
    BOOL started = [engine startAndReturnError:&error];
    CHECK(started, "engine with an attached AVAudioUnitEQ starts");

    AVAudioPCMBuffer *source = [[AVAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:kFrames];
    float *const *sourceChannels = [source floatChannelData];
    for (AVAudioFrameCount i = 0; i < kFrames; i++)
        sourceChannels[0][i] = sinf(2.0f * (float)M_PI * 2000.0f * (float)i / kSampleRate) * 0.5f;
    [source setFrameLength:kFrames];
    if (sourceOut)
        memcpy(sourceOut, sourceChannels[0], kFrames * sizeof(float));

    [player scheduleBuffer:source completionHandler:nil];
    [player play];

    AudioBufferList *pulled = calloc(1, sizeof(AudioBufferList));
    pulled->mNumberBuffers = 1;
    pulled->mBuffers[0].mNumberChannels = 1;
    pulled->mBuffers[0].mDataByteSize = kFrames * sizeof(float);
    pulled->mBuffers[0].mData = calloc(1, kFrames * sizeof(float));

    OSStatus status = pullOutput(pulled, kFrames, engine);
    CHECK(status == noErr, "AudioUnitRender through player->EQ->mixer->(offline)output returns noErr");

    float *result = malloc(kFrames * sizeof(float));
    memcpy(result, pulled->mBuffers[0].mData, kFrames * sizeof(float));
    free(pulled->mBuffers[0].mData);
    free(pulled);
    [engine stop];
    return result;
}

static float rms(const float *samples, AVAudioFrameCount count)
{
    double sum = 0;
    for (AVAudioFrameCount i = 0; i < count; i++)
        sum += (double)samples[i] * (double)samples[i];
    return sqrtf((float)(sum / count));
}

int main(void)
{
    @autoreleasepool {
        CHECK(NSStringFromClass([AVAudioUnitEQ class]) != nil, "AVAudioUnitEQ class resolves");

        float source[kFrames];

        float *zeroGainOutput = runGraph(^(AVAudioUnitEQ *eq) {
            eq.bands[0].filterType = AVAudioUnitEQFilterTypeParametric;
            eq.bands[0].gain = 0;
            eq.bands[0].frequency = 2000;
            eq.bands[0].bandwidth = 1.0;
            eq.bands[0].bypass = NO;
            CHECK(!eq.bands[0].bypass, "band 0 reports un-bypassed");
        }, source);

        float maxZeroGainDelta = 0;
        for (AVAudioFrameCount i = 0; i < kFrames; i++) {
            float delta = fabsf(zeroGainOutput[i] - source[i]);
            if (delta > maxZeroGainDelta)
                maxZeroGainDelta = delta;
        }
        printf("max |output - source| with an active 0 dB band: %.6f\n", maxZeroGainDelta);
        charon_check(maxZeroGainDelta < 0.01f,
                     "a 0 dB active band matches the input closely (near-identity, not a rubber stamp on non-zero output)", nil);

        float *filteredOutput = runGraph(^(AVAudioUnitEQ *eq) {
            eq.bands[0].filterType = AVAudioUnitEQFilterTypeParametric;
            eq.bands[0].gain = 0;
            eq.bands[0].frequency = 2000;
            eq.bands[0].bandwidth = 1.0;
            eq.bands[0].bypass = NO;
            eq.bands[1].filterType = AVAudioUnitEQFilterTypeLowPass;
            eq.bands[1].frequency = 150;
            eq.bands[1].bypass = NO;
            CHECK(!eq.bands[1].bypass, "band 1 reports un-bypassed");
        }, source);

        float sourceRMS = rms(source, kFrames);
        float zeroGainRMS = rms(zeroGainOutput, kFrames);
        float filteredRMS = rms(filteredOutput, kFrames);
        printf("RMS: source=%.6f zero-gain-band=%.6f 150Hz-lowpass-on-2kHz-tone=%.6f\n", sourceRMS, zeroGainRMS, filteredRMS);

        charon_check(filteredRMS < zeroGainRMS * 0.5f,
                     "a real low-pass band well below the test tone measurably and predictably attenuates it (not silence, not unchanged)", nil);

        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures ? 1 : 0;
}
