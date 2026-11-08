#import <CoreLocation/CoreLocation.h>
#import <objc/runtime.h>

@implementation CLLocationManager (RevenantAuthorizationStatus)

- (CLAuthorizationStatus)authorizationStatus
{
    Class kind = object_getClass(self);
    return [kind authorizationStatus];
}

- (CLAccuracyAuthorization)accuracyAuthorization
{
    return CLAccuracyAuthorizationFullAccuracy;
}

@end
