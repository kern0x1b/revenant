#import "RevenantUserNotifications.h"
#import "../RevenantSayOnce.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface RevenantMonitoredRequest : NSObject {
@public
    UNLocationNotificationTrigger *_trigger;
    UNNotificationRequest *_request;
}
@end

@implementation RevenantMonitoredRequest
@end

@implementation RevenantRegionMonitor

+ (RevenantRegionMonitor *)revenant_sharedMonitor
{
    static RevenantRegionMonitor *monitor;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        monitor = [[RevenantRegionMonitor alloc] init];
    });
    return monitor;
}

- (instancetype)init
{
    if ((self = [super init]))
        _byRegion = [NSMutableDictionary dictionary];
    return self;
}

- (CLLocationManager *)revenant_manager
{
    if (!_manager) {
        _manager = [[CLLocationManager alloc] init];
        _manager.delegate = self;
    }
    return _manager;
}

- (void)revenant_forget:(NSString *)identifier
{
    for (NSString *name in [_byRegion.allKeys copy]) {
        NSMutableArray *kept = _byRegion[name];
        for (RevenantMonitoredRequest *watched in [kept copy])
            if ([watched->_request.identifier isEqualToString:identifier])
                [kept removeObject:watched];
        if (!kept.count)
            [self revenant_stopRegionNamed:name];
    }
}

- (void)revenant_stopRegionNamed:(NSString *)name
{
    [_byRegion removeObjectForKey:name];
    for (CLRegion *region in _manager.monitoredRegions)
        if ([region.identifier isEqualToString:name]) {
            [_manager stopMonitoringForRegion:region];
            break;
        }
}

- (NSError *)revenant_monitorRequest:(UNNotificationRequest *)request
{
    UNLocationNotificationTrigger *trigger = (UNLocationNotificationTrigger *)request.trigger;
    CLRegion *region = trigger.region;
    if (!region.identifier.length)
        return revenant_unsupported(@"a region needs an identifier of its own, since the identifier is what CoreLocation reports a crossing under");
    __block NSError *refusal = nil;
    revenant_on_main(^{
        if (![CLLocationManager regionMonitoringAvailable])
            refusal = revenant_unsupported([NSString stringWithFormat:@"iOS %@ cannot watch a region on this device, so a request whose trigger is one is not scheduled",
                                                                      [UIDevice currentDevice].systemVersion]);
        else {
            [self revenant_forget:request.identifier];
            NSMutableArray *kept = _byRegion[region.identifier];
            if (!kept) {
                kept = [NSMutableArray array];
                _byRegion[region.identifier] = kept;
                [_manager startMonitoringForRegion:region];
            }
            RevenantMonitoredRequest *watched = [[RevenantMonitoredRequest alloc] init];
            watched->_trigger = trigger;
            watched->_request = request;
            [kept addObject:watched];
        }
    });
    return refusal;
}

- (NSArray<UNNotificationRequest *> *)revenant_requests
{
    NSMutableArray *requests = [NSMutableArray array];
    revenant_on_main(^{
        for (NSMutableArray *kept in self->_byRegion.allValues)
            for (RevenantMonitoredRequest *watched in kept)
                [requests addObject:watched->_request];
    });
    return requests;
}

- (void)revenant_removeRequestsWithIdentifiers:(NSSet<NSString *> *)identifiers
{
    revenant_on_main(^{
        for (NSString *name in [self->_byRegion.allKeys copy]) {
            NSMutableArray *kept = self->_byRegion[name];
            for (RevenantMonitoredRequest *watched in [kept copy])
                if (!identifiers || [identifiers containsObject:watched->_request.identifier])
                    [kept removeObject:watched];
            if (!kept.count)
                [self revenant_stopRegionNamed:name];
        }
    });
}

- (void)revenant_fire:(RevenantMonitoredRequest *)watched
{
    UNNotificationRequest *request = watched->_request;
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [[UIApplication sharedApplication] presentLocalNotificationNow:[center revenant_localNotificationForRequest:request]];
    if (!watched->_trigger.repeats)
        [self revenant_removeRequestsWithIdentifiers:[NSSet setWithObject:request.identifier]];
}

- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region
{
    revenant_on_main(^{
        for (RevenantMonitoredRequest *watched in [self->_byRegion[region.identifier] copy])
            [self revenant_fire:watched];
    });
}

- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region
{
    revenant_on_main(^{
        for (RevenantMonitoredRequest *watched in [self->_byRegion[region.identifier] copy])
            [self revenant_fire:watched];
    });
}

- (void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region withError:(NSError *)error
{
    revenant_say_once_for(@"region", [NSString stringWithFormat:@"UNLocationNotificationTrigger: iOS %@ could not watch the region %@ (%@), so the request under it is not fired and stays pending",
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
    return [[self alloc] initRevenantWithRegion:region repeats:repeats];
}

- (instancetype)initRevenantWithRegion:(CLRegion *)region repeats:(BOOL)repeats
{
    if ((self = [super initRevenantWithRepeats:repeats]))
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
