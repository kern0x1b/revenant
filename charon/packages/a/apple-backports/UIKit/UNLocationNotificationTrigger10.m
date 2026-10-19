#import "CharonUserNotifications.h"
#import "../CharonSayOnce.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

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
    [[UIApplication sharedApplication] presentLocalNotificationNow:[center charon_localNotificationForRequest:request]];
    if (!watched->_trigger.repeats)
        [self charon_removeRequestsWithIdentifiers:[NSSet setWithObject:request.identifier]];
}

- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region
{
    charon_on_main(^{
        for (CharonMonitoredRequest *watched in [self->_byRegion[region.identifier] copy])
            [self charon_fire:watched];
    });
}

- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region
{
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
