#import <CoreLocation/CoreLocation.h>

@implementation CLLocationManager (CharonVisits)

- (void)startMonitoringVisits
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSLog(@"CLLocationManager.startMonitoringVisits does nothing on iOS 6: the release does not detect visits, so the delegate is never sent locationManager:didVisit:");
    });
}

- (void)stopMonitoringVisits
{
}

@end
