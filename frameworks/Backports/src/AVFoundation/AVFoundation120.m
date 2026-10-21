#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

static const char revenant_prevents_display_sleep_key;

@implementation AVPlayer (RevenantAVFoundationDisplaySleep)

- (BOOL)preventsDisplaySleepDuringVideoPlayback
{
    NSNumber *stored = objc_getAssociatedObject(self, &revenant_prevents_display_sleep_key);
    return stored ? stored.boolValue : YES;
}

- (void)setPreventsDisplaySleepDuringVideoPlayback:(BOOL)preventsDisplaySleepDuringVideoPlayback
{
    objc_setAssociatedObject(self, &revenant_prevents_display_sleep_key,
                             @(preventsDisplaySleepDuringVideoPlayback), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
