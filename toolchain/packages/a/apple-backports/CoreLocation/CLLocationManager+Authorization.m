#import <CoreLocation/CoreLocation.h>
#import <objc/runtime.h>

@interface RevenantLocationAuthorization : NSObject <CLLocationManagerDelegate>
@end

static const CLLocationAccuracy revenant_authorization_accuracy = 3000;

static CLLocationManager *revenant_authorization_manager;
static id<CLLocationManagerDelegate> revenant_authorization_delegate;

static void revenant_request_authorization(CLLocationManager *manager)
{
    Class kind = object_getClass(manager);
    if (![kind locationServicesEnabled] || [kind authorizationStatus] != kCLAuthorizationStatusNotDetermined)
        return;
    if (revenant_authorization_manager)
        return;
    revenant_authorization_manager = [[kind alloc] init];
    revenant_authorization_delegate = [[RevenantLocationAuthorization alloc] init];
    revenant_authorization_manager.delegate = revenant_authorization_delegate;
    revenant_authorization_manager.desiredAccuracy = revenant_authorization_accuracy;
    [revenant_authorization_manager startUpdatingLocation];
}

@implementation RevenantLocationAuthorization

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    if (status == kCLAuthorizationStatusNotDetermined)
        return;
    [revenant_authorization_manager stopUpdatingLocation];
    revenant_authorization_manager.delegate = nil;
    revenant_authorization_manager = nil;
    revenant_authorization_delegate = nil;
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    [revenant_authorization_manager stopUpdatingLocation];
}

@end

@implementation CLLocationManager (RevenantAuthorization)

- (void)requestWhenInUseAuthorization
{
    revenant_request_authorization(self);
}

- (void)requestAlwaysAuthorization
{
    revenant_request_authorization(self);
}

@end
