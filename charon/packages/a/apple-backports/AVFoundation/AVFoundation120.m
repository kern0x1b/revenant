#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

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
