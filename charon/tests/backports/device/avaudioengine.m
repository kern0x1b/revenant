#import <AVFoundation/AVFoundation.h>
#include <dlfcn.h>
#include <objc/message.h>
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
