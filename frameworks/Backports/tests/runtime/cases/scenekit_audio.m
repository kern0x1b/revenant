#import "../app/revenant_check.h"
#import "../../SceneKit/wave_file.h"
#import <AudioToolbox/AudioToolbox.h>
#import <OpenAL/al.h>
#include <stdio.h>
#include <unistd.h>
#import <OpenAL/al.h>
#import <OpenAL/alc.h>
#import <QuartzCore/QuartzCore.h>
#import "../../../src/SceneKit/RevenantSCNAudio.h"
#import "../../../src/SceneKit/RevenantSCNSoundEngine.h"

static BOOL revenant_finishes(SCNAudioPlayer *player, NSTimeInterval within)
{
    __block BOOL finished = NO;
    player.didFinishPlayback = ^{
        finished = YES;
    };
    CFTimeInterval started = CACurrentMediaTime();
    CFTimeInterval nextReport = started + 0.5;
    while (!finished && CACurrentMediaTime() - started < within) {
        [player revenantUpdateWithWorld:SCNMatrix4Identity time:CACurrentMediaTime()];
        if (CACurrentMediaTime() >= nextReport) {
            ALint state = 0, offset = 0;
            ALuint handle = [player revenantSource];
            if (handle) {
                alGetSourcei(handle, AL_SOURCE_STATE, &state);
                alGetSourcei(handle, AL_SAMPLE_OFFSET, &offset);
            }
            printf("REVENANT-PROBE finish-poll at=%.2f state=%d offset=%d\n", CACurrentMediaTime() - started, state, offset);
            nextReport += 0.5;
        }
        usleep(10000);
    }
    printf("REVENANT-PROBE finish guest=%.3f finished=%d\n", CACurrentMediaTime() - started, finished);
    return finished;
}

REVENANT_CASE(scenekit_audio)
{
    NSString *tonePath = @"/var/revenant/scenekit_audio_tone.wav";
    NSString *streamPath = @"/var/revenant/scenekit_audio_stream.wav";

    BOOL prepared = NO;
    @try {
        [RevenantSCNSoundEngine prepare];
        prepared = YES;
    } @catch (NSException *exception) {
        printf("REVENANT-PROBE prepare raised %s: %s\n", [exception.name UTF8String], [exception.reason UTF8String]);
    }
    revenant_expect_true(@"OpenAL opens an output device on iOS 6.1.3", prepared != (BOOL)negative, @"prepare raised");

    ALCdevice *device = alcGetContextsDevice(alcGetCurrentContext());
    BOOL asa = device && alcIsExtensionPresent(device, "ALC_EXT_ASA");
    printf("REVENANT-PROBE ALC_EXT_ASA present=%d\n", asa);
    revenant_expect_true(@"ALC_EXT_ASA is present on iOS 6.1.3", asa != (BOOL)negative, @"the extension is absent");
    printf("REVENANT-PROBE alcASASetListener=%p alcASASetSource=%p alcASAGetSource=%p\n",
           [RevenantSCNSoundEngine procedureNamed:"alcASASetListener"],
           [RevenantSCNSoundEngine procedureNamed:"alcASASetSource"],
           [RevenantSCNSoundEngine procedureNamed:"alcASAGetSource"]);
    revenant_expect_true(@"the ASA reverb send procedure resolves", ([RevenantSCNSoundEngine procedureNamed:"alcASASetSource"] != NULL) != (BOOL)negative,
                         @"alcGetProcAddress returned NULL");
    revenant_expect_true(@"the reverb path is available", [RevenantSCNSoundEngine supportsReverb] != (BOOL)negative, @"no reverb path");

    NSURL *tone = revenant_write_tone(tonePath, 2.0, 440);
    double rate = 0;
    unsigned long long frames = 0;
    NSData *pcm = [RevenantSCNSoundEngine decodeURL:tone channels:1 sampleRate:&rate frames:&frames];
    printf("REVENANT-PROBE decoded frames=%llu rate=%g bytes=%lu\n", frames, rate, (unsigned long)pcm.length);
    revenant_expect_true(@"ExtAudioFile decodes the tone at its rate",
                         (pcm != nil && frames == 16000 && rate == 8000) != (BOOL)negative, @"the decode is wrong");

    SCNAudioSource *source = [[SCNAudioSource alloc] initWithURL:tone];
    source.positional = NO;
    SCNAudioPlayer *player = [SCNAudioPlayer audioPlayerWithSource:source];
    BOOL started = NO;
    @try {
        [player revenantStartOnNode:nil];
        started = [player revenantIsPlaying];
    } @catch (NSException *exception) {
        printf("REVENANT-PROBE start raised %s: %s\n", [exception.name UTF8String], [exception.reason UTF8String]);
    }
    revenant_expect_true(@"a source starts playing on iOS 6.1.3", started != (BOOL)negative, @"the source is not playing");
    BOOL finished = revenant_finishes(player, 3.0);
    printf("REVENANT-PROBE tone finished on its own=%d\n", finished);
    revenant_expect_true(@"a 2 second tone finishes on its own", finished != (BOOL)negative, @"the tone did not finish");

    NSURL *streamed = revenant_write_tone(streamPath, 2.0, 440);
    SCNAudioSource *stream = [[SCNAudioSource alloc] initWithURL:streamed];
    stream.positional = NO;
    stream.shouldStream = YES;
    SCNAudioPlayer *streaming = [SCNAudioPlayer audioPlayerWithSource:stream];
    BOOL streamStarted = NO;
    @try {
        [streaming revenantStartOnNode:nil];
        streamStarted = [streaming revenantIsPlaying];
    } @catch (NSException *exception) {
        printf("REVENANT-PROBE stream start raised %s: %s\n", [exception.name UTF8String], [exception.reason UTF8String]);
    }
    revenant_expect_true(@"a streamed source starts playing on iOS 6.1.3", streamStarted != (BOOL)negative, @"the stream is not playing");
    BOOL streamFinished = revenant_finishes(streaming, 3.0);
    printf("REVENANT-PROBE stream finished on its own=%d\n", streamFinished);
    revenant_expect_true(@"a streamed 2 second tone finishes on its own", streamFinished != (BOOL)negative, @"the stream did not finish");

    SCNAudioSource *reverbed = [[SCNAudioSource alloc] initWithURL:tone];
    reverbed.positional = NO;
    reverbed.reverbBlend = 0.5;
    BOOL reverbStarted = NO;
    @try {
        SCNAudioPlayer *reverbPlayer = [SCNAudioPlayer audioPlayerWithSource:reverbed];
        [reverbPlayer revenantStartOnNode:nil];
        reverbStarted = [reverbPlayer revenantIsPlaying];
        [reverbPlayer revenantStop];
    } @catch (NSException *exception) {
        printf("REVENANT-PROBE reverb start raised %s: %s\n", [exception.name UTF8String], [exception.reason UTF8String]);
    }
    revenant_expect_true(@"a source with reverb starts on iOS 6.1.3", reverbStarted != (BOOL)negative, @"the reverb source did not start");

    [[NSFileManager defaultManager] removeItemAtPath:tonePath error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:streamPath error:NULL];
}
