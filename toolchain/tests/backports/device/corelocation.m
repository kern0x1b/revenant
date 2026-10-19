#import <CoreLocation/CoreLocation.h>
#include <dlfcn.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "check.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

static NSString *image_of(Class cls)
{
    Dl_info info;
    return dladdr((__bridge const void *)cls, &info) ? @(info.dli_fname).lastPathComponent : @"?";
}

static void check_regions(void)
{
    CLLocationCoordinate2D center = {37.33, -122.03}, far = {40, -100};
    Class circular = NSClassFromString(@"CLCircularRegion");
    CHECK(circular != Nil, "CLCircularRegion exists");
    CHECK_EQUAL(image_of(circular), @"libCoreLocationBackports.dylib", "CLCircularRegion comes from the backports");
    CLCircularRegion *region = [[CLCircularRegion alloc] initWithCenter:center radius:250 identifier:@"own"];
    CHECK([region isKindOfClass:[CLRegion class]], "a circular region is a region");
    CHECK_EQUAL(NSStringFromClass([region class]), @"CLCircularRegion", "the class of a circular region");
    CHECK(region.radius == 250, "the radius");
    CHECK(region.center.latitude == 37.33 && region.center.longitude == -122.03, "the centre");
    CHECK_EQUAL(region.identifier, @"own", "the identifier");
    CHECK([region containsCoordinate:center], "it contains its centre");
    CHECK(![region containsCoordinate:far], "it does not contain a far coordinate");
    CHECK_EQUAL(NSStringFromClass([[region copy] class]), @"CLCircularRegion", "a copy is a circular region again");
    CHECK(region.notifyOnEntry && region.notifyOnExit, "both notify flags start YES");
    region.notifyOnEntry = NO;
    CHECK(!region.notifyOnEntry && region.notifyOnExit, "notifyOnEntry answers what was set and leaves the exit flag alone");
    region.notifyOnExit = NO;
    CHECK(!region.notifyOnEntry && !region.notifyOnExit, "notifyOnExit answers what was set");
    CLRegion *plain = [[CLRegion alloc] initCircularRegionWithCenter:center radius:100 identifier:@"plain"];
    CHECK_EQUAL(NSStringFromClass([plain class]), @"CLRegion", "a region of the release keeps its own class");
    CHECK(plain.radius == 100 && [plain containsCoordinate:center] && ![plain containsCoordinate:far], "a region of the release answers as before");
    CHECK(plain.notifyOnEntry && plain.notifyOnExit, "a region of the release gets the notify flags too, YES to start");
}

static void check_availability(void)
{
    Class circular = NSClassFromString(@"CLCircularRegion");
    BOOL monitoring = [CLLocationManager regionMonitoringAvailable];
    CHECK([CLLocationManager isMonitoringAvailableForClass:circular] == monitoring, "circular monitoring is the release's region monitoring");
    CHECK([CLLocationManager isMonitoringAvailableForClass:[CLRegion class]] == monitoring, "plain region monitoring is the release's region monitoring");
    CHECK(![CLLocationManager isMonitoringAvailableForClass:[NSString class]], "a class that is no region is not monitorable");
    Class none = Nil;
    CHECK(![CLLocationManager isMonitoringAvailableForClass:none], "no class is not monitorable");
    CHECK(![CLLocationManager isRangingAvailable], "ranging is not available");
    CLLocationManager *manager = [[CLLocationManager alloc] init];
    CHECK([manager.rangedRegions isKindOfClass:[NSSet class]] && manager.rangedRegions.count == 0, "no region is ranged");
}

@interface CharonLocationProbe : NSObject <CLLocationManagerDelegate>
@property (nonatomic) int updates, failures, states;
@property (nonatomic) NSInteger lastErrorCode;
@property (nonatomic, copy) NSString *lastErrorDomain;
@property (nonatomic) CLRegionState lastState;
@property (nonatomic) NSUInteger lastCount;
@property (nonatomic) int ranging;
@property (nonatomic, strong) CLBeaconRegion *rangingRegion;
@end

