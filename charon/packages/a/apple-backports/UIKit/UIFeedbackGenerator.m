#import "CharonFeedbackGenerator.h"
#include <dlfcn.h>

enum { CharonVibrateSoundID = 0x00000FFF };

static void *charon_symbol(const char *library, const char *name)
{
    void *handle = dlopen(library, RTLD_LAZY);
    return handle ? dlsym(handle, name) : NULL;
}

BOOL charon_feedback_motor_present(void)
{
    static BOOL present;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        int (*available)(void) = charon_symbol("/System/Library/Frameworks/CoreMedia.framework/CoreMedia",
                                               "FigVibratorIsVibratorAvailable");
        present = available && available() != 0;
    });
    return present;
}

void charon_feedback_play(float intensity, const int *milliseconds, NSUInteger count)
{
    static void (*play)(UInt32, id, NSDictionary *);
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        play = charon_symbol("/System/Library/Frameworks/AudioToolbox.framework/AudioToolbox",
                             "AudioServicesPlaySystemSoundWithVibration");
    });
    if (!play || !charon_feedback_motor_present() || count == 0)
        return;
    NSMutableArray *pattern = [NSMutableArray arrayWithCapacity:count * 2];
    for (NSUInteger index = 0; index < count; index++) {
        [pattern addObject:(index % 2 == 0 ? (__bridge id)kCFBooleanTrue : (__bridge id)kCFBooleanFalse)];
        [pattern addObject:@(milliseconds[index])];
    }
    play(CharonVibrateSoundID, nil, @{ @"VibePattern": pattern, @"Intensity": @(intensity) });
}

@implementation UIFeedbackGenerator

- (void)prepare
{
}

- (void)_charonPlayIntensity:(float)intensity milliseconds:(const int *)milliseconds count:(NSUInteger)count
{
    charon_feedback_play(intensity, milliseconds, count);
}

@end
