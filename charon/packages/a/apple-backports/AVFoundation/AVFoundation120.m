#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

// iOS 12's AVFoundation on 6.1.3: one row of the 16 that this slice carries, and it is stored rather
// than applied. The other 15 are absent with the measurement in each row - see
// facts/AVFoundation/AVFoundation120.md.
//
// AVPlayer.preventsDisplaySleepDuringVideoPlayback selects whether the player's playback keeps the
// screen awake. 6.1.3's AVPlayer carries 140 own instance methods and 19 own class methods and no
// sleep member of any kind: its playback vocabulary is -rate, -setRate:, -play, -pause, -currentItem
// and the external-playback pair, and none of them touches the idle timer. The port therefore stores
// and returns the value, and the row is inert for that reason and not because the call is missing.
//
// The default is AVPlayer.h:860's: YES on iOS, so a player nobody has set answers YES.

static const char charon_prevents_display_sleep_key;

@implementation AVPlayer (CharonAVFoundationDisplaySleep)

- (BOOL)preventsDisplaySleepDuringVideoPlayback
{
    NSNumber *stored = objc_getAssociatedObject(self, &charon_prevents_display_sleep_key);
    return stored ? stored.boolValue : YES;
}

- (void)setPreventsDisplaySleepDuringVideoPlayback:(BOOL)preventsDisplaySleepDuringVideoPlayback
{
    objc_setAssociatedObject(self, &charon_prevents_display_sleep_key,
                             @(preventsDisplaySleepDuringVideoPlayback), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end