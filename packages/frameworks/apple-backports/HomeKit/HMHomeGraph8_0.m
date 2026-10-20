#import "RevenantHomeKitInternal.h"

#pragma mark - HMRoom

@implementation HMRoom

@synthesize revenant_identifier = _revenant_identifier, revenant_homeIdentifier = _revenant_homeIdentifier;

REVENANT_HOMEKIT_NIL_INIT

- (instancetype)revenant_initWithStore:(RevenantHomeKitStore *)store identifier:(NSUUID *)identifier __attribute__((objc_method_family(init)))
{
    self = [super init];
    if (self) {
        _revenant_identifier = identifier ? [RevenantHomeKitUUIDString(identifier) copy] : [RevenantHomeKitNewIdentifier() copy];
        RevenantHomeKitRecord(@"rooms", _revenant_identifier);
    }
    return self;
}

- (NSUUID *)uniqueIdentifier
{
    return RevenantHomeKitUUID(_revenant_identifier);
}

- (NSString *)name
{
    return RevenantHomeKitStringField(RevenantHomeKitRecord(@"rooms", _revenant_identifier), @"name", @"");
}

- (NSArray<HMAccessory *> *)accessories
{
    NSMutableDictionary *home = [[RevenantHomeKitStore shared] tableNamed:@"homes"][_revenant_homeIdentifier];
    if (!home)
        return @[];
    NSString *held = home[@"roomNames"][_revenant_identifier];
    if (!held)
        return @[];
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *accessoryIdentifier in home[@"accessoryOrder"] ?: @[]) {
        if ([held isEqualToString:accessoryIdentifier])
            [found addObject:RevenantHomeKitAccessory(accessoryIdentifier, _revenant_homeIdentifier)];
    }
    return found;
}

- (void)updateName:(NSString *)name completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!name) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeNilParameter, @"a room needs a name"));
        return;
    }
    RevenantHomeKitSetField(@"rooms", _revenant_identifier, @"name", name);
    RevenantHomeKitFinishError(completionHandler, nil);
}

@end

HMRoom *RevenantHomeKitRoom(NSString *identifier, NSString *homeIdentifier)
{
    HMRoom *room = [[HMRoom alloc] revenant_initWithStore:[RevenantHomeKitStore shared] identifier:nil];
    room.revenant_homeIdentifier = homeIdentifier;
    return room;
}

#pragma mark - HMZone

@implementation HMZone

@synthesize revenant_identifier = _revenant_identifier, revenant_homeIdentifier = _revenant_homeIdentifier;

REVENANT_HOMEKIT_NIL_INIT

- (instancetype)revenant_initWithStore:(RevenantHomeKitStore *)store identifier:(NSUUID *)identifier __attribute__((objc_method_family(init)))
{
    self = [super init];
    if (self) {
        _revenant_identifier = identifier ? [RevenantHomeKitUUIDString(identifier) copy] : [RevenantHomeKitNewIdentifier() copy];
        RevenantHomeKitRecord(@"zones", _revenant_identifier);
    }
    return self;
}

- (NSUUID *)uniqueIdentifier
{
    return RevenantHomeKitUUID(_revenant_identifier);
}

- (NSString *)name
{
    return RevenantHomeKitStringField(RevenantHomeKitRecord(@"zones", _revenant_identifier), @"name", @"");
}

- (NSArray<HMRoom *> *)rooms
{
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *identifier in RevenantHomeKitStringListField(RevenantHomeKitRecord(@"zones", _revenant_identifier), @"rooms"))
        [found addObject:RevenantHomeKitRoom(identifier, _revenant_homeIdentifier)];
    return found;
}

- (void)updateName:(NSString *)name completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!name) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeNilParameter, @"a zone needs a name"));
        return;
    }
    RevenantHomeKitSetField(@"zones", _revenant_identifier, @"name", name);
    RevenantHomeKitFinishError(completionHandler, nil);
}

