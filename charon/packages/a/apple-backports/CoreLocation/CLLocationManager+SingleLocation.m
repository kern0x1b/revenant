#import <CoreLocation/CoreLocation.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char charon_request_key;
static const NSTimeInterval charon_request_timeout = 10;

typedef void (^CharonLocationCompletion)(CLLocation *location, NSError *error);

@interface CharonLocationRequest : NSObject <CLLocationManagerDelegate>
- (instancetype)initWithManager:(CLLocationManager *)manager completion:(CharonLocationCompletion)completion;
- (void)start;
@end

@implementation CharonLocationRequest {
    CLLocationManager *_manager;
    CLLocationManager *_helper;
    CLLocation *_best;
    NSTimer *_timer;
    CharonLocationCompletion _completion;
}

- (instancetype)initWithManager:(CLLocationManager *)manager completion:(CharonLocationCompletion)completion
{
    if ((self = [super init])) {
        _manager = manager;
        _completion = [completion copy];
    }
    return self;
}

- (void)start
{
    _helper = [[CLLocationManager alloc] init];
    _helper.delegate = self;
    _helper.desiredAccuracy = _manager.desiredAccuracy;
    _helper.distanceFilter = kCLDistanceFilterNone;
    _timer = [NSTimer scheduledTimerWithTimeInterval:charon_request_timeout target:self selector:@selector(timedOut) userInfo:nil repeats:NO];
    [_helper startUpdatingLocation];
}

- (void)finishWithLocation:(CLLocation *)location error:(NSError *)error
{
    if (!_completion)
        return;
    CharonLocationCompletion completion = _completion;
    _completion = nil;
    [_timer invalidate];
    _timer = nil;
    [_helper stopUpdatingLocation];
    _helper.delegate = nil;
    _helper = nil;
    completion(location, error);
}

- (void)timedOut
{
    if (_best)
        [self finishWithLocation:_best error:nil];
    else
        [self finishWithLocation:nil error:[NSError errorWithDomain:kCLErrorDomain code:kCLErrorLocationUnknown userInfo:nil]];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    CLLocation *location = locations.lastObject;
    if (!location || location.horizontalAccuracy < 0)
        return;
    if (!_best || location.horizontalAccuracy <= _best.horizontalAccuracy)
        _best = location;
    if (_helper.desiredAccuracy > 0 && location.horizontalAccuracy <= _helper.desiredAccuracy)
        [self finishWithLocation:location error:nil];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    if ([error.domain isEqualToString:kCLErrorDomain] && error.code == kCLErrorLocationUnknown)
        return;
    [self finishWithLocation:nil error:error];
}

@end

@implementation CLLocationManager (CharonSingleLocation)

- (void)requestLocation
{
    id<CLLocationManagerDelegate> delegate = self.delegate;
    if (![delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
        [[NSAssertionHandler currentHandler] handleFailureInMethod:_cmd object:self file:@"CLLocationManager.m" lineNumber:0
                                                        description:@"Delegate must respond to locationManager:didUpdateLocations:"];
        return;
    }
    if (![delegate respondsToSelector:@selector(locationManager:didFailWithError:)]) {
        [[NSAssertionHandler currentHandler] handleFailureInMethod:_cmd object:self file:@"CLLocationManager.m" lineNumber:0
                                                        description:@"Delegate must respond to locationManager:didFailWithError:"];
        return;
    }
    if (objc_getAssociatedObject(self, &charon_request_key))
        return;
    __weak CLLocationManager *manager = self;
    CharonLocationRequest *request = [[CharonLocationRequest alloc] initWithManager:self completion:^(CLLocation *location, NSError *error) {
        objc_setAssociatedObject(manager, &charon_request_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        id<CLLocationManagerDelegate> current = manager.delegate;
        if (location)
            [current locationManager:manager didUpdateLocations:@[location]];
        else if ([current respondsToSelector:@selector(locationManager:didFailWithError:)])
            [current locationManager:manager didFailWithError:error];
    }];
    objc_setAssociatedObject(self, &charon_request_key, request, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [request start];
}

- (void)requestStateForRegion:(CLRegion *)region
{
    NSParameterAssert(region != nil);
    __weak CLLocationManager *manager = self;
    Class beacons = NSClassFromString(@"CLBeaconRegion");
    void (^deliver)(CLRegionState) = ^(CLRegionState state) {
        id<CLLocationManagerDelegate> current = manager.delegate;
        if ([current respondsToSelector:@selector(locationManager:didDetermineState:forRegion:)])
            [current locationManager:manager didDetermineState:state forRegion:region];
    };
    if (beacons && [region isKindOfClass:beacons]) {
        dispatch_async(dispatch_get_main_queue(), ^{ deliver(CLRegionStateUnknown); });
        return;
    }
    CharonLocationRequest *request = [[CharonLocationRequest alloc] initWithManager:self completion:^(CLLocation *location, NSError *error) {
        if (location)
            deliver([region containsCoordinate:location.coordinate] ? CLRegionStateInside : CLRegionStateOutside);
        else
            deliver(CLRegionStateUnknown);
    }];
    [request start];
}

@end
