// The home graph of iOS 8.0: HMHome and the objects it holds -- HMRoom, HMZone, HMUser,
// HMServiceGroup -- with the triggers and action sets a home automates with: HMTrigger, HMTimerTrigger,
// HMActionSet.
//
// iOS 6 runs no home hub, no homekitd and no accessories daemon, so there is no system service to ask
// for a home graph and the port keeps it itself, in CharonHomeKitStore. What an application builds
// through -addHomeWithName:completionHandler: is there for the next launch, and every method that
// changes the graph writes the store before it calls back.
//
// Every class here is made through the port's own designated initialiser, `charon_initWithStore:`,
// because the release marks -init and +new unavailable on all of them; see CharonHomeKitConstruction.h
// for why, and for the pair of functions every graph edge is written with, because Apple's headers give
// the uniqueIdentifier family an NSUUID while the store's keys are strings.
//
// One release's API per object file, which is what the band machinery needs.
#import "CharonHomeKitInternal.h"

#pragma mark - HMRoom

@implementation HMRoom

// -init, as the release's own class answers it: the body read out of the
// arm64e cache of iOS 16.0, and what it does is written down in
// facts/HomeKit/HMAccessoryProfile.md. The header closes -init; Apple's class does not.
@synthesize charon_identifier = _charon_identifier, charon_homeIdentifier = _charon_homeIdentifier;

CHARON_HOMEKIT_NIL_INIT

// The port's own designated initialiser; see CharonHomeKitConstruction.h for why this is
// not -init and what the method-family attribute is for.
- (instancetype)charon_initWithStore:(CharonHomeKitStore *)store identifier:(NSUUID *)identifier __attribute__((objc_method_family(init)))
{
    self = [super init];
    if (self) {
        _charon_identifier = identifier ? [CharonHomeKitUUIDString(identifier) copy] : [CharonHomeKitNewIdentifier() copy];
        CharonHomeKitRecord(@"rooms", _charon_identifier);
    }
    return self;
}

- (NSUUID *)uniqueIdentifier
{
    return CharonHomeKitUUID(_charon_identifier);
}

- (NSString *)name
{
    return CharonHomeKitStringField(CharonHomeKitRecord(@"rooms", _charon_identifier), @"name", @"");
}

- (NSArray<HMAccessory *> *)accessories
{
    // A room's accessories are the ones the home's own ordering says are in it: the graph, not a second
    // copy of the membership, is what answers, and it answers the same on every launch.
    NSMutableDictionary *home = [[CharonHomeKitStore shared] tableNamed:@"homes"][_charon_homeIdentifier];
    if (!home)
        return @[];
    NSString *held = home[@"roomNames"][_charon_identifier];
    if (!held)
        return @[];
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *accessoryIdentifier in home[@"accessoryOrder"] ?: @[]) {
        if ([held isEqualToString:accessoryIdentifier])
            [found addObject:CharonHomeKitAccessory(accessoryIdentifier, _charon_homeIdentifier)];
    }
    return found;
}

- (void)updateName:(NSString *)name completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!name) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeNilParameter, @"a room needs a name"));
        return;
    }
    CharonHomeKitSetField(@"rooms", _charon_identifier, @"name", name);
    CharonHomeKitFinishError(completionHandler, nil);
}

@end

HMRoom *CharonHomeKitRoom(NSString *identifier, NSString *homeIdentifier)
{
    HMRoom *room = [[HMRoom alloc] charon_initWithStore:[CharonHomeKitStore shared] identifier:nil];
    room.charon_homeIdentifier = homeIdentifier;
    return room;
}

#pragma mark - HMZone

@implementation HMZone

// -init, as the release's own class answers it: the body read out of the
// arm64e cache of iOS 16.0, and what it does is written down in
// facts/HomeKit/HMAccessoryProfile.md. The header closes -init; Apple's class does not.
@synthesize charon_identifier = _charon_identifier, charon_homeIdentifier = _charon_homeIdentifier;

CHARON_HOMEKIT_NIL_INIT

