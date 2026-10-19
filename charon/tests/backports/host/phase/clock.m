// PHASEEngine's clock, the host's against the port's, in one binary.
//
// The host's answer is the time its own engine reports; the port's is the time the render loop of PHASEEngine15.m
// reports. Both are run through the same script: start, one second, pause, half a second, start again, half a second,
// stop, and an update() on an automatic engine. The checks are the measured behaviour in facts/PHASE/PHASEEngine.md:
//   - a stopped engine's lastRenderTime is nil, and so is a paused engine's and a stopped one's;
//   - a started engine reports its time at 48 kHz, and the time is the elapsed time since the engine last started
//     (a pause does not carry it across, and a resume restarts it);
//   - update() on an automatic engine raises an API Misuse exception.
// The port's clock is a 10 ms timer, so each reading is held to the elapsed time within 100 ms.
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <PHASE/PHASE.h>
#include <stdio.h>
#include <stdlib.h>

static int failures = 0;

static void check(int ok, const char *who, const char *what)
{
    if (!ok) {
        printf("FAIL %s %s\n", who, what);
        failures++;
    }
}

static int near(AVAudioFramePosition sample, AVAudioFramePosition want)
{
    return llabs(sample - want) <= 4800;
}

static void exercise(Class engineClass, const char *who)
{
    NSError *error = nil;
    id engine = [[engineClass alloc] initWithUpdateMode:PHASEUpdateModeAutomatic];
    check([engine renderingState] == PHASERenderingStateStopped && [engine lastRenderTime] == nil, who, "fresh engine: stopped, nil time");

    check([engine startAndReturnError:&error], who, "start");
    AVAudioTime *atStart = [engine lastRenderTime];
    check(atStart != nil && atStart.sampleRate == 48000 && near(atStart.sampleTime, 0), who, "time at start is zero");

    [NSThread sleepForTimeInterval:1.0];
    AVAudioTime *afterSecond = [engine lastRenderTime];
    check(afterSecond != nil && near(afterSecond.sampleTime, 48000), who, "time after one second");

    [engine pause];
    check([engine renderingState] == PHASERenderingStatePaused && [engine lastRenderTime] == nil, who, "paused: nil time");
    [NSThread sleepForTimeInterval:0.5];

    check([engine startAndReturnError:&error], who, "resume");
    [NSThread sleepForTimeInterval:0.5];
    AVAudioTime *afterResume = [engine lastRenderTime];
    check(afterResume != nil && near(afterResume.sampleTime, 24000), who, "time restarts at the resume");

    [engine stop];
    check([engine renderingState] == PHASERenderingStateStopped && [engine lastRenderTime] == nil, who, "stopped: nil time");

    @try {
        [engine update];
        check(0, who, "update on an automatic engine raised nothing");
    } @catch (NSException *exception) {
        check([exception.name isEqualToString:@"API Misuse"], who, "update on an automatic engine raises API Misuse");
    }

    printf("%s start=%lld after1s=%lld resumed=%lld\n", who, (long long)atStart.sampleTime,
           (long long)afterSecond.sampleTime, (long long)afterResume.sampleTime);
}

int main(void)
{
    @autoreleasepool {
        Class hostClass = [PHASEEngine class];
        Class portClass = NSClassFromString(@"charon_host_PHASEEngine");
        if (hostClass == Nil || portClass == Nil) {
            printf("FAIL a class is missing: host %s, port %s\n", hostClass ? "found" : "missing", portClass ? "found" : "missing");
            return 1;
        }
        exercise(hostClass, "host");
        exercise(portClass, "port");
        printf("checks=phase-clock failures=%d\n", failures);
    }
    return failures == 0 ? 0 : 1;
}
