#import <CoreLocation/CoreLocation.h>
#import <objc/runtime.h>

@interface CharonLocationAuthorization : NSObject <CLLocationManagerDelegate>
@end

static const CLLocationAccuracy charon_authorization_accuracy = 3000;

static CLLocationManager *charon_authorization_manager;
static id<CLLocationManagerDelegate> charon_authorization_delegate;

static void charon_request_authorization(CLLocationManager *manager)
{
    Class kind = object_getClass(manager);
    if (![kind locationServicesEnabled] || [kind authorizationStatus] != kCLAuthorizationStatusNotDetermined)
        return;
    if (charon_authorization_manager)
        return;
    charon_authorization_manager = [[kind alloc] init];
    charon_authorization_delegate = [[CharonLocationAuthorization alloc] init];
    charon_authorization_manager.delegate = charon_authorization_delegate;
    charon_authorization_manager.desiredAccuracy = charon_authorization_accuracy;
    [charon_authorization_manager startUpdatingLocation];
}

@implementation CharonLocationAuthorization

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    if (status == kCLAuthorizationStatusNotDetermined)
        return;
    [charon_authorization_manager stopUpdatingLocation];
    charon_authorization_manager.delegate = nil;
    charon_authorization_manager = nil;
    charon_authorization_delegate = nil;
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    [charon_authorization_manager stopUpdatingLocation];
}

@end

@implementation CLLocationManager (CharonAuthorization)

- (void)requestWhenInUseAuthorization
{
    charon_request_authorization(self);
}

- (void)requestAlwaysAuthorization
{
    charon_request_authorization(self);
}

@end
