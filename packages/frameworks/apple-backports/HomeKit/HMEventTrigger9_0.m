#import "RevenantHomeKitInternal.h"

#pragma mark - HMEvent

@implementation HMEvent

@synthesize revenant_identifier = _revenant_identifier;

- (NSUUID *)uniqueIdentifier
{
    return RevenantHomeKitUUID(_revenant_identifier);
}

@end

HMEvent *RevenantHomeKitEvent(NSString *identifier, NSString *kind)
{
    HMEvent *event = nil;
    if ([kind isEqualToString:@"characteristic"])
        event = [[HMCharacteristicEvent alloc] revenant_initWithStore:[RevenantHomeKitStore shared] identifier:RevenantHomeKitUUID(identifier)];
    else if ([kind isEqualToString:@"location"])
        event = [[HMLocationEvent alloc] revenant_initWithStore:[RevenantHomeKitStore shared] identifier:RevenantHomeKitUUID(identifier)];
    else
        event = [[HMEvent alloc] revenant_initWithStore:[RevenantHomeKitStore shared] identifier:RevenantHomeKitUUID(identifier)];
    return event;
}

#pragma mark - HMCharacteristicEvent

@implementation HMCharacteristicEvent

@synthesize revenant_characteristic = _revenant_characteristic, revenant_triggerValue = _revenant_triggerValue;

- (instancetype)init
{
    self = [super init];
    return self;
}

- (instancetype)initWithCharacteristic:(HMCharacteristic *)characteristic triggerValue:(id)triggerValue
{
    self = [super init];
    if (self) {
        _revenant_characteristic = characteristic;
        _revenant_triggerValue = [triggerValue copy];
    }
    return self;
}

- (HMCharacteristic *)characteristic
{
    return _revenant_characteristic;
}

- (id)triggerValue
{
    return _revenant_triggerValue;
}

- (void)updateTriggerValue:(id)triggerValue completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    _revenant_triggerValue = [triggerValue copy];
    RevenantHomeKitFinishError(completionHandler, nil);
}

@end

#pragma mark - HMLocationEvent

@implementation HMLocationEvent

@synthesize revenant_region = _revenant_region;

- (instancetype)init
{
    self = [super init];
    return self;
}

- (instancetype)initWithRegion:(CLCircularRegion *)region
{
    self = [super init];
    if (self)
        _revenant_region = region;
    return self;
}

- (CLCircularRegion *)region
{
    return _revenant_region;
}

- (void)updateRegion:(CLCircularRegion *)region completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!region) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeNilParameter, @"a region is needed"));
        return;
    }
    _revenant_region = region;
    RevenantHomeKitFinishError(completionHandler, nil);
}

@end

#pragma mark - HMEventTrigger

static NSArray *revenant_recurrenceList(NSArray<NSDateComponents *> *recurrences)
{
    NSMutableArray *stored = [NSMutableArray array];
    for (NSDateComponents *recurrence in recurrences) {
        [stored addObject:@{@"day": @(recurrence.day == NSDateComponentUndefined ? 0 : recurrence.day),
                            @"hour": @(recurrence.hour == NSDateComponentUndefined ? 0 : recurrence.hour),
                            @"minute": @(recurrence.minute == NSDateComponentUndefined ? 0 : recurrence.minute)}];
    }
    return stored;
}


@implementation HMEventTrigger

@synthesize revenant_identifier = _revenant_identifier, revenant_homeIdentifier = _revenant_homeIdentifier;

- (instancetype)revenant_initWithStore:(RevenantHomeKitStore *)store identifier:(NSUUID *)identifier __attribute__((objc_method_family(init)))
{
    if (!(self = [super revenant_initWithStore:store identifier:identifier]))
        return nil;
    if (self) {
        _revenant_identifier = identifier ? [RevenantHomeKitUUIDString(identifier) copy] : [RevenantHomeKitNewIdentifier() copy];
        RevenantHomeKitSetField(@"triggers", _revenant_identifier, @"kind", @"event");
        RevenantHomeKitSetField(@"triggers", _revenant_identifier, @"events", @[]);
    }
    return self;
}

