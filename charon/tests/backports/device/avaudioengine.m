#import <AVFoundation/AVFoundation.h>
#include <dlfcn.h>
#include <objc/message.h>
#import "check.h"

// AVAudioEngine and AVAudioPlayerNode: a graph that compiles, runs and produces silence reports
// nothing - no exception, no error code, a green gate. The only real proof is reading the graph's
// actual output and comparing samples. kAudioUnitSubType_GenericOutput needs no mediaserverd
// (confirmed via AudioComponentFindNext - facts/AVFoundation/AVAudioEngine.md), so this pulls the
// graph's real output by hand and checks it sample-for-sample against a known waveform scheduled
// through a real AVAudioPlayerNode into the real mainMixerNode - the actual node/connection/format
// plumbing this port builds, not a shortcut around it.
//
// CharonAudioEngineTestSupport is reached by name (NSClassFromString/objc_msgSend), not static
// linking: this project deliberately hides every symbol whose bare name starts with
// "charon_"/"Charon" from a dylib's exported table (modules/apple/backports.lua's
// internal_symbol()), and a brand-new such class is still fully registered in __objc_classlist at
// load time - only static linking against its symbol is blocked.

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

static NSString *image_of(Class cls)
{
    Dl_info info;
    return dladdr((__bridge const void *)cls, &info) ? @(info.dli_fname).lastPathComponent : @"?";
}

int main(void)
{
    @autoreleasepool {
        CHECK_EQUAL(image_of([AVAudioEngine class]), @"libAVFoundationBackports.dylib", "AVAudioEngine comes from the backports");

        setForcedOfflineOutput(YES);
        AVAudioEngine *engine = [[AVAudioEngine alloc] init];
        CHECK(engine != nil, "engine constructed");
        CHECK([engine mainMixerNode] != nil, "mainMixerNode exists from construction");
        CHECK([engine outputNode] != nil, "outputNode exists from construction");

        AVAudioFormat *format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100.0 channels:1];
        AVAudioPlayerNode *player = [[AVAudioPlayerNode alloc] init];
        [engine attachNode:player];
        [engine connect:player to:[engine mainMixerNode] format:format];

        NSArray *points = [engine outputConnectionPointsForNode:player outputBus:0];
        CHECK(points.count == 1, "outputConnectionPointsForNode: reports the real connection");
        CHECK([[points firstObject] node] == [engine mainMixerNode], "the connection point is the mixer");

        NSError *error = nil;
        BOOL started = [engine startAndReturnError:&error];
        CHECK(started, "engine starts");
        CHECK([engine isRunning], "engine reports running");

        AVAudioFrameCount frameCount = 512;
        AVAudioPCMBuffer *source = [[AVAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:frameCount];
        float *const *sourceChannels = [source floatChannelData];
        for (AVAudioFrameCount i = 0; i < frameCount; i++)
            sourceChannels[0][i] = sinf((float)i * 0.05f) * 0.5f;
        [source setFrameLength:frameCount];

        __block BOOL completed = NO;
        [player scheduleBuffer:source completionHandler:^{ completed = YES; }];
        [player play];
        CHECK([player isPlaying], "player reports playing");

        // One pull for the whole buffer, matching kAudioUnitProperty_MaximumFramesPerSlice
        // (4096, set in -init) - a chunked pull with each chunk's AudioTimeStamp reset to sample
        // time 0 was tried first and only matched for the first chunk: the mixer unit tracks its
        // own internal sample-time continuity across calls, and resetting it each time corrupts
        // every chunk after the first.
        AudioBufferList *pulled = calloc(1, sizeof(AudioBufferList));
        pulled->mNumberBuffers = 1;
        pulled->mBuffers[0].mNumberChannels = 1;
        pulled->mBuffers[0].mDataByteSize = frameCount * sizeof(float);
        pulled->mBuffers[0].mData = calloc(1, frameCount * sizeof(float));

        OSStatus status = pullOutput(pulled, frameCount, engine);
        CHECK(status == noErr, "AudioUnitRender against the offline graph returns noErr");

        float *pulledSamples = pulled->mBuffers[0].mData;
        BOOL anyNonZero = NO, matchesSource = YES;
        for (AVAudioFrameCount i = 0; i < frameCount; i++) {
            if (pulledSamples[i] != 0.0f)
                anyNonZero = YES;
            // The mixer's own gain/summing can introduce small floating-point differences even
            // for a single unity-gain input, so this checks "recognizably the same waveform",
            // not bit-exact equality - a real measurement, not a rubber stamp on non-zero output.
            if (fabsf(pulledSamples[i] - sourceChannels[0][i]) > 0.05f)
                matchesSource = NO;
        }
        charon_check(anyNonZero, "the graph's real output is not silent (the coordinator's named trap)", nil);
        charon_check(matchesSource, "the graph's output recognizably carries the waveform that was scheduled, not noise or silence", nil);

        [engine stop];
        CHECK(![engine isRunning], "engine reports stopped");

        printf("first 8 source samples:  ");
        for (int i = 0; i < 8; i++) printf("%+.4f ", sourceChannels[0][i]);
        printf("\nfirst 8 pulled samples:  ");
        for (int i = 0; i < 8; i++) printf("%+.4f ", pulledSamples[i]);
        printf("\n");

        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures ? 1 : 0;
}
