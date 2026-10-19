#import <CoreLocation/CoreLocation.h>
#import <objc/runtime.h>

static const char revenant_notify_entry_key;
static const char revenant_notify_exit_key;

static BOOL revenant_notify_flag(id region, const void *key)
{
    NSNumber *kept = objc_getAssociatedObject(region, key);
    return kept ? kept.boolValue : YES;
}

@implementation CLRegion (RevenantNotify)

- (BOOL)notifyOnEntry
{
    return revenant_notify_flag(self, &revenant_notify_entry_key);
}

- (void)setNotifyOnEntry:(BOOL)notifyOnEntry
{
    if (!notifyOnEntry) {
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            NSLog(@"CLRegion.notifyOnEntry is kept and not applied on iOS 6: the manager tells its delegate of every entry into a monitored region");
        });
    }
    objc_setAssociatedObject(self, &revenant_notify_entry_key, @(notifyOnEntry), OBJC_ASSOCIATION_RETAIN);
}

- (BOOL)notifyOnExit
{
    return revenant_notify_flag(self, &revenant_notify_exit_key);
}

- (void)setNotifyOnExit:(BOOL)notifyOnExit
{
    if (!notifyOnExit) {
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            NSLog(@"CLRegion.notifyOnExit is kept and not applied on iOS 6: the manager tells its delegate of every exit from a monitored region");
        });
    }
    objc_setAssociatedObject(self, &revenant_notify_exit_key, @(notifyOnExit), OBJC_ASSOCIATION_RETAIN);
}

@end