- (void)addRoom:(HMRoom *)room completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!room) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeNilParameter, @"a room is needed"));
        return;
    }
    NSString *identifier = RevenantHomeKitUUIDString(room.uniqueIdentifier);
    NSMutableDictionary *home = [[RevenantHomeKitStore shared] tableNamed:@"homes"][_revenant_homeIdentifier];
    for (NSString *zoneIdentifier in home[@"zoneOrder"] ?: @[]) {
        if ([zoneIdentifier isEqualToString:_revenant_identifier])
            continue;
        NSArray *members = RevenantHomeKitStringListField(RevenantHomeKitRecord(@"zones", zoneIdentifier), @"rooms");
        if ([members containsObject:identifier]) {
            RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeObjectAlreadyAssociatedToHome,
                                                                            @"the room is already in another zone of this home"));
            return;
        }
    }
    NSMutableDictionary *record = RevenantHomeKitRecord(@"zones", _revenant_identifier);
    NSMutableArray *members = [RevenantHomeKitStringListField(record, @"rooms") mutableCopy];
    if (![members containsObject:identifier]) {
        [members addObject:identifier];
        record[@"rooms"] = members;
        [[RevenantHomeKitStore shared] flushTableNamed:@"zones"];
    }
    RevenantHomeKitFinishError(completionHandler, nil);
}

- (void)removeRoom:(HMRoom *)room completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!room) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeNilParameter, @"a room is needed"));
        return;
    }
    NSMutableDictionary *record = RevenantHomeKitRecord(@"zones", _revenant_identifier);
    NSMutableArray *members = [RevenantHomeKitStringListField(record, @"rooms") mutableCopy];
    [members removeObject:RevenantHomeKitUUIDString(room.uniqueIdentifier)];
    record[@"rooms"] = members;
    [[RevenantHomeKitStore shared] flushTableNamed:@"zones"];
    RevenantHomeKitFinishError(completionHandler, nil);
}

@end

HMZone *RevenantHomeKitZone(NSString *identifier, NSString *homeIdentifier)
{
    HMZone *zone = [[HMZone alloc] revenant_initWithStore:[RevenantHomeKitStore shared] identifier:nil];
    zone.revenant_homeIdentifier = homeIdentifier;
    return zone;
}

#pragma mark - HMUser

@implementation HMUser

@synthesize revenant_identifier = _revenant_identifier, revenant_homeIdentifier = _revenant_homeIdentifier;

REVENANT_HOMEKIT_UNAVAILABLE_INIT

- (instancetype)revenant_initWithStore:(RevenantHomeKitStore *)store identifier:(NSUUID *)identifier __attribute__((objc_method_family(init)))
{
    self = [super init];
    if (self) {
        _revenant_identifier = identifier ? [RevenantHomeKitUUIDString(identifier) copy] : [RevenantHomeKitNewIdentifier() copy];
        RevenantHomeKitRecord(@"users", _revenant_identifier);
    }
    return self;
}

- (NSUUID *)uniqueIdentifier
{
    return RevenantHomeKitUUID(_revenant_identifier);
}

- (NSString *)name
{
    return RevenantHomeKitStringField(RevenantHomeKitRecord(@"users", _revenant_identifier), @"name", @"");
}

- (void)revenant_setName:(NSString *)name
{
    RevenantHomeKitSetField(@"users", _revenant_identifier, @"name", name);
}

@end

HMUser *RevenantHomeKitUser(NSString *identifier, NSString *homeIdentifier)
{
    HMUser *user = [[HMUser alloc] revenant_initWithStore:[RevenantHomeKitStore shared] identifier:nil];
    user.revenant_homeIdentifier = homeIdentifier;
    return user;
}

#pragma mark - HMServiceGroup

@implementation HMServiceGroup

@synthesize revenant_identifier = _revenant_identifier, revenant_homeIdentifier = _revenant_homeIdentifier;

REVENANT_HOMEKIT_NIL_INIT

- (instancetype)revenant_initWithStore:(RevenantHomeKitStore *)store identifier:(NSUUID *)identifier __attribute__((objc_method_family(init)))
{
    self = [super init];
    if (self) {
        _revenant_identifier = identifier ? [RevenantHomeKitUUIDString(identifier) copy] : [RevenantHomeKitNewIdentifier() copy];
        RevenantHomeKitRecord(@"servicegroups", _revenant_identifier);
    }
    return self;
}

- (NSUUID *)uniqueIdentifier
{
    return RevenantHomeKitUUID(_revenant_identifier);
}

- (NSString *)name
{
    return RevenantHomeKitStringField(RevenantHomeKitRecord(@"servicegroups", _revenant_identifier), @"name", @"");
}