// The port's own designated initialiser; see CharonHomeKitConstruction.h for why this is
// not -init and what the method-family attribute is for.
- (instancetype)charon_initWithStore:(CharonHomeKitStore *)store identifier:(NSUUID *)identifier __attribute__((objc_method_family(init)))
{
    self = [super init];
    if (self) {
        _charon_identifier = identifier ? [CharonHomeKitUUIDString(identifier) copy] : [CharonHomeKitNewIdentifier() copy];
        CharonHomeKitRecord(@"zones", _charon_identifier);
    }
    return self;
}

- (NSUUID *)uniqueIdentifier
{
    return CharonHomeKitUUID(_charon_identifier);
}

- (NSString *)name
{
    return CharonHomeKitStringField(CharonHomeKitRecord(@"zones", _charon_identifier), @"name", @"");
}

- (NSArray<HMRoom *> *)rooms
{
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *identifier in CharonHomeKitStringListField(CharonHomeKitRecord(@"zones", _charon_identifier), @"rooms"))
        [found addObject:CharonHomeKitRoom(identifier, _charon_homeIdentifier)];
    return found;
}

- (void)updateName:(NSString *)name completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!name) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeNilParameter, @"a zone needs a name"));
        return;
    }
    CharonHomeKitSetField(@"zones", _charon_identifier, @"name", name);
    CharonHomeKitFinishError(completionHandler, nil);
}

- (void)addRoom:(HMRoom *)room completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!room) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeNilParameter, @"a room is needed"));
        return;
    }
    // A room already in another zone of the same home is refused rather than moved out of it, which is
    // what HomeKit does and what an application that lays out zones would be surprised by.
    NSString *identifier = CharonHomeKitUUIDString(room.uniqueIdentifier);
    NSMutableDictionary *home = [[CharonHomeKitStore shared] tableNamed:@"homes"][_charon_homeIdentifier];
    for (NSString *zoneIdentifier in home[@"zoneOrder"] ?: @[]) {
        if ([zoneIdentifier isEqualToString:_charon_identifier])
            continue;
        NSArray *members = CharonHomeKitStringListField(CharonHomeKitRecord(@"zones", zoneIdentifier), @"rooms");
        if ([members containsObject:identifier]) {
            CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeObjectAlreadyAssociatedToHome,
                                                                            @"the room is already in another zone of this home"));
            return;
        }
    }
    NSMutableDictionary *record = CharonHomeKitRecord(@"zones", _charon_identifier);
    NSMutableArray *members = [CharonHomeKitStringListField(record, @"rooms") mutableCopy];
    if (![members containsObject:identifier]) {
        [members addObject:identifier];
        record[@"rooms"] = members;
        [[CharonHomeKitStore shared] flushTableNamed:@"zones"];
    }
    CharonHomeKitFinishError(completionHandler, nil);
}

- (void)removeRoom:(HMRoom *)room completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!room) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeNilParameter, @"a room is needed"));
        return;
    }
    NSMutableDictionary *record = CharonHomeKitRecord(@"zones", _charon_identifier);
    NSMutableArray *members = [CharonHomeKitStringListField(record, @"rooms") mutableCopy];
    [members removeObject:CharonHomeKitUUIDString(room.uniqueIdentifier)];
    record[@"rooms"] = members;
    [[CharonHomeKitStore shared] flushTableNamed:@"zones"];
    CharonHomeKitFinishError(completionHandler, nil);
}

@end

HMZone *CharonHomeKitZone(NSString *identifier, NSString *homeIdentifier)
{
    HMZone *zone = [[HMZone alloc] charon_initWithStore:[CharonHomeKitStore shared] identifier:nil];
    zone.charon_homeIdentifier = homeIdentifier;
    return zone;
}

#pragma mark - HMUser

@implementation HMUser

// -init, as the release's own class answers it: the body read out of the
// arm64e cache of iOS 16.0, and what it does is written down in
// facts/HomeKit/HMAccessoryProfile.md. The header closes -init; Apple's class does not.
@synthesize charon_identifier = _charon_identifier, charon_homeIdentifier = _charon_homeIdentifier;

CHARON_HOMEKIT_UNAVAILABLE_INIT

// The port's own designated initialiser; see CharonHomeKitConstruction.h for why this is
// not -init and what the method-family attribute is for.
- (instancetype)charon_initWithStore:(CharonHomeKitStore *)store identifier:(NSUUID *)identifier __attribute__((objc_method_family(init)))
{
    self = [super init];
    if (self) {
        _charon_identifier = identifier ? [CharonHomeKitUUIDString(identifier) copy] : [CharonHomeKitNewIdentifier() copy];
        CharonHomeKitRecord(@"users", _charon_identifier);
    }
    return self;
}

