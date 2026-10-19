#import <CoreLocation/CoreLocation.h>
#import <objc/runtime.h>

static const char charon_background_updates_key;
static const char charon_background_indicator_key;

@implementation CLLocationManager (CharonBackground)

- (BOOL)allowsBackgroundLocationUpdates
{
    return [objc_getAssociatedObject(self, &charon_background_updates_key) boolValue];
}

- (void)setAllowsBackgroundLocationUpdates:(BOOL)allowsBackgroundLocationUpdates
{
    if (allowsBackgroundLocationUpdates) {
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            NSLog(@"CLLocationManager.allowsBackgroundLocationUpdates is kept and not applied on iOS 6: location in the background follows the location entry of UIBackgroundModes in the application's property list");
        });
    }
    objc_setAssociatedObject(self, &charon_background_updates_key, @(allowsBackgroundLocationUpdates), OBJC_ASSOCIATION_RETAIN);
}

- (BOOL)showsBackgroundLocationIndicator
{
    return [objc_getAssociatedObject(self, &charon_background_indicator_key) boolValue];
}

- (void)setShowsBackgroundLocationIndicator:(BOOL)showsBackgroundLocationIndicator
{
    if (showsBackgroundLocationIndicator) {
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            NSLog(@"CLLocationManager.showsBackgroundLocationIndicator is kept and not applied on iOS 6: the status bar shows the location arrow whenever location is in use, and has no bar of its own for the background");
        });
    }
    objc_setAssociatedObject(self, &charon_background_indicator_key, @(showsBackgroundLocationIndicator), OBJC_ASSOCIATION_RETAIN);
}

@end