- (NSArray<HMService *> *)services
{
    NSMutableDictionary *accessories = [[RevenantHomeKitStore shared] tableNamed:@"accessories"];
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *serviceIdentifier in RevenantHomeKitStringListField(RevenantHomeKitRecord(@"servicegroups", _revenant_identifier), @"services")) {
        for (NSString *accessoryIdentifier in accessories) {
            NSArray *services = accessories[accessoryIdentifier][@"services"] ?: @[];
            if ([services containsObject:serviceIdentifier]) {
                [found addObject:RevenantHomeKitService(serviceIdentifier, accessoryIdentifier)];
                break;
            }
        }
    }
    return found;
}

- (void)updateName:(NSString *)name completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!name) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeNilParameter, @"a service group needs a name"));
        return;
    }
    RevenantHomeKitSetField(@"servicegroups", _revenant_identifier, @"name", name);
    RevenantHomeKitFinishError(completionHandler, nil);
}

- (void)addService:(HMService *)service completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!service) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeNilParameter, @"a service is needed"));
        return;
    }
    NSMutableDictionary *record = RevenantHomeKitRecord(@"servicegroups", _revenant_identifier);
    NSMutableArray *members = [RevenantHomeKitStringListField(record, @"services") mutableCopy];
    NSString *identifier = RevenantHomeKitUUIDString(service.uniqueIdentifier);
    if (![members containsObject:identifier]) {
        [members addObject:identifier];
        record[@"services"] = members;
        [[RevenantHomeKitStore shared] flushTableNamed:@"servicegroups"];
    }
    [self revenant_tellHome:@selector(home:didAddService:toServiceGroup:) object:self block:^(id<HMHomeDelegate> delegate, HMHome *home, id object) {
        [delegate home:home didAddService:service toServiceGroup:(HMServiceGroup *)object];
    }];
    RevenantHomeKitFinishError(completionHandler, nil);
}

- (void)removeService:(HMService *)service completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!service) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeNilParameter, @"a service is needed"));
        return;
    }
    NSMutableDictionary *record = RevenantHomeKitRecord(@"servicegroups", _revenant_identifier);
    NSMutableArray *members = [RevenantHomeKitStringListField(record, @"services") mutableCopy];
    [members removeObject:RevenantHomeKitUUIDString(service.uniqueIdentifier)];
    record[@"services"] = members;
    [[RevenantHomeKitStore shared] flushTableNamed:@"servicegroups"];
    [self revenant_tellHome:@selector(home:didRemoveService:fromServiceGroup:) object:self block:^(id<HMHomeDelegate> delegate, HMHome *home, id object) {
        [delegate home:home didRemoveService:service fromServiceGroup:(HMServiceGroup *)object];
    }];
    RevenantHomeKitFinishError(completionHandler, nil);
}

@end

HMServiceGroup *RevenantHomeKitServiceGroup(NSString *identifier, NSString *homeIdentifier)
{
    HMServiceGroup *group = [[HMServiceGroup alloc] revenant_initWithStore:[RevenantHomeKitStore shared] identifier:nil];
    group.revenant_homeIdentifier = homeIdentifier;
    return group;
}

#pragma mark - HMActionSet

@implementation HMActionSet

@synthesize revenant_identifier = _revenant_identifier, revenant_homeIdentifier = _revenant_homeIdentifier;

REVENANT_HOMEKIT_NIL_INIT

- (void)revenant_setHomeIdentifier:(NSString *)homeIdentifier
{
    self.revenant_homeIdentifier = homeIdentifier;
}

- (instancetype)revenant_initWithStore:(RevenantHomeKitStore *)store identifier:(NSUUID *)identifier __attribute__((objc_method_family(init)))
{
    self = [super init];
    if (self) {
        _revenant_identifier = identifier ? [RevenantHomeKitUUIDString(identifier) copy] : [RevenantHomeKitNewIdentifier() copy];
        RevenantHomeKitRecord(@"actionsets", _revenant_identifier);
    }
    return self;
}

- (NSUUID *)uniqueIdentifier
{
    return RevenantHomeKitUUID(_revenant_identifier);
}

- (NSString *)name
{
    return RevenantHomeKitStringField(RevenantHomeKitRecord(@"actionsets", _revenant_identifier), @"name", @"");
}

- (NSString *)actionSetType
{
    return RevenantHomeKitStringField(RevenantHomeKitRecord(@"actionsets", _revenant_identifier), @"type", HMActionSetTypeUserDefined);
}

- (BOOL)executing
{
    return RevenantHomeKitBoolField(RevenantHomeKitRecord(@"actionsets", _revenant_identifier), @"executing", NO);
}