- (NSUUID *)uniqueIdentifier
{
    return CharonHomeKitUUID(_charon_identifier);
}

- (NSString *)name
{
    return CharonHomeKitStringField(CharonHomeKitRecord(@"users", _charon_identifier), @"name", @"");
}

- (void)charon_setName:(NSString *)name
{
    CharonHomeKitSetField(@"users", _charon_identifier, @"name", name);
}

@end

HMUser *CharonHomeKitUser(NSString *identifier, NSString *homeIdentifier)
{
    HMUser *user = [[HMUser alloc] charon_initWithStore:[CharonHomeKitStore shared] identifier:nil];
    user.charon_homeIdentifier = homeIdentifier;
    return user;
}

#pragma mark - HMServiceGroup

@implementation HMServiceGroup

// -init, as the release's own class answers it: the body read out of the
// arm64e cache of iOS 16.0, and what it does is written down in
// facts/HomeKit/HMAccessoryProfile.md. The header closes -init; Apple's class does not.
@synthesize charon_identifier = _charon_identifier, charon_homeIdentifier = _charon_homeIdentifier;

CHARON_HOMEKIT_NIL_INIT

// The port's own designated initialiser; see CharonHomeKitConstruction.h for why this is
// not -init and what the method-family attribute is for.
- (instancetype)charon_initWithStore:(CharonHomeKitStore *)store identifier:(NSUUID *)identifier __attribute__((objc_method_family(init)))
{
    self = [super init];
    if (self) {
        _charon_identifier = identifier ? [CharonHomeKitUUIDString(identifier) copy] : [CharonHomeKitNewIdentifier() copy];
        CharonHomeKitRecord(@"servicegroups", _charon_identifier);
    }
    return self;
}

- (NSUUID *)uniqueIdentifier
{
    return CharonHomeKitUUID(_charon_identifier);
}

- (NSString *)name
{
    return CharonHomeKitStringField(CharonHomeKitRecord(@"servicegroups", _charon_identifier), @"name", @"");
}

- (NSArray<HMService *> *)services
{
    // A service belongs to an accessory, so the group walks the accessories' own service lists to find
    // the ones it holds: the graph answers, and it answers the same on every launch.
    NSMutableDictionary *accessories = [[CharonHomeKitStore shared] tableNamed:@"accessories"];
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *serviceIdentifier in CharonHomeKitStringListField(CharonHomeKitRecord(@"servicegroups", _charon_identifier), @"services")) {
        for (NSString *accessoryIdentifier in accessories) {
            NSArray *services = accessories[accessoryIdentifier][@"services"] ?: @[];
            if ([services containsObject:serviceIdentifier]) {
                [found addObject:CharonHomeKitService(serviceIdentifier, accessoryIdentifier)];
                break;
            }
        }
    }
    return found;
}

- (void)updateName:(NSString *)name completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!name) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeNilParameter, @"a service group needs a name"));
        return;
    }
    CharonHomeKitSetField(@"servicegroups", _charon_identifier, @"name", name);
    CharonHomeKitFinishError(completionHandler, nil);
}

- (void)addService:(HMService *)service completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!service) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeNilParameter, @"a service is needed"));
        return;
    }
    NSMutableDictionary *record = CharonHomeKitRecord(@"servicegroups", _charon_identifier);
    NSMutableArray *members = [CharonHomeKitStringListField(record, @"services") mutableCopy];
    NSString *identifier = CharonHomeKitUUIDString(service.uniqueIdentifier);
    if (![members containsObject:identifier]) {
        [members addObject:identifier];
        record[@"services"] = members;
        [[CharonHomeKitStore shared] flushTableNamed:@"servicegroups"];
    }
    [self charon_tellHome:@selector(home:didAddService:toServiceGroup:) object:self block:^(id<HMHomeDelegate> delegate, HMHome *home, id object) {
        [delegate home:home didAddService:service toServiceGroup:(HMServiceGroup *)object];
    }];
    CharonHomeKitFinishError(completionHandler, nil);
}

