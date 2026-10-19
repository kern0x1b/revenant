#import <CoreLocation/CoreLocation.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation CLLocationManager (CharonRanging)

- (void)startRangingBeaconsInRegion:(CLBeaconRegion *)region
{
    NSParameterAssert(region != nil);
    __weak CLLocationManager *manager = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        id<CLLocationManagerDelegate> delegate = manager.delegate;
        if ([delegate respondsToSelector:@selector(locationManager:rangingBeaconsDidFailForRegion:withError:)])
            [delegate locationManager:manager rangingBeaconsDidFailForRegion:region
                            withError:[NSError errorWithDomain:kCLErrorDomain code:kCLErrorRangingUnavailable userInfo:nil]];
    });
}

- (void)stopRangingBeaconsInRegion:(CLBeaconRegion *)region
{
    NSParameterAssert(region != nil);
}

@end