@implementation CharonLocationProbe
- (void)locationManager:(CLLocationManager *)manager rangingBeaconsDidFailForRegion:(CLBeaconRegion *)region withError:(NSError *)error
{
    self.ranging++;
    self.rangingRegion = region;
    self.lastErrorCode = error.code;
    self.lastErrorDomain = error.domain;
}
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    self.updates++;
    self.lastCount = locations.count;
}
- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    self.failures++;
    self.lastErrorCode = error.code;
    self.lastErrorDomain = error.domain;
}
- (void)locationManager:(CLLocationManager *)manager didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region
{
    self.states++;
    self.lastState = state;
}
@end

@interface CharonSilentDelegate : NSObject <CLLocationManagerDelegate>
@end

@implementation CharonSilentDelegate
@end

static void spin_until(BOOL (^done)(void), NSTimeInterval seconds)
{
    NSDate *limit = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while (!done() && [limit timeIntervalSinceNow] > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
}

static NSString *raised(void (^block)(void))
{
    @try {
        block();
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
    }
    return @"nothing";
}

static void check_single_location(void)
{
    CLLocationManager *bare = [[CLLocationManager alloc] init];
    CharonSilentDelegate *silent = [[CharonSilentDelegate alloc] init];
    bare.delegate = silent;
    NSString *without = raised(^{ [bare requestLocation]; });
    CHECK([without hasPrefix:@"NSInternalInconsistencyException"] && [without containsString:@"locationManager:didUpdateLocations:"],
          "a delegate that cannot take a location is refused");
    CharonLocationProbe *probe = [[CharonLocationProbe alloc] init];
    CLLocationManager *manager = [[CLLocationManager alloc] init];
    manager.delegate = probe;
    manager.desiredAccuracy = kCLLocationAccuracyKilometer;
    [manager requestLocation];
    [manager requestLocation];
    spin_until(^BOOL { return probe.updates + probe.failures > 0; }, 25);
    spin_until(^BOOL { return NO; }, 1);
    CHECK(probe.updates + probe.failures == 1, "a request made while one is outstanding is not a second one");
    if (probe.updates)
        CHECK(probe.lastCount == 1, "a location request delivers one location");
    else
        CHECK([probe.lastErrorDomain isEqualToString:kCLErrorDomain], "a location request that fails fails in the location error domain");
    printf("info requestLocation: updates %d failures %d code %ld domain %s\n", probe.updates, probe.failures,
           (long)probe.lastErrorCode, probe.lastErrorDomain.UTF8String ?: "-");
}

static void check_region_state(void)
{
    CLLocationCoordinate2D center = {37.33, -122.03};
    CLRegion *region = [[CLRegion alloc] initCircularRegionWithCenter:center radius:100 identifier:@"state"];
    CharonLocationProbe *probe = [[CharonLocationProbe alloc] init];
    CLLocationManager *manager = [[CLLocationManager alloc] init];
    manager.delegate = probe;
    manager.desiredAccuracy = kCLLocationAccuracyKilometer;
    CLRegion *none = nil;
    CHECK([raised(^{ [manager requestStateForRegion:none]; }) hasPrefix:@"NSInternalInconsistencyException"], "no region is refused");
    [manager requestStateForRegion:region];
    spin_until(^BOOL { return probe.states > 0; }, 25);
    spin_until(^BOOL { return NO; }, 1);
    CHECK(probe.states == 1, "a region state is answered once");
    CHECK(probe.lastState == CLRegionStateUnknown || probe.lastState == CLRegionStateInside || probe.lastState == CLRegionStateOutside,
          "the state is one of the three");
    printf("info requestStateForRegion: states %d state %ld\n", probe.states, (long)probe.lastState);
}

static void check_beacons(void)
{
    Class regions = NSClassFromString(@"CLBeaconRegion"), beacons = NSClassFromString(@"CLBeacon");
    CHECK(regions != Nil && beacons != Nil, "the beacon classes exist");
    CHECK_EQUAL(image_of(regions), @"libCoreLocationBackports.dylib", "CLBeaconRegion comes from the backports");
    CHECK_EQUAL(image_of(beacons), @"libCoreLocationBackports.dylib", "CLBeacon comes from the backports");
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:@"E2C56DB5-DFFB-48D2-B060-D0F5A71096E0"];
    CLBeaconRegion *whole = [[CLBeaconRegion alloc] initWithProximityUUID:uuid identifier:@"whole"];
    CLBeaconRegion *majored = [[CLBeaconRegion alloc] initWithProximityUUID:uuid major:513 identifier:@"majored"];
    CLBeaconRegion *exact = [[CLBeaconRegion alloc] initWithProximityUUID:uuid major:513 minor:258 identifier:@"exact"];
    CHECK([whole isKindOfClass:[CLRegion class]] && [exact isKindOfClass:[CLRegion class]], "a beacon region is a region");
    CHECK_EQUAL(whole.proximityUUID, uuid, "the proximity UUID");
    CHECK(whole.major == nil && whole.minor == nil, "a region of a UUID has no major and no minor");
    CHECK([majored.major isEqual:@513] && majored.minor == nil, "a region of a major has no minor");
    CHECK([exact.major isEqual:@513] && [exact.minor isEqual:@258], "the major and the minor");
    CHECK_EQUAL(exact.identifier, @"exact", "the identifier");
    CHECK(!exact.notifyEntryStateOnDisplay, "the entry state on display starts NO");
    exact.notifyEntryStateOnDisplay = YES;
    CHECK(exact.notifyEntryStateOnDisplay, "the entry state on display answers what was set");
    CHECK(exact.notifyOnEntry && exact.notifyOnExit, "a beacon region notifies on entry and exit to start");
    NSUUID *noUUID = nil;
    NSString *raisedNil = raised(^{ [[CLBeaconRegion alloc] initWithProximityUUID:noUUID identifier:@"none"]; });
    CHECK([raisedNil hasPrefix:@"NSInvalidArgumentException"], "a beacon region needs a UUID");
    NSMutableDictionary *data = [exact peripheralDataWithMeasuredPower:@(-70)];
    NSData *bytes = data[@"kCBAdvDataAppleBeaconKey"];
    const unsigned char expected[] = {0xE2, 0xC5, 0x6D, 0xB5, 0xDF, 0xFB, 0x48, 0xD2, 0xB0, 0x60, 0xD0, 0xF5, 0xA7, 0x10, 0x96, 0xE0,
                                      0x02, 0x01, 0x01, 0x02, 0xBA};
    CHECK(data.count == 1 && bytes.length == sizeof expected && memcmp(bytes.bytes, expected, sizeof expected) == 0,
          "the advertisement is the UUID, the major and the minor big endian and the measured power");
    NSData *defaulted = [whole peripheralDataWithMeasuredPower:nil][@"kCBAdvDataAppleBeaconKey"];
    CHECK(defaulted.length == 21 && ((const signed char *)defaulted.bytes)[20] == -59 && ((const unsigned char *)defaulted.bytes)[17] == 0,
          "with no measured power the advertisement carries -59, and an absent major and minor are zero");
    CLBeacon *beacon = [[CLBeacon alloc] init];
    CHECK(beacon.proximity == CLProximityUnknown && beacon.accuracy == -1 && beacon.rssi == 0 && beacon.proximityUUID == nil,
          "a beacon with nothing ranged is unknown, of no accuracy and no signal");
    CHECK([[beacon copy] isKindOfClass:beacons], "a beacon copies");
    CharonLocationProbe *probe = [[CharonLocationProbe alloc] init];
    CLLocationManager *manager = [[CLLocationManager alloc] init];
    manager.delegate = probe;
    CHECK(![CLLocationManager isMonitoringAvailableForClass:regions], "a beacon region cannot be monitored");
    [manager startRangingBeaconsInRegion:exact];
    spin_until(^BOOL { return probe.ranging > 0; }, 10);
    spin_until(^BOOL { return NO; }, 1);
    CHECK(probe.ranging == 1 && probe.rangingRegion == exact, "ranging is refused once, for the region asked");
    CHECK([probe.lastErrorDomain isEqualToString:kCLErrorDomain] && probe.lastErrorCode == kCLErrorRangingUnavailable,
          "ranging is refused as unavailable");
    CHECK([raised(^{ [manager stopRangingBeaconsInRegion:exact]; }) isEqualToString:@"nothing"], "stopping ranging raises nothing");
    CLBeaconRegion *missing = nil;
    CHECK([raised(^{ [manager startRangingBeaconsInRegion:missing]; }) hasPrefix:@"NSInternalInconsistencyException"], "no region is refused");
    CHECK(manager.rangedRegions.count == 0, "no region is ranged");
    CLRegionState state = 99;
    CharonLocationProbe *statePart = [[CharonLocationProbe alloc] init];
    manager.delegate = statePart;
    [manager requestStateForRegion:exact];
    spin_until(^BOOL { return statePart.states > 0; }, 5);
    state = statePart.lastState;
    CHECK(state == CLRegionStateUnknown, "the state of a beacon region is unknown");
}

