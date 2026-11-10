#import "../RevenantVibration.h"
#import <AudioToolbox/AudioToolbox.h>
#include <dlfcn.h>
#include <stdint.h>

static void *revenant_coremedia_symbol(const char *name)
{
    static void *handle;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        handle = dlopen("/System/Library/Frameworks/CoreMedia.framework/CoreMedia", RTLD_LAZY);
    });
    return handle ? dlsym(handle, name) : NULL;
}

static void *revenant_audiotoolbox_symbol(const char *name)
{
    static void *handle;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        handle = dlopen("/System/Library/Frameworks/AudioToolbox.framework/AudioToolbox", RTLD_LAZY);
    });
    return handle ? dlsym(handle, name) : NULL;
}

BOOL RevenantVibratorIsAvailable(void)
{
    static BOOL available;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        int (*query)(void) = revenant_coremedia_symbol("FigVibratorIsVibratorAvailable");
        available = query && query() != 0;
    });
    return available;
}

void RevenantVibratorPlay(float intensity, const int *milliseconds, NSUInteger count)
{
    static void (*play)(uint32_t, id, NSDictionary *);
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        play = revenant_audiotoolbox_symbol("AudioServicesPlaySystemSoundWithVibration");
    });
    if (!play || !RevenantVibratorIsAvailable() || !milliseconds || count == 0)
        return;
    NSMutableArray *pattern = [NSMutableArray arrayWithCapacity:count * 2];
    for (NSUInteger index = 0; index < count; index++) {
        [pattern addObject:(index % 2 == 0 ? (__bridge id)kCFBooleanTrue : (__bridge id)kCFBooleanFalse)];
        [pattern addObject:@(milliseconds[index])];
    }
    play(kSystemSoundID_Vibrate, nil, @{ @"VibePattern": pattern, @"Intensity": @(MIN(1.0f, MAX(0.0f, intensity))) });
}

void RevenantVibratorPulse(void)
{
    if (RevenantVibratorIsAvailable())
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
}

void RevenantVibratorStop(void)
{
    void (*stop)(void) = revenant_coremedia_symbol("FigVibratorStop");
    if (stop)
        stop();
}