- (NSDate *)lastExecutionDate
{
    return [RevenantHomeKitRecord(@"actionsets", _revenant_identifier)[@"lastExecutionDate"] copy];
}

- (NSArray<HMAction *> *)actions
{
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *identifier in RevenantHomeKitStringListField(RevenantHomeKitRecord(@"actionsets", _revenant_identifier), @"actions"))
        [found addObject:RevenantHomeKitAction(identifier, _revenant_homeIdentifier)];
    return found;
}

- (void)updateName:(NSString *)name completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!name) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeNilParameter, @"an action set needs a name"));
        return;
    }
    RevenantHomeKitSetField(@"actionsets", _revenant_identifier, @"name", name);
    [self revenant_tellHome:@selector(home:didUpdateNameForActionSet:) object:self block:^(id<HMHomeDelegate> delegate, HMHome *home, id object) {
        [delegate home:home didUpdateNameForActionSet:(HMActionSet *)object];
    }];
    RevenantHomeKitFinishError(completionHandler, nil);
}

- (void)addAction:(HMAction *)action completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!action) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeNilParameter, @"an action is needed"));
        return;
    }
    NSMutableDictionary *record = RevenantHomeKitRecord(@"actionsets", _revenant_identifier);
    NSMutableArray *members = [RevenantHomeKitStringListField(record, @"actions") mutableCopy];
    if (![members containsObject:RevenantHomeKitUUIDString(action.uniqueIdentifier)]) {
        [members addObject:RevenantHomeKitUUIDString(action.uniqueIdentifier)];
        record[@"actions"] = members;
        [[RevenantHomeKitStore shared] flushTableNamed:@"actionsets"];
    }
    [self revenant_tellHome:@selector(home:didUpdateActionsForActionSet:) object:self block:^(id<HMHomeDelegate> delegate, HMHome *home, id object) {
        [delegate home:home didUpdateActionsForActionSet:(HMActionSet *)object];
    }];
    RevenantHomeKitFinishError(completionHandler, nil);
}

- (void)removeAction:(HMAction *)action completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!action) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeNilParameter, @"an action is needed"));
        return;
    }
    NSMutableDictionary *record = RevenantHomeKitRecord(@"actionsets", _revenant_identifier);
    NSMutableArray *members = [RevenantHomeKitStringListField(record, @"actions") mutableCopy];
    [members removeObject:RevenantHomeKitUUIDString(action.uniqueIdentifier)];
    record[@"actions"] = members;
    [[RevenantHomeKitStore shared] flushTableNamed:@"actionsets"];
    [self revenant_tellHome:@selector(home:didUpdateActionsForActionSet:) object:self block:^(id<HMHomeDelegate> delegate, HMHome *home, id object) {
        [delegate home:home didUpdateActionsForActionSet:(HMActionSet *)object];
    }];
    RevenantHomeKitFinishError(completionHandler, nil);
}

@end

HMActionSet *RevenantHomeKitActionSet(NSString *identifier, NSString *homeIdentifier)
{
    HMActionSet *set = [[HMActionSet alloc] revenant_initWithStore:[RevenantHomeKitStore shared] identifier:nil];
    set.revenant_homeIdentifier = homeIdentifier;
    return set;
}

#pragma mark - HMTrigger

@implementation HMTrigger

@synthesize revenant_identifier = _revenant_identifier, revenant_homeIdentifier = _revenant_homeIdentifier;

- (instancetype)revenant_initWithStore:(RevenantHomeKitStore *)store identifier:(NSUUID *)identifier __attribute__((objc_method_family(init)))
{
    (void)store;
    self = [super init];
    if (self) {
        _revenant_identifier = identifier ? [RevenantHomeKitUUIDString(identifier) copy] : [RevenantHomeKitNewIdentifier() copy];
        RevenantHomeKitSetField(@"triggers", _revenant_identifier, @"kind", @"timer");
        RevenantHomeKitSetField(@"triggers", _revenant_identifier, @"actionSets", @[]);
    }
    return self;
}

- (NSUUID *)uniqueIdentifier
{
    return RevenantHomeKitUUID(_revenant_identifier);
}

- (NSString *)name
{
    return RevenantHomeKitStringField(RevenantHomeKitRecord(@"triggers", _revenant_identifier), @"name", @"");
}

- (BOOL)enabled
{
    return RevenantHomeKitBoolField(RevenantHomeKitRecord(@"triggers", _revenant_identifier), @"enabled", NO);
}