static void check_floor_and_visits(void)
{
    Class floors = NSClassFromString(@"CLFloor"), visits = NSClassFromString(@"CLVisit");
    CHECK(floors != Nil && visits != Nil, "the floor and visit classes exist");
    CHECK_EQUAL(image_of(floors), @"libCoreLocationBackports.dylib", "CLFloor comes from the backports");
    CHECK_EQUAL(image_of(visits), @"libCoreLocationBackports.dylib", "CLVisit comes from the backports");
    CLLocation *location = [[CLLocation alloc] initWithLatitude:37.33 longitude:-122.03];
    CHECK([location floor] == nil, "a location has no floor");
    CLVisit *visit = [[CLVisit alloc] init];
    CHECK([visit.arrivalDate isEqual:[NSDate distantPast]] && [visit.departureDate isEqual:[NSDate distantFuture]],
          "a visit with nothing known has no arrival and no departure");
    CHECK(visit.horizontalAccuracy == -1, "a visit with nothing known has no accuracy");
    CLVisit *copy = [visit copy];
    CHECK([copy isKindOfClass:visits] && [copy.arrivalDate isEqual:visit.arrivalDate], "a visit copies");
    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:visit];
    CLVisit *decoded = [NSKeyedUnarchiver unarchiveObjectWithData:archive];
    CHECK([decoded isKindOfClass:visits] && [decoded.departureDate isEqual:visit.departureDate], "a visit survives archiving");
    CharonLocationProbe *probe = [[CharonLocationProbe alloc] init];
    CLLocationManager *manager = [[CLLocationManager alloc] init];
    manager.delegate = probe;
    CHECK([raised(^{ [manager startMonitoringVisits]; [manager stopMonitoringVisits]; }) isEqualToString:@"nothing"],
          "visit monitoring is accepted");
    spin_until(^BOOL { return NO; }, 1);
    CHECK(probe.updates == 0 && probe.failures == 0, "nothing is delivered for a visit");
}

