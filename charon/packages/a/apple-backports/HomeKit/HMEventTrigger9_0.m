#import "CharonHomeKitInternal.h"

#pragma mark - HMEvent

@implementation HMEvent

@synthesize charon_identifier = _charon_identifier;

- (NSUUID *)uniqueIdentifier
{
    return CharonHomeKitUUID(_charon_identifier);
}

@end

HMEvent *CharonHomeKitEvent(NSString *identifier, NSString *kind)
{
    HMEvent *event = nil;
    if ([kind isEqualToString:@"characteristic"])
        event = [[HMCharacteristicEvent alloc] charon_initWithStore:[CharonHomeKitStore shared] identifier:CharonHomeKitUUID(identifier)];
    else if ([kind isEqualToString:@"location"])
        event = [[HMLocationEvent alloc] charon_initWithStore:[CharonHomeKitStore shared] identifier:CharonHomeKitUUID(identifier)];
    else
        event = [[HMEvent alloc] charon_initWithStore:[CharonHomeKitStore shared] identifier:CharonHomeKitUUID(identifier)];
    return event;
}

#pragma mark - HMCharacteristicEvent

@implementation HMCharacteristicEvent

@synthesize charon_characteristic = _charon_characteristic, charon_triggerValue = _charon_triggerValue;

- (instancetype)init
{
    self = [super init];
    return self;
}

- (instancetype)initWithCharacteristic:(HMCharacteristic *)characteristic triggerValue:(id)triggerValue
{
    self = [super init];
    if (self) {
        _charon_characteristic = characteristic;
        _charon_triggerValue = [triggerValue copy];
    }
    return self;
}

- (HMCharacteristic *)characteristic
{
    return _charon_characteristic;
}

- (id)triggerValue
{
    return _charon_triggerValue;
}

- (void)updateTriggerValue:(id)triggerValue completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    _charon_triggerValue = [triggerValue copy];
    CharonHomeKitFinishError(completionHandler, nil);
}

@end

#pragma mark - HMLocationEvent

@implementation HMLocationEvent

@synthesize charon_region = _charon_region;

- (instancetype)init
{
    self = [super init];
    return self;
}

- (instancetype)initWithRegion:(CLCircularRegion *)region
{
    self = [super init];
    if (self)
        _charon_region = region;
    return self;
}

- (CLCircularRegion *)region
{
    return _charon_region;
}

- (void)updateRegion:(CLCircularRegion *)region completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!region) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeNilParameter, @"a region is needed"));
        return;
    }
    _charon_region = region;
    CharonHomeKitFinishError(completionHandler, nil);
}

@end

#pragma mark - HMEventTrigger

static NSArray *charon_recurrenceList(NSArray<NSDateComponents *> *recurrences)
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

@synthesize charon_identifier = _charon_identifier, charon_homeIdentifier = _charon_homeIdentifier;

- (instancetype)charon_initWithStore:(CharonHomeKitStore *)store identifier:(NSUUID *)identifier __attribute__((objc_method_family(init)))
{
    if (!(self = [super charon_initWithStore:store identifier:identifier]))
        return nil;
    if (self) {
        _charon_identifier = identifier ? [CharonHomeKitUUIDString(identifier) copy] : [CharonHomeKitNewIdentifier() copy];
        CharonHomeKitSetField(@"triggers", _charon_identifier, @"kind", @"event");
        CharonHomeKitSetField(@"triggers", _charon_identifier, @"events", @[]);
    }
    return self;
}

- (instancetype)initWithName:(NSString *)name events:(NSArray<HMEvent *> *)events predicate:(NSPredicate *)predicate
{
    self = [self charon_initWithStore:[CharonHomeKitStore shared] identifier:nil];
    if (self) {
        [self charon_applyName:name];
        [self charon_applyEvents:events forKey:@"events"];
        [self charon_applyPredicate:predicate];
    }
    return self;
}

- (instancetype)initWithName:(NSString *)name events:(NSArray<HMEvent *> *)events
                  endEvents:(NSArray<HMEvent *> *)endEvents recurrences:(NSArray<NSDateComponents *> *)recurrences
                   predicate:(NSPredicate *)predicate
{
    self = [self initWithName:name events:events predicate:predicate];
    if (self) {
        [self charon_applyEvents:endEvents forKey:@"endEvents"];
        CharonHomeKitSetField(@"triggers", _charon_identifier, @"recurrences", charon_recurrenceList(recurrences));
    }
    return self;
}

- (NSArray<HMEvent *> *)events
{
    return [self charon_eventsForKey:@"events"];
}

- (NSArray<HMEvent *> *)endEvents
{
    return [self charon_eventsForKey:@"endEvents"];
}