- (instancetype)initWithName:(NSString *)name events:(NSArray<HMEvent *> *)events predicate:(NSPredicate *)predicate
{
    self = [self revenant_initWithStore:[RevenantHomeKitStore shared] identifier:nil];
    if (self) {
        [self revenant_applyName:name];
        [self revenant_applyEvents:events forKey:@"events"];
        [self revenant_applyPredicate:predicate];
    }
    return self;
}

- (instancetype)initWithName:(NSString *)name events:(NSArray<HMEvent *> *)events
                  endEvents:(NSArray<HMEvent *> *)endEvents recurrences:(NSArray<NSDateComponents *> *)recurrences
                   predicate:(NSPredicate *)predicate
{
    self = [self initWithName:name events:events predicate:predicate];
    if (self) {
        [self revenant_applyEvents:endEvents forKey:@"endEvents"];
        RevenantHomeKitSetField(@"triggers", _revenant_identifier, @"recurrences", revenant_recurrenceList(recurrences));
    }
    return self;
}

- (NSArray<HMEvent *> *)events
{
    return [self revenant_eventsForKey:@"events"];
}

- (NSArray<HMEvent *> *)endEvents
{
    return [self revenant_eventsForKey:@"endEvents"];
}

- (NSArray<NSDateComponents *> *)recurrences
{
    NSMutableArray *found = [NSMutableArray array];
    for (id entry in RevenantHomeKitStringListField(RevenantHomeKitRecord(@"triggers", _revenant_identifier), @"recurrences")) {
        NSDictionary *stored = [entry isKindOfClass:[NSDictionary class]] ? entry : nil;
        if (!stored)
            continue;
        NSDateComponents *recurrence = [[NSDateComponents alloc] init];
        recurrence.day = [stored[@"day"] integerValue];
        recurrence.hour = [stored[@"hour"] integerValue];
        recurrence.minute = [stored[@"minute"] integerValue];
        [found addObject:recurrence];
    }
    return found;
}

- (NSPredicate *)predicate
{
    return [RevenantHomeKitRecord(@"triggers", _revenant_identifier)[@"predicate"] copy];
}

- (BOOL)executeOnce
{
    return RevenantHomeKitBoolField(RevenantHomeKitRecord(@"triggers", _revenant_identifier), @"executeOnce", NO);
}

- (HMEventTriggerActivationState)triggerActivationState
{
    return HMEventTriggerActivationStateDisabledNoHomeHub;
}

- (void)addEvent:(HMEvent *)event completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!event) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeNilParameter, @"an event is needed"));
        return;
    }
    NSMutableDictionary *record = RevenantHomeKitRecord(@"triggers", _revenant_identifier);
    NSMutableArray *members = [RevenantHomeKitStringListField(record, @"events") mutableCopy];
    [members addObject:RevenantHomeKitUUIDString(event.uniqueIdentifier)];
    record[@"events"] = members;
    [[RevenantHomeKitStore shared] flushTableNamed:@"triggers"];
    RevenantHomeKitFinishError(completionHandler, nil);
}

- (void)removeEvent:(HMEvent *)event completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!event) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeNilParameter, @"an event is needed"));
        return;
    }
    NSMutableDictionary *record = RevenantHomeKitRecord(@"triggers", _revenant_identifier);
    NSMutableArray *members = [RevenantHomeKitStringListField(record, @"events") mutableCopy];
    [members removeObject:RevenantHomeKitUUIDString(event.uniqueIdentifier)];
    record[@"events"] = members;
    [[RevenantHomeKitStore shared] flushTableNamed:@"triggers"];
    RevenantHomeKitFinishError(completionHandler, nil);
}