- (NSDate *)lastFireDate
{
    return [RevenantHomeKitRecord(@"triggers", _revenant_identifier)[@"lastFireDate"] copy];
}

- (NSArray<HMActionSet *> *)actionSets
{
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *identifier in RevenantHomeKitStringListField(RevenantHomeKitRecord(@"triggers", _revenant_identifier), @"actionSets"))
        [found addObject:RevenantHomeKitActionSet(identifier, _revenant_homeIdentifier)];
    return found;
}

- (void)updateName:(NSString *)name completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!name) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeNilParameter, @"a trigger needs a name"));
        return;
    }
    RevenantHomeKitSetField(@"triggers", _revenant_identifier, @"name", name);
    [self revenant_tellHome:@selector(home:didUpdateNameForTrigger:) object:self block:^(id<HMHomeDelegate> delegate, HMHome *home, id object) {
        [delegate home:home didUpdateNameForTrigger:(HMTrigger *)object];
    }];
    RevenantHomeKitFinishError(completionHandler, nil);
}

- (void)enable:(BOOL)enabled completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    RevenantHomeKitSetField(@"triggers", _revenant_identifier, @"enabled", @(enabled));
    RevenantHomeKitFinishError(completionHandler, nil);
}

- (void)addActionSet:(HMActionSet *)actionSet completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!actionSet) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeNilParameter, @"an action set is needed"));
        return;
    }
    NSMutableDictionary *record = RevenantHomeKitRecord(@"triggers", _revenant_identifier);
    NSMutableArray *members = [RevenantHomeKitStringListField(record, @"actionSets") mutableCopy];
    if (![members containsObject:RevenantHomeKitUUIDString(actionSet.uniqueIdentifier)]) {
        [members addObject:RevenantHomeKitUUIDString(actionSet.uniqueIdentifier)];
        record[@"actionSets"] = members;
        [[RevenantHomeKitStore shared] flushTableNamed:@"triggers"];
    }
    RevenantHomeKitFinishError(completionHandler, nil);
}

- (void)removeActionSet:(HMActionSet *)actionSet completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!actionSet) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeNilParameter, @"an action set is needed"));
        return;
    }
    NSMutableDictionary *record = RevenantHomeKitRecord(@"triggers", _revenant_identifier);
    NSMutableArray *members = [RevenantHomeKitStringListField(record, @"actionSets") mutableCopy];
    [members removeObject:RevenantHomeKitUUIDString(actionSet.uniqueIdentifier)];
    record[@"actionSets"] = members;
    [[RevenantHomeKitStore shared] flushTableNamed:@"triggers"];
    RevenantHomeKitFinishError(completionHandler, nil);
}

@end

HMTrigger *RevenantHomeKitTrigger(NSString *identifier, NSString *homeIdentifier)
{
    HMTrigger *trigger = [[HMTrigger alloc] revenant_initWithStore:[RevenantHomeKitStore shared] identifier:nil];
    trigger.revenant_homeIdentifier = homeIdentifier;
    RevenantHomeKitSetField(@"triggers", trigger.revenant_identifier, @"kind", @"timer");
    return trigger;
}

#pragma mark - HMTimerTrigger

@implementation HMTimerTrigger

REVENANT_HOMEKIT_NIL_INIT
- (instancetype)initWithName:(NSString *)name fireDate:(NSDate *)fireDate recurrence:(NSDateComponents *)recurrence
{
    self = [super revenant_initWithStore:[RevenantHomeKitStore shared] identifier:nil];
    if (self) {
        [self revenant_applyName:name];
        [self revenant_applyFireDate:fireDate];
        [self revenant_applyRecurrence:recurrence];
    }
    return self;
}

- (instancetype)initWithName:(NSString *)name fireDate:(NSDate *)fireDate timeZone:(NSTimeZone *)timeZone
                 recurrence:(NSDateComponents *)recurrence recurrenceCalendar:(NSCalendar *)recurrenceCalendar
{
    self = [super revenant_initWithStore:[RevenantHomeKitStore shared] identifier:nil];
    if (self) {
        [self revenant_applyName:name];
        [self revenant_applyFireDate:fireDate];
        RevenantHomeKitSetField(@"triggers", self.revenant_identifier, @"timeZone", timeZone.name);
        [self revenant_applyRecurrence:recurrence];
        NSString *identifier = nil;
        if ([recurrenceCalendar respondsToSelector:@selector(calendarIdentifier)])
            identifier = [recurrenceCalendar valueForKey:@"calendarIdentifier"];
        RevenantHomeKitSetField(@"triggers", self.revenant_identifier, @"recurrenceCalendar", identifier);
    }
    return self;
}