- (void)removeService:(HMService *)service completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!service) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeNilParameter, @"a service is needed"));
        return;
    }
    NSMutableDictionary *record = CharonHomeKitRecord(@"servicegroups", _charon_identifier);
    NSMutableArray *members = [CharonHomeKitStringListField(record, @"services") mutableCopy];
    [members removeObject:CharonHomeKitUUIDString(service.uniqueIdentifier)];
    record[@"services"] = members;
    [[CharonHomeKitStore shared] flushTableNamed:@"servicegroups"];
    [self charon_tellHome:@selector(home:didRemoveService:fromServiceGroup:) object:self block:^(id<HMHomeDelegate> delegate, HMHome *home, id object) {
        [delegate home:home didRemoveService:service fromServiceGroup:(HMServiceGroup *)object];
    }];
    CharonHomeKitFinishError(completionHandler, nil);
}

@end

HMServiceGroup *CharonHomeKitServiceGroup(NSString *identifier, NSString *homeIdentifier)
{
    HMServiceGroup *group = [[HMServiceGroup alloc] charon_initWithStore:[CharonHomeKitStore shared] identifier:nil];
    group.charon_homeIdentifier = homeIdentifier;
    return group;
}

#pragma mark - HMActionSet

@implementation HMActionSet

// -init, as the release's own class answers it: the body read out of the
// arm64e cache of iOS 16.0, and what it does is written down in
// facts/HomeKit/HMAccessoryProfile.md. The header closes -init; Apple's class does not.
@synthesize charon_identifier = _charon_identifier, charon_homeIdentifier = _charon_homeIdentifier;

CHARON_HOMEKIT_NIL_INIT

- (void)charon_setHomeIdentifier:(NSString *)homeIdentifier
{
    self.charon_homeIdentifier = homeIdentifier;
}

// The port's own designated initialiser; see CharonHomeKitConstruction.h for why this is
// not -init and what the method-family attribute is for.
- (instancetype)charon_initWithStore:(CharonHomeKitStore *)store identifier:(NSUUID *)identifier __attribute__((objc_method_family(init)))
{
    self = [super init];
    if (self) {
        _charon_identifier = identifier ? [CharonHomeKitUUIDString(identifier) copy] : [CharonHomeKitNewIdentifier() copy];
        CharonHomeKitRecord(@"actionsets", _charon_identifier);
    }
    return self;
}

- (NSUUID *)uniqueIdentifier
{
    return CharonHomeKitUUID(_charon_identifier);
}

- (NSString *)name
{
    return CharonHomeKitStringField(CharonHomeKitRecord(@"actionsets", _charon_identifier), @"name", @"");
}

- (NSString *)actionSetType
{
    return CharonHomeKitStringField(CharonHomeKitRecord(@"actionsets", _charon_identifier), @"type", HMActionSetTypeUserDefined);
}

- (BOOL)executing
{
    return CharonHomeKitBoolField(CharonHomeKitRecord(@"actionsets", _charon_identifier), @"executing", NO);
}

- (NSDate *)lastExecutionDate
{
    return [CharonHomeKitRecord(@"actionsets", _charon_identifier)[@"lastExecutionDate"] copy];
}

- (NSArray<HMAction *> *)actions
{
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *identifier in CharonHomeKitStringListField(CharonHomeKitRecord(@"actionsets", _charon_identifier), @"actions"))
        [found addObject:CharonHomeKitAction(identifier, _charon_homeIdentifier)];
    return found;
}

- (void)updateName:(NSString *)name completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!name) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeNilParameter, @"an action set needs a name"));
        return;
    }
    CharonHomeKitSetField(@"actionsets", _charon_identifier, @"name", name);
    [self charon_tellHome:@selector(home:didUpdateNameForActionSet:) object:self block:^(id<HMHomeDelegate> delegate, HMHome *home, id object) {
        [delegate home:home didUpdateNameForActionSet:(HMActionSet *)object];
    }];
    CharonHomeKitFinishError(completionHandler, nil);
}

