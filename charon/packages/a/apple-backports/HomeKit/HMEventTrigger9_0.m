// The events of iOS 9.0 and the trigger that fires on them: HMEvent, HMCharacteristicEvent,
// HMLocationEvent, HMEventTrigger and HMHomeAccessControl.
//
// One release's API per object file, which is what the band machinery needs: every class here arrived
// in iOS 9.0, whatever release a later member of one of them arrived in.
#import "CharonHomeKitInternal.h"

#pragma mark - HMEvent

@implementation HMEvent

@synthesize charon_identifier = _charon_identifier;

- (NSUUID *)uniqueIdentifier
{
    return CharonHomeKitUUID(_charon_identifier);
}

@end

// The port's own way back in, and the event is rebuilt as the subclass it was created as: an event
// trigger keeps each event's kind beside its identifier, and a presence event read back is a presence
// event rather than whichever subclass the reader happens to reach first.
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

// A recurrence, as the numbers a date component is made of, so that it crosses a property list: a
// field that is not set is left out rather than written as zero, because a zero is a real value for a
// day and a real value for an hour.
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

// The release marks -init and +new unavailable on the trigger too, so it is made the same way every
// other graph class is; see CharonHomeKitConstruction.h.
- (instancetype)charon_initWithStore:(CharonHomeKitStore *)store identifier:(NSUUID *)identifier __attribute__((objc_method_family(init)))
{
    // HMTrigger's own -init is unavailable in the release's header, so a subclass reaches the base
    // through the base's port construction rather than through [super init]: the method family
    // attribute lets this assign self, and the call names a method of our own, which is nameable.
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
    // An event trigger fires when the home hub is there to run it, and a home hub is the one thing
    // this release has none of. The header names that condition itself:
    // HMEventTriggerActivationState.h:27 is HMEventTriggerActivationStateDisabledNoHomeHub, and
    // "disabled, no home hub" is what this device is.
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
    // A predicate is an expression object and does not cross a property list, so what is stored is its
    // format, and what is read back is a predicate built from that. The format is what the release
    // evaluates too, so a trigger's predicate means the same thing after a relaunch.
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
    // The base's -init is unavailable too, so this one reaches it the way every other subclass here
    // does: through the base's own port construction, which is a method of our own and nameable.
    self = [super charon_initWithStore:store identifier:identifier];
    return self;
}

- (BOOL)administrator
{
    // The administrator of a home is the user who may change it. This port's home graph is the
    // application's own store, which no other application can read or write, so the user it reports is
    // the administrator: answering NO would tell an application its own store is writable by somebody
    // else, and an application that believed it would stop doing the one thing it is entitled to do.
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
