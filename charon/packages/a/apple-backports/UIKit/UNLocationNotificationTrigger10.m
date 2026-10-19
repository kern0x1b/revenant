#import "CharonUserNotifications.h"
#import "../CharonSayOnce.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// A trigger that fires when the device enters or leaves a region, which the SDK's own declaration of
// UNLocationNotificationTrigger gives in its first sentence, and which CoreLocation has been able to
// watch since iPhone OS 4.0: -[CLLocationManager startMonitoringForRegion:] and the two delegate
// callbacks are in every held rung from 4.0 on, and so is the initializer of the circular region that
// a release before 7.0 can construct, CLCircularRegion having arrived with 7.0. A request carrying
// this trigger therefore has no date to schedule: it is a region to monitor, and the notification is
// presented when CoreLocation says the device crossed its edge.

// A request under monitor: the trigger says which region and whether it fires again, the request says
// what to present. Two requests may share a region and a third region may carry two, so they are
// counted per region identifier rather than one region per request.
@interface CharonMonitoredRequest : NSObject {
@public
    UNLocationNotificationTrigger *_trigger;
    UNNotificationRequest *_request;
}
@end

@implementation CharonMonitoredRequest
@end

@implementation CharonRegionMonitor

+ (CharonRegionMonitor *)charon_sharedMonitor
{
    static CharonRegionMonitor *monitor;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        monitor = [[CharonRegionMonitor alloc] init];
    });
    return monitor;
}

- (instancetype)init
{
    if ((self = [super init]))
        _byRegion = [NSMutableDictionary dictionary];
    return self;
}

- (CLLocationManager *)charon_manager
{
    if (!_manager) {
        _manager = [[CLLocationManager alloc] init];
        _manager.delegate = self;
    }
    return _manager;
}

- (void)charon_forget:(NSString *)identifier
{
    for (NSString *name in [_byRegion.allKeys copy]) {
        NSMutableArray *kept = _byRegion[name];
        for (CharonMonitoredRequest *watched in [kept copy])
            if ([watched->_request.identifier isEqualToString:identifier])
                [kept removeObject:watched];
        if (!kept.count)
            [self charon_stopRegionNamed:name];
    }
}

- (void)charon_stopRegionNamed:(NSString *)name
{
    [_byRegion removeObjectForKey:name];
    for (CLRegion *region in _manager.monitoredRegions)
        if ([region.identifier isEqualToString:name]) {
            [_manager stopMonitoringForRegion:region];
            break;
        }
}

- (NSError *)charon_monitorRequest:(UNNotificationRequest *)request
{
    UNLocationNotificationTrigger *trigger = (UNLocationNotificationTrigger *)request.trigger;
    CLRegion *region = trigger.region;
    if (!region.identifier.length)
        return charon_unsupported(@"a region needs an identifier of its own, since the identifier is what CoreLocation reports a crossing under");
    __block NSError *refusal = nil;
    charon_on_main(^{
        if (![CLLocationManager regionMonitoringAvailable])
            refusal = charon_unsupported([NSString stringWithFormat:@"iOS %@ cannot watch a region on this device, so a request whose trigger is one is not scheduled",
                                                                      [UIDevice currentDevice].systemVersion]);
        else {
            // A second request under one identifier replaces the first, whichever region each of them
            // named, as it does for a trigger with a date.
            [self charon_forget:request.identifier];
            NSMutableArray *kept = _byRegion[region.identifier];
            if (!kept) {
                kept = [NSMutableArray array];
                _byRegion[region.identifier] = kept;
                [_manager startMonitoringForRegion:region];
            }
            CharonMonitoredRequest *watched = [[CharonMonitoredRequest alloc] init];
            watched->_trigger = trigger;
            watched->_request = request;
            [kept addObject:watched];
        }
    });
    return refusal;
}

- (NSArray<UNNotificationRequest *> *)charon_requests
{
    NSMutableArray *requests = [NSMutableArray array];
    charon_on_main(^{
        for (NSMutableArray *kept in self->_byRegion.allValues)
            for (CharonMonitoredRequest *watched in kept)
                [requests addObject:watched->_request];
    });
    return requests;
}

- (void)charon_removeRequestsWithIdentifiers:(NSSet<NSString *> *)identifiers
{
    charon_on_main(^{
        for (NSString *name in [self->_byRegion.allKeys copy]) {
            NSMutableArray *kept = self->_byRegion[name];
            for (CharonMonitoredRequest *watched in [kept copy])
                if (!identifiers || [identifiers containsObject:watched->_request.identifier])
                    [kept removeObject:watched];
            if (!kept.count)
                [self charon_stopRegionNamed:name];
        }
    });
}

- (void)charon_fire:(CharonMonitoredRequest *)watched
{
    UNNotificationRequest *request = watched->_request;
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    // The same path a request with no trigger takes, so the notification is shown by iOS 6 itself and
    // the centre's delegate hears of it as it hears of any other.
    [[UIApplication sharedApplication] presentLocalNotificationNow:[center charon_localNotificationForRequest:request]];
    // iOS 10 fires a trigger that does not repeat once and forgets it; the release's monitoring does
    // not forget a region, so the request is dropped here or the next crossing would show it again.
    if (!watched->_trigger.repeats)
        [self charon_removeRequestsWithIdentifiers:[NSSet setWithObject:request.identifier]];
}

- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region
{
    // The bucket is keyed by the region's identifier, so everything in it is a request under this
    // region and nothing has to be matched again.
    charon_on_main(^{
        for (CharonMonitoredRequest *watched in [self->_byRegion[region.identifier] copy])
            [self charon_fire:watched];
    });
}

- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region
{
    // The bucket is keyed by the region's identifier, so everything in it is a request under this
    // region and nothing has to be matched again.
    charon_on_main(^{
        for (CharonMonitoredRequest *watched in [self->_byRegion[region.identifier] copy])
            [self charon_fire:watched];
    });
}

- (void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region withError:(NSError *)error
{
    charon_say_once_for(@"region", [NSString stringWithFormat:@"UNLocationNotificationTrigger: iOS %@ could not watch the region %@ (%@), so the request under it is not fired and stays pending",
                                          [UIDevice currentDevice].systemVersion, region.identifier, error.localizedDescription]);
}

@end

@implementation UNLocationNotificationTrigger {
@private
    CLRegion *_region;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (instancetype)triggerWithRegion:(CLRegion *)region repeats:(BOOL)repeats
{
    NSAssert(region != nil, @"region cannot be nil");
    return [[self alloc] initCharonWithRegion:region repeats:repeats];
}

- (instancetype)initCharonWithRegion:(CLRegion *)region repeats:(BOOL)repeats
{
    if ((self = [super initCharonWithRepeats:repeats]))
        _region = [region copy];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder]))
        _region = [coder decodeObjectForKey:@"region"];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:_region forKey:@"region"];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (CLRegion *)region
{
    return _region;
}

- (BOOL)isEqual:(id)object
{
    return [super isEqual:object] && [_region isEqual:((UNLocationNotificationTrigger *)object).region];
}

- (NSUInteger)hash
{
    return [super hash] ^ _region.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; region: %@, repeats: %@>", [self class], self, _region,
                                      self.repeats ? @"YES" : @"NO"];
}

@end