- (void)addAction:(HMAction *)action completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!action) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeNilParameter, @"an action is needed"));
        return;
    }
    NSMutableDictionary *record = CharonHomeKitRecord(@"actionsets", _charon_identifier);
    NSMutableArray *members = [CharonHomeKitStringListField(record, @"actions") mutableCopy];
    if (![members containsObject:CharonHomeKitUUIDString(action.uniqueIdentifier)]) {
        [members addObject:CharonHomeKitUUIDString(action.uniqueIdentifier)];
        record[@"actions"] = members;
        [[CharonHomeKitStore shared] flushTableNamed:@"actionsets"];
    }
    [self charon_tellHome:@selector(home:didUpdateActionsForActionSet:) object:self block:^(id<HMHomeDelegate> delegate, HMHome *home, id object) {
        [delegate home:home didUpdateActionsForActionSet:(HMActionSet *)object];
    }];
    CharonHomeKitFinishError(completionHandler, nil);
}

- (void)removeAction:(HMAction *)action completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!action) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeNilParameter, @"an action is needed"));
        return;
    }
    NSMutableDictionary *record = CharonHomeKitRecord(@"actionsets", _charon_identifier);
    NSMutableArray *members = [CharonHomeKitStringListField(record, @"actions") mutableCopy];
    [members removeObject:CharonHomeKitUUIDString(action.uniqueIdentifier)];
    record[@"actions"] = members;
    [[CharonHomeKitStore shared] flushTableNamed:@"actionsets"];
    [self charon_tellHome:@selector(home:didUpdateActionsForActionSet:) object:self block:^(id<HMHomeDelegate> delegate, HMHome *home, id object) {
        [delegate home:home didUpdateActionsForActionSet:(HMActionSet *)object];
    }];
    CharonHomeKitFinishError(completionHandler, nil);
}

@end

HMActionSet *CharonHomeKitActionSet(NSString *identifier, NSString *homeIdentifier)
{
    HMActionSet *set = [[HMActionSet alloc] charon_initWithStore:[CharonHomeKitStore shared] identifier:nil];
    set.charon_homeIdentifier = homeIdentifier;
    return set;
}

#pragma mark - HMTrigger

@implementation HMTrigger

@synthesize charon_identifier = _charon_identifier, charon_homeIdentifier = _charon_homeIdentifier;

// The port's own designated initialiser; see CharonHomeKitConstruction.h for why this is not
// -init and what the method-family attribute is for.
- (instancetype)charon_initWithStore:(CharonHomeKitStore *)store identifier:(NSUUID *)identifier __attribute__((objc_method_family(init)))
{
    (void)store;
    self = [super init];
    if (self) {
        _charon_identifier = identifier ? [CharonHomeKitUUIDString(identifier) copy] : [CharonHomeKitNewIdentifier() copy];
        CharonHomeKitSetField(@"triggers", _charon_identifier, @"kind", @"timer");
        CharonHomeKitSetField(@"triggers", _charon_identifier, @"actionSets", @[]);
    }
    return self;
}

- (NSUUID *)uniqueIdentifier
{
    return CharonHomeKitUUID(_charon_identifier);
}

- (NSString *)name
{
    return CharonHomeKitStringField(CharonHomeKitRecord(@"triggers", _charon_identifier), @"name", @"");
}

- (BOOL)enabled
{
    return CharonHomeKitBoolField(CharonHomeKitRecord(@"triggers", _charon_identifier), @"enabled", NO);
}

- (NSDate *)lastFireDate
{
    return [CharonHomeKitRecord(@"triggers", _charon_identifier)[@"lastFireDate"] copy];
}

- (NSArray<HMActionSet *> *)actionSets
{
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *identifier in CharonHomeKitStringListField(CharonHomeKitRecord(@"triggers", _charon_identifier), @"actionSets"))
        [found addObject:CharonHomeKitActionSet(identifier, _charon_homeIdentifier)];
    return found;
}

- (void)updateName:(NSString *)name completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!name) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeNilParameter, @"a trigger needs a name"));
        return;
    }
    CharonHomeKitSetField(@"triggers", _charon_identifier, @"name", name);
    [self charon_tellHome:@selector(home:didUpdateNameForTrigger:) object:self block:^(id<HMHomeDelegate> delegate, HMHome *home, id object) {
        [delegate home:home didUpdateNameForTrigger:(HMTrigger *)object];
    }];
    CharonHomeKitFinishError(completionHandler, nil);
}