- (NSDate *)fireDate
{
    return [RevenantHomeKitRecord(@"triggers", self.revenant_identifier)[@"fireDate"] copy];
}

- (NSTimeZone *)timeZone
{
    NSString *name = RevenantHomeKitRecord(@"triggers", self.revenant_identifier)[@"timeZone"];
    return name ? [NSTimeZone timeZoneWithName:name] : [NSTimeZone localTimeZone];
}

- (NSDateComponents *)recurrence
{
    return [RevenantHomeKitRecord(@"triggers", self.revenant_identifier)[@"recurrence"] copy];
}

- (NSCalendar *)recurrenceCalendar
{
    NSString *identifier = RevenantHomeKitRecord(@"triggers", self.revenant_identifier)[@"recurrenceCalendar"];
    if (identifier && [NSCalendar respondsToSelector:@selector(calendarWithIdentifier:)])
        return [NSCalendar calendarWithIdentifier:identifier];
    return [NSCalendar currentCalendar];
}

- (void)updateFireDate:(NSDate *)fireDate completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!fireDate) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeNilParameter, @"a fire date is needed"));
        return;
    }
    if ([fireDate compare:[NSDate date]] == NSOrderedAscending) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeFireDateInPast, @"the fire date is in the past"));
        return;
    }
    [self revenant_applyFireDate:fireDate];
    RevenantHomeKitFinishError(completionHandler, nil);
}

- (void)updateRecurrence:(NSDateComponents *)recurrence completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!recurrence) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeNilParameter, @"a recurrence is needed"));
        return;
    }
    [self revenant_applyRecurrence:recurrence];
    RevenantHomeKitFinishError(completionHandler, nil);
}

- (void)updateTimeZone:(NSTimeZone *)timeZone completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!timeZone) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeNilParameter, @"a time zone is needed"));
        return;
    }
    RevenantHomeKitSetField(@"triggers", self.revenant_identifier, @"timeZone", timeZone.name);
    RevenantHomeKitFinishError(completionHandler, nil);
}

- (void)revenant_applyName:(NSString *)name
{
    if (name)
        RevenantHomeKitSetField(@"triggers", self.revenant_identifier, @"name", name);
}

- (void)revenant_applyFireDate:(NSDate *)fireDate
{
    if (fireDate)
        RevenantHomeKitSetField(@"triggers", self.revenant_identifier, @"fireDate", fireDate);
}

- (void)revenant_applyRecurrence:(NSDateComponents *)recurrence
{
    if (!recurrence)
        return;
    NSMutableDictionary *fields = [NSMutableDictionary dictionary];
#define REVENANT_RECURRENCE_FIELD(name) do { NSInteger value = [recurrence name]; \
    if (value != NSDateComponentUndefined) fields[@#name] = @(value); } while (0)
    REVENANT_RECURRENCE_FIELD(era); REVENANT_RECURRENCE_FIELD(year); REVENANT_RECURRENCE_FIELD(month);
    REVENANT_RECURRENCE_FIELD(day); REVENANT_RECURRENCE_FIELD(hour); REVENANT_RECURRENCE_FIELD(minute);
    REVENANT_RECURRENCE_FIELD(second); REVENANT_RECURRENCE_FIELD(weekday);
    REVENANT_RECURRENCE_FIELD(weekdayOrdinal); REVENANT_RECURRENCE_FIELD(quarter);
    REVENANT_RECURRENCE_FIELD(weekOfMonth); REVENANT_RECURRENCE_FIELD(weekOfYear);
    REVENANT_RECURRENCE_FIELD(yearForWeekOfYear);
#undef REVENANT_RECURRENCE_FIELD
    RevenantHomeKitSetField(@"triggers", self.revenant_identifier, @"recurrence", fields);
}

@end

HMTimerTrigger *RevenantHomeKitTimerTrigger(NSString *identifier, NSString *homeIdentifier)
{
    HMTimerTrigger *trigger = [[HMTimerTrigger alloc] revenant_initWithStore:[RevenantHomeKitStore shared] identifier:nil];
    trigger.revenant_homeIdentifier = homeIdentifier;
    RevenantHomeKitSetField(@"triggers", trigger.revenant_identifier, @"kind", @"timer");
    return trigger;
}
