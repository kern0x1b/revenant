// probe.m -- VSSpeechSynthesizer on the 6.1.3 image, driven in the guest. VoiceServices is loaded by path and the class is
// looked up by name, as voices/probe.m does. The probe sends the selectors AVSpeechSynthesizer will use and prints
// every delegate callback with its time from the call (guest seconds, the guest's own clock) and the synthesizer's
// isSpeaking flag. The waits are on the callbacks themselves, not on fixed times: the guest runs slower than its clock
// when the host is loaded, so a fixed sleep measures the load. Every line starts with "probe:" so the log can be read.
// The selectors' types are the image's (the inventory and the probe's own dump of class_copyMethodList, reviewed in
// facts/AVFoundation/AVSpeech.md); the delegate's method names are the ones the image calls, measured in run 1.
#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <objc/runtime.h>
#include <objc/message.h>

static NSTimeInterval t0;
static int gEvents;          // every delegate callback, so a wait can see that one arrived
static int gFinishes;        // didFinish callbacks (the phonemes variant, the one the image calls)
static NSTimeInterval gStartedAt;
static NSTimeInterval gFinishedAt;
static id gSynth;

static NSTimeInterval now(void) { return [NSDate timeIntervalSinceReferenceDate] - t0; }

static void line(NSString *text)
{
    printf("probe: %7.3f %s\n", now(), [text UTF8String]);
    fflush(stdout);
}

static void spin(NSTimeInterval seconds)
{
    NSDate *until = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while ([until timeIntervalSinceNow] > 0) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
}

// Spins until cond() holds or the limit (guest seconds) passes; returns whether cond() held.
static BOOL waitUntil(int (^cond)(void), NSTimeInterval limit)
{
    NSDate *until = [NSDate dateWithTimeIntervalSinceNow:limit];
    while (!cond() && [until timeIntervalSinceNow] > 0) {
        spin(0.1);
    }
    return cond();
}

static BOOL speaking(void)
{
    return ((BOOL (*)(id, SEL))objc_msgSend)(gSynth, NSSelectorFromString(@"isSpeaking"));
}

static void sendId(SEL sel, id arg) { ((void (*)(id, SEL, id))objc_msgSend)(gSynth, sel, arg); }
static void sendFloat(SEL sel, float arg) { ((void (*)(id, SEL, float))objc_msgSend)(gSynth, sel, arg); }
static float getFloat(NSString *name) { return ((float (*)(id, SEL))objc_msgSend)(gSynth, NSSelectorFromString(name)); }
static id getId(NSString *name) { return ((id (*)(id, SEL))objc_msgSend)(gSynth, NSSelectorFromString(name)); }

// The delegate. Each method logs its call and counts it. VoiceServices calls the phonemes variant of didFinish (run 1
// printed no call to the three-argument one), so that is the one the port answers.
@interface SpeakDelegate : NSObject
@end

@implementation SpeakDelegate
- (void)speechSynthesizerDidStartSpeaking:(id)s
{
    gEvents++;
    gStartedAt = now();
    line([NSString stringWithFormat:@"didStart isSpeaking=%d", speaking()]);
}
- (void)speechSynthesizerDidPauseSpeaking:(id)s
{
    gEvents++;
    line([NSString stringWithFormat:@"didPause isSpeaking=%d", speaking()]);
}
- (void)speechSynthesizerDidContinueSpeaking:(id)s
{
    gEvents++;
    line([NSString stringWithFormat:@"didContinue isSpeaking=%d", speaking()]);
}
- (void)speechSynthesizer:(id)s willSpeakRangeOfSpeechString:(NSRange)r
{
    gEvents++;
    line([NSString stringWithFormat:@"willSpeakRange %lu+%lu isSpeaking=%d", (unsigned long)r.location,
          (unsigned long)r.length, speaking()]);
}
- (void)speechSynthesizer:(id)s didFinishSpeaking:(BOOL)finished phonemesSpoken:(id)phonemes withError:(id)error
{
    gEvents++;
    gFinishes++;
    gFinishedAt = now();
    line([NSString stringWithFormat:@"didFinish finished=%d error=%@ isSpeaking=%d", finished, error, speaking()]);
}
@end

static SpeakDelegate *gDelegate;