- (void)enable:(BOOL)enabled completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    CharonHomeKitSetField(@"triggers", _charon_identifier, @"enabled", @(enabled));
    CharonHomeKitFinishError(completionHandler, nil);
}

- (void)addActionSet:(HMActionSet *)actionSet completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!actionSet) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeNilParameter, @"an action set is needed"));
        return;
    }
    NSMutableDictionary *record = CharonHomeKitRecord(@"triggers", _charon_identifier);
    NSMutableArray *members = [CharonHomeKitStringListField(record, @"actionSets") mutableCopy];
    if (![members containsObject:CharonHomeKitUUIDString(actionSet.uniqueIdentifier)]) {
        [members addObject:CharonHomeKitUUIDString(actionSet.uniqueIdentifier)];
        record[@"actionSets"] = members;
        [[CharonHomeKitStore shared] flushTableNamed:@"triggers"];
    }
    CharonHomeKitFinishError(completionHandler, nil);
}

- (void)removeActionSet:(HMActionSet *)actionSet completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!actionSet) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeNilParameter, @"an action set is needed"));
        return;
    }
    NSMutableDictionary *record = CharonHomeKitRecord(@"triggers", _charon_identifier);
    NSMutableArray *members = [CharonHomeKitStringListField(record, @"actionSets") mutableCopy];
    [members removeObject:CharonHomeKitUUIDString(actionSet.uniqueIdentifier)];
    record[@"actionSets"] = members;
    [[CharonHomeKitStore shared] flushTableNamed:@"triggers"];
    CharonHomeKitFinishError(completionHandler, nil);
}

@end

HMTrigger *CharonHomeKitTrigger(NSString *identifier, NSString *homeIdentifier)
{
    HMTrigger *trigger = [[HMTrigger alloc] charon_initWithStore:[CharonHomeKitStore shared] identifier:nil];
    trigger.charon_homeIdentifier = homeIdentifier;
    CharonHomeKitSetField(@"triggers", trigger.charon_identifier, @"kind", @"timer");
    return trigger;
}

#pragma mark - HMTimerTrigger

@implementation HMTimerTrigger

// -init, as the release's own class answers it: the body read out of the
// arm64e cache of iOS 16.0, and what it does is written down in
// facts/HomeKit/HMAccessoryProfile.md. The header closes -init; Apple's class does not.
CHARON_HOMEKIT_NIL_INIT
- (instancetype)initWithName:(NSString *)name fireDate:(NSDate *)fireDate recurrence:(NSDateComponents *)recurrence
{
    // HMTrigger's -init is unavailable in the release's header, so the timer trigger is built through
    // the port's own designated initialiser and the three initialisers above it are its arguments.
    self = [super charon_initWithStore:[CharonHomeKitStore shared] identifier:nil];
    if (self) {
        [self charon_applyName:name];
        [self charon_applyFireDate:fireDate];
        [self charon_applyRecurrence:recurrence];
    }
    return self;
}

- (instancetype)initWithName:(NSString *)name fireDate:(NSDate *)fireDate timeZone:(NSTimeZone *)timeZone
                 recurrence:(NSDateComponents *)recurrence recurrenceCalendar:(NSCalendar *)recurrenceCalendar
{
    self = [super charon_initWithStore:[CharonHomeKitStore shared] identifier:nil];
    if (self) {
        [self charon_applyName:name];
        [self charon_applyFireDate:fireDate];
        CharonHomeKitSetField(@"triggers", self.charon_identifier, @"timeZone", timeZone.name);
        [self charon_applyRecurrence:recurrence];
        // The calendar is stored by its identifier, which is what crosses a property list: a calendar
        // object is not one of a value's properties, and a store that held one would hold a different
        // object each launch.
        NSString *identifier = nil;
        if ([recurrenceCalendar respondsToSelector:@selector(calendarIdentifier)])
            identifier = [recurrenceCalendar valueForKey:@"calendarIdentifier"];
        CharonHomeKitSetField(@"triggers", self.charon_identifier, @"recurrenceCalendar", identifier);
    }
    return self;
}

- (NSDate *)fireDate
{
    return [CharonHomeKitRecord(@"triggers", self.charon_identifier)[@"fireDate"] copy];
}