static void check_geocoder_and_background(void)
{
    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    CHECK([geocoder respondsToSelector:@selector(geocodeAddressString:inRegion:preferredLocale:completionHandler:)] &&
          [geocoder respondsToSelector:@selector(reverseGeocodeLocation:preferredLocale:completionHandler:)], "the geocoder takes a preferred locale");
    CHECK(![geocoder respondsToSelector:NSSelectorFromString(@"geocodePostalAddress:completionHandler:")], "a postal address is not geocoded");
    CLPlacemark *placemark = ((id (*)(id, SEL))objc_msgSend)([CLPlacemark alloc], sel_registerName("init"));
    CHECK([placemark timeZone] == nil, "a placemark has no time zone");
    CHECK(![placemark respondsToSelector:NSSelectorFromString(@"postalAddress")], "a placemark has no postal address");
    CLLocationManager *manager = [[CLLocationManager alloc] init];
    CHECK(!manager.allowsBackgroundLocationUpdates && !manager.showsBackgroundLocationIndicator, "the background switches start NO");
    manager.allowsBackgroundLocationUpdates = YES;
    manager.showsBackgroundLocationIndicator = YES;
    CHECK(manager.allowsBackgroundLocationUpdates && manager.showsBackgroundLocationIndicator, "the background switches answer what was set");
    manager.allowsBackgroundLocationUpdates = NO;
    CHECK(!manager.allowsBackgroundLocationUpdates && manager.showsBackgroundLocationIndicator, "each background switch is its own");
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        check_regions();
        check_availability();
        check_single_location();
        check_region_state();
        check_beacons();
        check_floor_and_visits();
        check_geocoder_and_background();
        printf("%d checks, %d failed\n", charon_checks, charon_failures);
    }
    return charon_failures;
}