- (NSArray<NSDateComponents *> *)recurrences
{
    NSMutableArray *found = [NSMutableArray array];
    for (id entry in CharonHomeKitStringListField(CharonHomeKitRecord(@"triggers", _charon_identifier), @"recurrences")) {
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
    return [CharonHomeKitRecord(@"triggers", _charon_identifier)[@"predicate"] copy];
}

- (BOOL)executeOnce
{
    return CharonHomeKitBoolField(CharonHomeKitRecord(@"triggers", _charon_identifier), @"executeOnce", NO);
}

- (HMEventTriggerActivationState)triggerActivationState
{
    return HMEventTriggerActivationStateDisabledNoHomeHub;
}

- (void)addEvent:(HMEvent *)event completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!event) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeNilParameter, @"an event is needed"));
        return;
    }
    NSMutableDictionary *record = CharonHomeKitRecord(@"triggers", _charon_identifier);
    NSMutableArray *members = [CharonHomeKitStringListField(record, @"events") mutableCopy];
    [members addObject:CharonHomeKitUUIDString(event.uniqueIdentifier)];
    record[@"events"] = members;
    [[CharonHomeKitStore shared] flushTableNamed:@"triggers"];
    CharonHomeKitFinishError(completionHandler, nil);
}

- (void)removeEvent:(HMEvent *)event completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!event) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeNilParameter, @"an event is needed"));
        return;
    }
    NSMutableDictionary *record = CharonHomeKitRecord(@"triggers", _charon_identifier);
    NSMutableArray *members = [CharonHomeKitStringListField(record, @"events") mutableCopy];
    [members removeObject:CharonHomeKitUUIDString(event.uniqueIdentifier)];
    record[@"events"] = members;
    [[CharonHomeKitStore shared] flushTableNamed:@"triggers"];
    CharonHomeKitFinishError(completionHandler, nil);
}

- (void)updateEvents:(NSArray<HMEvent *> *)events completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!events) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeNilParameter, @"events are needed"));
        return;
    }
    [self charon_applyEvents:events forKey:@"events"];
    CharonHomeKitFinishError(completionHandler, nil);
}

- (void)updateEndEvents:(NSArray<HMEvent *> *)endEvents completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!endEvents) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeNilParameter, @"end events are needed"));
        return;
    }
    [self charon_applyEvents:endEvents forKey:@"endEvents"];
    CharonHomeKitFinishError(completionHandler, nil);
}

- (void)updateRecurrences:(NSArray<NSDateComponents *> *)recurrences completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!recurrences) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeNilParameter, @"recurrences are needed"));
        return;
    }
    CharonHomeKitSetField(@"triggers", _charon_identifier, @"recurrences", charon_recurrenceList(recurrences));
    CharonHomeKitFinishError(completionHandler, nil);
}

- (void)updatePredicate:(NSPredicate *)predicate completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    [self charon_applyPredicate:predicate];
    CharonHomeKitFinishError(completionHandler, nil);
}

- (void)updateExecuteOnce:(BOOL)executeOnce completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    CharonHomeKitSetField(@"triggers", _charon_identifier, @"executeOnce", @(executeOnce));
    CharonHomeKitFinishError(completionHandler, nil);
}

- (void)charon_setHomeIdentifier:(NSString *)homeIdentifier
{
    self.charon_homeIdentifier = homeIdentifier;
}

- (void)charon_applyName:(NSString *)name
{
    if (name)
        CharonHomeKitSetField(@"triggers", _charon_identifier, @"name", name);
}

- (void)charon_applyEvents:(NSArray<HMEvent *> *)events forKey:(NSString *)key
{
    NSMutableArray *identifiers = [NSMutableArray array];
    for (HMEvent *event in events)
        [identifiers addObject:CharonHomeKitUUIDString(event.uniqueIdentifier)];
    CharonHomeKitSetField(@"triggers", _charon_identifier, key, identifiers);
}

- (void)charon_applyPredicate:(NSPredicate *)predicate
{
    CharonHomeKitSetField(@"triggers", _charon_identifier, @"predicate", predicate.predicateFormat);
}

- (NSArray<HMEvent *> *)charon_eventsForKey:(NSString *)key
{
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *identifier in CharonHomeKitStringListField(CharonHomeKitRecord(@"triggers", _charon_identifier), key))
        [found addObject:CharonHomeKitEvent(identifier, @"event")];
    return found;
}

@end

HMEventTrigger *CharonHomeKitEventTrigger(NSString *identifier, NSString *homeIdentifier)
{
    HMEventTrigger *trigger = [[HMEventTrigger alloc] charon_initWithStore:[CharonHomeKitStore shared] identifier:CharonHomeKitUUID(identifier)];
    trigger.charon_homeIdentifier = [homeIdentifier copy];
    CharonHomeKitSetField(@"triggers", identifier, @"kind", @"event");
    return trigger;
}

#pragma mark - HMHomeAccessControl

@implementation HMHomeAccessControl

@synthesize charon_home = _charon_home, charon_user = _charon_user;

- (instancetype)charon_initWithStore:(CharonHomeKitStore *)store identifier:(NSUUID *)identifier __attribute__((objc_method_family(init)))
{
    (void)store;
    (void)identifier;
    self = [super charon_initWithStore:store identifier:identifier];
    return self;
}

- (BOOL)administrator
{
    return YES;
}

@end

HMHomeAccessControl *CharonHomeKitHomeAccessControl(HMHome *home, HMUser *user)
{
    HMHomeAccessControl *control = [[HMHomeAccessControl alloc] charon_initWithStore:nil identifier:nil];
    control.charon_home = home;
    control.charon_user = user;
    return control;
}