- (NSTimeZone *)timeZone
{
    NSString *name = CharonHomeKitRecord(@"triggers", self.charon_identifier)[@"timeZone"];
    return name ? [NSTimeZone timeZoneWithName:name] : [NSTimeZone localTimeZone];
}

- (NSDateComponents *)recurrence
{
    return [CharonHomeKitRecord(@"triggers", self.charon_identifier)[@"recurrence"] copy];
}

- (NSCalendar *)recurrenceCalendar
{
    NSString *identifier = CharonHomeKitRecord(@"triggers", self.charon_identifier)[@"recurrenceCalendar"];
    if (identifier && [NSCalendar respondsToSelector:@selector(calendarWithIdentifier:)])
        return [NSCalendar calendarWithIdentifier:identifier];
    return [NSCalendar currentCalendar];
}

- (void)updateFireDate:(NSDate *)fireDate completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    // A fire date in the past is refused, the way HomeKit refuses it: a trigger that fires where it
    // cannot is one that will never fire again.
    if (!fireDate) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeNilParameter, @"a fire date is needed"));
        return;
    }
    if ([fireDate compare:[NSDate date]] == NSOrderedAscending) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeFireDateInPast, @"the fire date is in the past"));
        return;
    }
    [self charon_applyFireDate:fireDate];
    CharonHomeKitFinishError(completionHandler, nil);
}

- (void)updateRecurrence:(NSDateComponents *)recurrence completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!recurrence) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeNilParameter, @"a recurrence is needed"));
        return;
    }
    [self charon_applyRecurrence:recurrence];
    CharonHomeKitFinishError(completionHandler, nil);
}

- (void)updateTimeZone:(NSTimeZone *)timeZone completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!timeZone) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeNilParameter, @"a time zone is needed"));
        return;
    }
    CharonHomeKitSetField(@"triggers", self.charon_identifier, @"timeZone", timeZone.name);
    CharonHomeKitFinishError(completionHandler, nil);
}

- (void)charon_applyName:(NSString *)name
{
    if (name)
        CharonHomeKitSetField(@"triggers", self.charon_identifier, @"name", name);
}

- (void)charon_applyFireDate:(NSDate *)fireDate
{
    if (fireDate)
        CharonHomeKitSetField(@"triggers", self.charon_identifier, @"fireDate", fireDate);
}

- (void)charon_applyRecurrence:(NSDateComponents *)recurrence
{
    // A recurrence is a set of fields, and it is stored as the numbers themselves so that it crosses a
    // property list, and read back the same way. A field that is not set is left out rather than
    // written as zero, because a zero is a real value for a day and a real value for an hour.
    if (!recurrence)
        return;
    NSMutableDictionary *fields = [NSMutableDictionary dictionary];
#define CHARON_RECURRENCE_FIELD(name) do { NSInteger value = [recurrence name]; \
    if (value != NSDateComponentUndefined) fields[@#name] = @(value); } while (0)
    CHARON_RECURRENCE_FIELD(era); CHARON_RECURRENCE_FIELD(year); CHARON_RECURRENCE_FIELD(month);
    CHARON_RECURRENCE_FIELD(day); CHARON_RECURRENCE_FIELD(hour); CHARON_RECURRENCE_FIELD(minute);
    CHARON_RECURRENCE_FIELD(second); CHARON_RECURRENCE_FIELD(weekday);
    CHARON_RECURRENCE_FIELD(weekdayOrdinal); CHARON_RECURRENCE_FIELD(quarter);
    CHARON_RECURRENCE_FIELD(weekOfMonth); CHARON_RECURRENCE_FIELD(weekOfYear);
    CHARON_RECURRENCE_FIELD(yearForWeekOfYear);
#undef CHARON_RECURRENCE_FIELD
    CharonHomeKitSetField(@"triggers", self.charon_identifier, @"recurrence", fields);
}

@end

HMTimerTrigger *CharonHomeKitTimerTrigger(NSString *identifier, NSString *homeIdentifier)
{
    HMTimerTrigger *trigger = [[HMTimerTrigger alloc] charon_initWithStore:[CharonHomeKitStore shared] identifier:nil];
    trigger.charon_homeIdentifier = homeIdentifier;
    CharonHomeKitSetField(@"triggers", trigger.charon_identifier, @"kind", @"timer");
    return trigger;
}