- (void)updateEvents:(NSArray<HMEvent *> *)events completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!events) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeNilParameter, @"events are needed"));
        return;
    }
    [self revenant_applyEvents:events forKey:@"events"];
    RevenantHomeKitFinishError(completionHandler, nil);
}

- (void)updateEndEvents:(NSArray<HMEvent *> *)endEvents completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!endEvents) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeNilParameter, @"end events are needed"));
        return;
    }
    [self revenant_applyEvents:endEvents forKey:@"endEvents"];
    RevenantHomeKitFinishError(completionHandler, nil);
}

- (void)updateRecurrences:(NSArray<NSDateComponents *> *)recurrences completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!recurrences) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeNilParameter, @"recurrences are needed"));
        return;
    }
    RevenantHomeKitSetField(@"triggers", _revenant_identifier, @"recurrences", revenant_recurrenceList(recurrences));
    RevenantHomeKitFinishError(completionHandler, nil);
}

- (void)updatePredicate:(NSPredicate *)predicate completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    [self revenant_applyPredicate:predicate];
    RevenantHomeKitFinishError(completionHandler, nil);
}

- (void)updateExecuteOnce:(BOOL)executeOnce completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    RevenantHomeKitSetField(@"triggers", _revenant_identifier, @"executeOnce", @(executeOnce));
    RevenantHomeKitFinishError(completionHandler, nil);
}

- (void)revenant_setHomeIdentifier:(NSString *)homeIdentifier
{
    self.revenant_homeIdentifier = homeIdentifier;
}

- (void)revenant_applyName:(NSString *)name
{
    if (name)
        RevenantHomeKitSetField(@"triggers", _revenant_identifier, @"name", name);
}

- (void)revenant_applyEvents:(NSArray<HMEvent *> *)events forKey:(NSString *)key
{
    NSMutableArray *identifiers = [NSMutableArray array];
    for (HMEvent *event in events)
        [identifiers addObject:RevenantHomeKitUUIDString(event.uniqueIdentifier)];
    RevenantHomeKitSetField(@"triggers", _revenant_identifier, key, identifiers);
}

- (void)revenant_applyPredicate:(NSPredicate *)predicate
{
    RevenantHomeKitSetField(@"triggers", _revenant_identifier, @"predicate", predicate.predicateFormat);
}

- (NSArray<HMEvent *> *)revenant_eventsForKey:(NSString *)key
{
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *identifier in RevenantHomeKitStringListField(RevenantHomeKitRecord(@"triggers", _revenant_identifier), key))
        [found addObject:RevenantHomeKitEvent(identifier, @"event")];
    return found;
}

@end

HMEventTrigger *RevenantHomeKitEventTrigger(NSString *identifier, NSString *homeIdentifier)
{
    HMEventTrigger *trigger = [[HMEventTrigger alloc] revenant_initWithStore:[RevenantHomeKitStore shared] identifier:RevenantHomeKitUUID(identifier)];
    trigger.revenant_homeIdentifier = [homeIdentifier copy];
    RevenantHomeKitSetField(@"triggers", identifier, @"kind", @"event");
    return trigger;
}

#pragma mark - HMHomeAccessControl

@implementation HMHomeAccessControl

@synthesize revenant_home = _revenant_home, revenant_user = _revenant_user;

- (instancetype)revenant_initWithStore:(RevenantHomeKitStore *)store identifier:(NSUUID *)identifier __attribute__((objc_method_family(init)))
{
    (void)store;
    (void)identifier;
    self = [super revenant_initWithStore:store identifier:identifier];
    return self;
}

- (BOOL)administrator
{
    return YES;
}

@end

HMHomeAccessControl *RevenantHomeKitHomeAccessControl(HMHome *home, HMUser *user)
{
    HMHomeAccessControl *control = [[HMHomeAccessControl alloc] revenant_initWithStore:nil identifier:nil];
    control.revenant_home = home;
    control.revenant_user = user;
    return control;
}