static void newSynth(void)
{
    Class cls = NSClassFromString(@"VSSpeechSynthesizer");
    gSynth = [[cls alloc] init];
    [gSynth performSelector:@selector(setDelegate:) withObject:gDelegate];
    gEvents = 0;
    gFinishes = 0;
    line([NSString stringWithFormat:@"new synthesizer %@", gSynth ? @"ok" : @"nil"]);
}

static NSString *const kLong = @"one two three four five six seven eight nine ten eleven twelve.";

int main(int argc, char **argv)
{
    @autoreleasepool {
        t0 = [NSDate timeIntervalSinceReferenceDate];
        void *voiceServices = dlopen("/System/Library/PrivateFrameworks/VoiceServices.framework/VoiceServices", RTLD_NOW);
        line([NSString stringWithFormat:@"VoiceServices %@", voiceServices ? @"loaded" : [NSString stringWithUTF8String:dlerror()]]);
        gDelegate = [SpeakDelegate new];

        line(@"scenario defaults");
        newSynth();
        line([NSString stringWithFormat:@"rate=%g pitch=%g volume=%g minimumRate=%g maximumRate=%g voice=%@ isSpeaking=%d",
              getFloat(@"rate"), getFloat(@"pitch"), getFloat(@"volume"), getFloat(@"minimumRate"), getFloat(@"maximumRate"),
              getId(@"voice"), speaking()]);

        sendFloat(NSSelectorFromString(@"setVolume:"), 0.3);
        sendFloat(NSSelectorFromString(@"setPitch:"), 1.0);
        line([NSString stringWithFormat:@"readback after setVolume:0.3 setPitch:1.0 volume=%g pitch=%g", getFloat(@"volume"), getFloat(@"pitch")]);
        sendFloat(NSSelectorFromString(@"setVolume:"), 1.0);
        sendFloat(NSSelectorFromString(@"setPitch:"), 0.5);

        line(@"scenario short");
        sendId(NSSelectorFromString(@"startSpeakingString:"), @"Hi there.");
        line([NSString stringWithFormat:@"after start isSpeaking=%d", speaking()]);
        waitUntil(^{ return gFinishes > 0; }, 240);
        line([NSString stringWithFormat:@"after finish isSpeaking=%d", speaking()]);

        line(@"scenario rate durations: min, default, max, on the same sentence");
        float rates[3] = { getFloat(@"minimumRate"), getFloat(@"rate"), getFloat(@"maximumRate") };
        for (int r = 0; r < 3; r++) {
            newSynth();
            sendFloat(NSSelectorFromString(@"setRate:"), rates[r]);
            line([NSString stringWithFormat:@"rate set %g reads %g", rates[r], getFloat(@"rate")]);
            sendId(NSSelectorFromString(@"startSpeakingString:"), @"Hi there, this is the test.");
            waitUntil(^{ return gFinishes > 0; }, 240);
            line([NSString stringWithFormat:@"rate %g: start to finish %.3f guest s", rates[r], gFinishedAt - gStartedAt]);
        }

        // stop: three forms. The boundary is an int; synchronously: is the image's second argument.
        for (int v = 0; v < 3; v++) {
            line([NSString stringWithFormat:@"scenario stop form %d", v]);
            newSynth();
            sendId(NSSelectorFromString(@"startSpeakingString:"), kLong);
            waitUntil(^{ return gEvents >= 3; }, 120);
            line([NSString stringWithFormat:@"before stop isSpeaking=%d events=%d", speaking(), gEvents]);
            id ret = nil;
            if (v == 0) ret = ((id (*)(id, SEL, int))objc_msgSend)(gSynth, NSSelectorFromString(@"stopSpeakingAtNextBoundary:"), 0);
            if (v == 1) ret = ((id (*)(id, SEL, int))objc_msgSend)(gSynth, NSSelectorFromString(@"stopSpeakingAtNextBoundary:"), 1);
            if (v == 2) ret = ((id (*)(id, SEL, int, BOOL))objc_msgSend)(gSynth, NSSelectorFromString(@"stopSpeakingAtNextBoundary:synchronously:"), 0, YES);
            line([NSString stringWithFormat:@"stop returned %@ isSpeaking=%d events=%d", ret, speaking(), gEvents]);
            waitUntil(^{ return gFinishes > 0; }, 120);
            line([NSString stringWithFormat:@"after stop finishes=%d isSpeaking=%d", gFinishes, speaking()]);
        }

        for (int v = 0; v < 3; v++) {
            line([NSString stringWithFormat:@"scenario pause form %d", v]);
            newSynth();
            sendId(NSSelectorFromString(@"startSpeakingString:"), kLong);
            waitUntil(^{ return gEvents >= 3; }, 120);
            int before = gEvents;
            if (v == 0) ((id (*)(id, SEL, int))objc_msgSend)(gSynth, NSSelectorFromString(@"pauseSpeakingAtNextBoundary:"), 0);
            if (v == 1) ((id (*)(id, SEL, int, BOOL))objc_msgSend)(gSynth, NSSelectorFromString(@"pauseSpeakingAtNextBoundary:synchronously:"), 0, YES);
            if (v == 2) ((id (*)(id, SEL, int))objc_msgSend)(gSynth, NSSelectorFromString(@"pauseSpeakingAtNextBoundary:"), 1);
            line([NSString stringWithFormat:@"pause sent isSpeaking=%d", speaking()]);
            waitUntil(^{ return gEvents > before; }, 60);
            line([NSString stringWithFormat:@"after pause isSpeaking=%d events=%d", speaking(), gEvents]);
            spin(3.0);
            int atContinue = gEvents;
            line([NSString stringWithFormat:@"before continue events=%d", atContinue]);
            ((void (*)(id, SEL))objc_msgSend)(gSynth, NSSelectorFromString(@"continueSpeaking"));
            line([NSString stringWithFormat:@"continue sent isSpeaking=%d", speaking()]);
            waitUntil(^{ return gFinishes > 0; }, 240);
            line([NSString stringWithFormat:@"after finish isSpeaking=%d finishes=%d", speaking(), gFinishes]);
        }

        line(@"scenario queue: second start while the first speaks");
        newSynth();
        sendId(NSSelectorFromString(@"startSpeakingString:"), kLong);
        waitUntil(^{ return gEvents >= 2; }, 120);
        sendId(NSSelectorFromString(@"startSpeakingString:"), @"Second short.");
        line([NSString stringWithFormat:@"after second start isSpeaking=%d", speaking()]);
        waitUntil(^{ return gFinishes >= 2; }, 300);
        line([NSString stringWithFormat:@"after both finishes=%d isSpeaking=%d", gFinishes, speaking()]);

        line(@"scenario stop with a queued second");
        newSynth();
        sendId(NSSelectorFromString(@"startSpeakingString:"), kLong);
        sendId(NSSelectorFromString(@"startSpeakingString:"), @"Second short.");
        waitUntil(^{ return gEvents >= 2; }, 120);
        ((id (*)(id, SEL, int))objc_msgSend)(gSynth, NSSelectorFromString(@"stopSpeakingAtNextBoundary:"), 0);
        waitUntil(^{ return gFinishes >= 1; }, 120);
        spin(20.0);
        line([NSString stringWithFormat:@"after stop and 20s finishes=%d events=%d isSpeaking=%d", gFinishes, gEvents, speaking()]);

        line(@"scenario voice: read back, an unknown name, a language code");
        newSynth();
        sendId(NSSelectorFromString(@"setVoice:"), @"Thomas");
        line([NSString stringWithFormat:@"voice after setVoice:Thomas = %@", getId(@"voice")]);
        sendId(NSSelectorFromString(@"setVoice:"), @"NoSuchVoice");
        line([NSString stringWithFormat:@"voice after setVoice:NoSuchVoice = %@", getId(@"voice")]);
        sendId(NSSelectorFromString(@"startSpeakingString:"), @"Hi there.");
        waitUntil(^{ return gFinishes > 0; }, 240);
        line([NSString stringWithFormat:@"after unknown voice finishes=%d", gFinishes]);
        newSynth();
        ((id (*)(id, SEL, id, id))objc_msgSend)(gSynth, NSSelectorFromString(@"startSpeakingString:withLanguageCode:"), @"Bonjour.", @"fr-FR");
        waitUntil(^{ return gFinishes > 0; }, 240);
        line([NSString stringWithFormat:@"after language code finishes=%d", gFinishes]);
        newSynth();
        line([NSString stringWithFormat:@"stop when idle returns %@", ((id (*)(id, SEL, int))objc_msgSend)(gSynth, NSSelectorFromString(@"stopSpeakingAtNextBoundary:"), 0)]);
    }
    return 0;
}
