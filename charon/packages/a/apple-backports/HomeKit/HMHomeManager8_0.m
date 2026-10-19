#import "CharonHomeKitInternal.h"

#pragma mark - HMHome

@implementation HMHome
@synthesize charon_identifier = _charon_identifier, charon_homeIdentifier = _charon_homeIdentifier, charon_delegate = _charon_delegate;

CHARON_HOMEKIT_NIL_INIT

- (instancetype)charon_initWithStore:(CharonHomeKitStore *)store identifier:(NSUUID *)identifier __attribute__((objc_method_family(init)))
{
    self = [super init];
    if (self) {
        _charon_identifier = identifier ? [CharonHomeKitUUIDString(identifier) copy]
                                        : [CharonHomeKitNewIdentifier() copy];
        CharonHomeKitRecord(@"homes", _charon_identifier);
    }
    return self;
}

- (NSUUID *)uniqueIdentifier
{
    return CharonHomeKitUUID(_charon_identifier);
}

- (NSString *)name
{
    return CharonHomeKitStringField(CharonHomeKitRecord(@"homes", _charon_identifier), @"name", @"");
}

- (BOOL)primary
{
    return CharonHomeKitBoolField(CharonHomeKitRecord(@"homes", _charon_identifier), @"primary", NO);
}

- (id<HMHomeDelegate>)delegate
{
    return _charon_delegate;
}

- (void)setDelegate:(id<HMHomeDelegate>)delegate
{
    _charon_delegate = delegate;
}

- (HMUser *)currentUser
{
    NSString *current = CharonHomeKitRecord(@"homes", _charon_identifier)[@"currentUser"];
    return current ? CharonHomeKitUser(current, _charon_identifier) : nil;
}

- (HMHomeHubState)homeHubState
{
    return HMHomeHubStateNotAvailable;
}

- (BOOL)supportsAddingNetworkRouter
{
    return NO;
}

- (NSArray<HMRoom *> *)rooms
{
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *identifier in CharonHomeKitStringListField(CharonHomeKitRecord(@"homes", _charon_identifier), @"roomOrder"))
        [found addObject:CharonHomeKitRoom(identifier, _charon_identifier)];
    return found;
}

- (HMRoom *)roomForEntireHome
{
    NSMutableDictionary *record = CharonHomeKitRecord(@"homes", _charon_identifier);
    NSString *identifier = record[@"entireHomeRoom"];
    if (identifier)
        return CharonHomeKitRoom(identifier, _charon_identifier);
    HMRoom *room = [[HMRoom alloc] charon_initWithStore:[CharonHomeKitStore shared] identifier:nil];
    [room updateName:@"Home" completionHandler:nil];
    record[@"entireHomeRoom"] = CharonHomeKitUUIDString(room.uniqueIdentifier);
    NSMutableArray *order = [CharonHomeKitStringListField(record, @"roomOrder") mutableCopy];
    [order addObject:CharonHomeKitUUIDString(room.uniqueIdentifier)];
    record[@"roomOrder"] = order;
    [[CharonHomeKitStore shared] flushTableNamed:@"homes"];
    return room;
}

- (NSArray<HMZone *> *)zones
{
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *identifier in CharonHomeKitStringListField(CharonHomeKitRecord(@"homes", _charon_identifier), @"zoneOrder"))
        [found addObject:CharonHomeKitZone(identifier, _charon_identifier)];
    return found;
}

- (NSArray<HMUser *> *)users
{
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *identifier in CharonHomeKitStringListField(CharonHomeKitRecord(@"homes", _charon_identifier), @"userOrder"))
        [found addObject:CharonHomeKitUser(identifier, _charon_identifier)];
    return found;
}

- (NSArray<HMServiceGroup *> *)serviceGroups
{
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *identifier in CharonHomeKitStringListField(CharonHomeKitRecord(@"homes", _charon_identifier), @"serviceGroupOrder"))
        [found addObject:CharonHomeKitServiceGroup(identifier, _charon_identifier)];
    return found;
}

- (NSArray<HMAccessory *> *)accessories
{
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *identifier in CharonHomeKitStringListField(CharonHomeKitRecord(@"homes", _charon_identifier), @"accessoryOrder"))
        [found addObject:CharonHomeKitAccessory(identifier, _charon_identifier)];
    return found;
}

- (NSArray<HMTrigger *> *)triggers
{
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *identifier in CharonHomeKitStringListField(CharonHomeKitRecord(@"homes", _charon_identifier), @"triggerOrder")) {
        [found addObject:CharonHomeKitTimerTrigger(identifier, _charon_identifier)];
    }
    return found;
}

- (NSArray<HMActionSet *> *)actionSets
{
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *identifier in CharonHomeKitStringListField(CharonHomeKitRecord(@"homes", _charon_identifier), @"actionSetOrder"))
        [found addObject:CharonHomeKitActionSet(identifier, _charon_identifier)];
    return found;
}

- (HMActionSet *)builtinActionSetOfType:(NSString *)type
{
    for (HMActionSet *set in self.actionSets) {
        if ([set.actionSetType isEqualToString:type])
            return set;
    }
    return nil;
}

- (void)updateName:(NSString *)name completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!name) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeNilParameter, @"a home needs a name"));
        return;
    }
    CharonHomeKitSetField(@"homes", _charon_identifier, @"name", name);
    HMHome *home = self;
    CharonHomeKitTell(_charon_delegate, @selector(homeDidUpdateName:), ^(id target) {
        [(id<HMHomeDelegate>)target homeDidUpdateName:home];
    });
    CharonHomeKitFinishError(completionHandler, nil);
}

- (void)addRoomWithName:(NSString *)name completionHandler:(void (^)(HMRoom * _Nullable room, NSError * _Nullable error))completionHandler
{
    if (!name) {
        CharonHomeKitFinish(completionHandler, nil, CharonHomeKitError(HMErrorCodeNilParameter, @"a room needs a name"));
        return;
    }
    if ([self charon_nameInUse:name]) {
        CharonHomeKitFinish(completionHandler, nil,
                            CharonHomeKitError(HMErrorCodeObjectWithSimilarNameExistsInHome,
                                               @"this home already has a room, zone or service group with that name"));
        return;
    }
    HMRoom *room = [[HMRoom alloc] charon_initWithStore:[CharonHomeKitStore shared] identifier:nil];
    [room updateName:name completionHandler:nil];
    [self charon_append:CharonHomeKitUUIDString(room.uniqueIdentifier) to:@"roomOrder"];
    HMHome *home = self;
    CharonHomeKitTell(_charon_delegate, @selector(home:didAddRoom:), ^(id target) {
        [(id<HMHomeDelegate>)target home:home didAddRoom:room];
    });
    CharonHomeKitFinish(completionHandler, room, nil);
}

- (void)addZoneWithName:(NSString *)name completionHandler:(void (^)(HMZone * _Nullable zone, NSError * _Nullable error))completionHandler
{
    if (!name) {
        CharonHomeKitFinish(completionHandler, nil, CharonHomeKitError(HMErrorCodeNilParameter, @"a zone needs a name"));
        return;
    }
    if ([self charon_nameInUse:name]) {
        CharonHomeKitFinish(completionHandler, nil,
                            CharonHomeKitError(HMErrorCodeObjectWithSimilarNameExistsInHome,
                                               @"this home already has a room, zone or service group with that name"));
        return;
    }
    HMZone *zone = [[HMZone alloc] charon_initWithStore:[CharonHomeKitStore shared] identifier:nil];
    [zone updateName:name completionHandler:nil];
    [self charon_append:CharonHomeKitUUIDString(zone.uniqueIdentifier) to:@"zoneOrder"];
    HMHome *home = self;
    CharonHomeKitTell(_charon_delegate, @selector(home:didAddZone:), ^(id target) {
        [(id<HMHomeDelegate>)target home:home didAddZone:zone];
    });
    CharonHomeKitFinish(completionHandler, zone, nil);
}

- (void)addServiceGroupWithName:(NSString *)name completionHandler:(void (^)(HMServiceGroup * _Nullable group, NSError * _Nullable error))completionHandler
{
    if (!name) {
        CharonHomeKitFinish(completionHandler, nil, CharonHomeKitError(HMErrorCodeNilParameter, @"a service group needs a name"));
        return;
    }
    if ([self charon_nameInUse:name]) {
        CharonHomeKitFinish(completionHandler, nil,
                            CharonHomeKitError(HMErrorCodeObjectWithSimilarNameExistsInHome,
                                               @"this home already has a room, zone or service group with that name"));
        return;
    }
    HMServiceGroup *group = [[HMServiceGroup alloc] charon_initWithStore:[CharonHomeKitStore shared] identifier:nil];
    [group updateName:name completionHandler:nil];
    [self charon_append:CharonHomeKitUUIDString(group.uniqueIdentifier) to:@"serviceGroupOrder"];
    HMHome *home = self;
    CharonHomeKitTell(_charon_delegate, @selector(home:didAddServiceGroup:), ^(id target) {
        [(id<HMHomeDelegate>)target home:home didAddServiceGroup:group];
    });
    CharonHomeKitFinish(completionHandler, group, nil);
}

- (void)addUserWithCompletionHandler:(void (^)(HMUser * _Nullable user, NSError * _Nullable error))completionHandler
{
    HMUser *user = [[HMUser alloc] charon_initWithStore:[CharonHomeKitStore shared] identifier:nil];
    [user charon_setName:@"Me"];
    [self charon_append:CharonHomeKitUUIDString(user.uniqueIdentifier) to:@"userOrder"];
    CharonHomeKitSetField(@"homes", _charon_identifier, @"currentUser", CharonHomeKitUUIDString(user.uniqueIdentifier));
    HMHome *home = self;
    CharonHomeKitTell(_charon_delegate, @selector(home:didAddUser:), ^(id target) {
        [(id<HMHomeDelegate>)target home:home didAddUser:user];
    });
    CharonHomeKitFinish(completionHandler, user,
                        CharonHomeKitError(HMErrorCodeUserManagementFailed,
                                           @"there is no Apple ID on this release to invite a person from, so the user is the one this process runs as"));
}

- (void)manageUsersWithCompletionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    CharonHomeKitFinishError(completionHandler,
                             CharonHomeKitError(HMErrorCodeUserManagementFailed,
                                                @"managing users needs an iCloud account, which this release has no service for"));
}

- (HMHomeAccessControl *)homeAccessControlForUser:(HMUser *)user
{
    if (!user)
        user = self.currentUser;
    HMUser *wanted = user;
    if (!wanted)
        return nil;
    for (HMUser *held in self.users) {
        if ([held.uniqueIdentifier isEqual:wanted.uniqueIdentifier])
            return CharonHomeKitHomeAccessControl(self, held);
    }
    return nil;
}

- (void)addAccessory:(HMAccessory *)accessory completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!accessory) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeNilParameter, @"an accessory is needed"));
        return;
    }
    if ([self charon_holdsAccessory:accessory]) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeObjectAlreadyAssociatedToHome,
                                                                        @"the accessory is already in a home"));
        return;
    }
    CharonHomeKitFinishError(completionHandler, CharonHomeKitErrorForAccessory(HMErrorCodeAccessoryPairingFailed, accessory,
                                                                                @"adding an accessory needs a completed HAP pair-setup, which this port does not carry"));
}

- (void)removeAccessory:(HMAccessory *)accessory completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!accessory) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeNilParameter, @"an accessory is needed"));
        return;
    }
    if (![self charon_holdsAccessory:accessory]) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeObjectNotAssociatedToAnyHome,
                                                                        @"the accessory is not in this home"));
        return;
    }
    NSMutableArray *order = [self charon_orderFor:@"accessoryOrder"];
    [order removeObject:CharonHomeKitUUIDString(accessory.identifier)];
    [self charon_setOrder:order for:@"accessoryOrder"];
    HMHome *home = self;
    CharonHomeKitTell(_charon_delegate, @selector(home:didRemoveAccessory:), ^(id target) {
        [(id<HMHomeDelegate>)target home:home didRemoveAccessory:accessory];
    });
    CharonHomeKitFinishError(completionHandler, nil);
}

- (void)assignAccessory:(HMAccessory *)accessory toRoom:(HMRoom *)room completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!accessory || !room) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeNilParameter, @"an accessory and a room are needed"));
        return;
    }
    if (![self charon_holdsAccessory:accessory]) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeObjectNotAssociatedToAnyHome,
                                                                        @"the accessory is not in this home"));
        return;
    }
    if (room == self.roomForEntireHome) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeRoomForHomeCannotBeUpdated,
                                                                        @"the room for the entire home cannot hold one accessory"));
        return;
    }
    [accessory charon_setRoom:CharonHomeKitUUIDString(room.uniqueIdentifier)];
    HMHome *home = self;
    CharonHomeKitTell(_charon_delegate, @selector(home:didUpdateRoom:forAccessory:), ^(id target) {
        [(id<HMHomeDelegate>)target home:home didUpdateRoom:room forAccessory:accessory];
    });
    CharonHomeKitFinishError(completionHandler, nil);
}

- (void)unblockAccessory:(HMAccessory *)accessory completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!accessory) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeNilParameter, @"an accessory is needed"));
        return;
    }
    CharonHomeKitSetField(@"accessories", CharonHomeKitUUIDString(accessory.identifier), @"blocked", @NO);
    HMHome *home = self;
    CharonHomeKitTell(_charon_delegate, @selector(home:didUnblockAccessory:), ^(id target) {
        [(id<HMHomeDelegate>)target home:home didUnblockAccessory:accessory];
    });
    CharonHomeKitFinishError(completionHandler, nil);
}

- (void)removeRoom:(HMRoom *)room completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!room) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeNilParameter, @"a room is needed"));
        return;
    }
    if (room == self.roomForEntireHome) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeRoomForHomeCannotBeUpdated,
                                                                        @"the room for the entire home cannot be removed"));
        return;
    }
    NSMutableArray *order = [self charon_orderFor:@"roomOrder"];
    if (![order containsObject:CharonHomeKitUUIDString(room.uniqueIdentifier)]) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeObjectNotAssociatedToAnyHome,
                                                                        @"the room is not in this home"));
        return;
    }
    [order removeObject:CharonHomeKitUUIDString(room.uniqueIdentifier)];
    [self charon_setOrder:order for:@"roomOrder"];
    HMHome *home = self;
    CharonHomeKitTell(_charon_delegate, @selector(home:didRemoveRoom:), ^(id target) {
        [(id<HMHomeDelegate>)target home:home didRemoveRoom:room];
    });
    CharonHomeKitFinishError(completionHandler, nil);
}

- (void)removeZone:(HMZone *)zone completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (![self charon_remove:CharonHomeKitUUIDString(zone.uniqueIdentifier) from:@"zoneOrder" named:@"the zone"]) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeObjectNotAssociatedToAnyHome,
                                                                        @"the zone is not in this home"));
        return;
    }
    HMHome *home = self;
    CharonHomeKitTell(_charon_delegate, @selector(home:didRemoveZone:), ^(id target) {
        [(id<HMHomeDelegate>)target home:home didRemoveZone:zone];
    });
    CharonHomeKitFinishError(completionHandler, nil);
}

- (void)removeServiceGroup:(HMServiceGroup *)group completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (![self charon_remove:CharonHomeKitUUIDString(group.uniqueIdentifier) from:@"serviceGroupOrder" named:@"the service group"]) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeObjectNotAssociatedToAnyHome,
                                                                        @"the service group is not in this home"));
        return;
    }
    HMHome *home = self;
    CharonHomeKitTell(_charon_delegate, @selector(home:didRemoveServiceGroup:), ^(id target) {
        [(id<HMHomeDelegate>)target home:home didRemoveServiceGroup:group];
    });
    CharonHomeKitFinishError(completionHandler, nil);
}

- (void)removeUser:(HMUser *)user completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!user) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeNilParameter, @"a user is needed"));
        return;
    }
    NSMutableArray *order = [self charon_orderFor:@"userOrder"];
    if (![order containsObject:CharonHomeKitUUIDString(user.uniqueIdentifier)]) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeObjectNotAssociatedToAnyHome,
                                                                        @"the user is not in this home"));
        return;
    }
    if (order.count == 1) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeCannotRemoveBuiltinActionSet,
                                                                        @"a home keeps at least one user"));
        return;
    }
    [order removeObject:CharonHomeKitUUIDString(user.uniqueIdentifier)];
    [self charon_setOrder:order for:@"userOrder"];
    if ([CharonHomeKitRecord(@"homes", _charon_identifier)[@"currentUser"] isEqualToString:CharonHomeKitUUIDString(user.uniqueIdentifier)])
        CharonHomeKitSetField(@"homes", _charon_identifier, @"currentUser", order.firstObject);
    HMHome *home = self;
    CharonHomeKitTell(_charon_delegate, @selector(home:didRemoveUser:), ^(id target) {
        [(id<HMHomeDelegate>)target home:home didRemoveUser:user];
    });
    CharonHomeKitFinishError(completionHandler, nil);
}

- (NSArray<HMService *> *)servicesWithTypes:(NSArray<NSString *> *)types
{
    NSMutableArray *found = [NSMutableArray array];
    for (HMAccessory *accessory in self.accessories) {
        for (HMService *service in accessory.services) {
            if ([types containsObject:service.serviceType])
                [found addObject:service];
        }
    }
    return found;
}

- (void)addTrigger:(HMTrigger *)trigger completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!trigger) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeNilParameter, @"a trigger is needed"));
        return;
    }
    [trigger charon_setHomeIdentifier:_charon_identifier];
    [self charon_append:CharonHomeKitUUIDString(trigger.uniqueIdentifier) to:@"triggerOrder"];
    HMHome *home = self;
    CharonHomeKitTell(_charon_delegate, @selector(home:didAddTrigger:), ^(id target) {
        [(id<HMHomeDelegate>)target home:home didAddTrigger:trigger];
    });
    CharonHomeKitFinishError(completionHandler, nil);
}

- (void)removeTrigger:(HMTrigger *)trigger completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!trigger) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeNilParameter, @"a trigger is needed"));
        return;
    }
    [self charon_remove:CharonHomeKitUUIDString(trigger.uniqueIdentifier) from:@"triggerOrder" named:@"the trigger"];
    HMHome *home = self;
    CharonHomeKitTell(_charon_delegate, @selector(home:didRemoveTrigger:), ^(id target) {
        [(id<HMHomeDelegate>)target home:home didRemoveTrigger:trigger];
    });
    CharonHomeKitFinishError(completionHandler, nil);
}

- (void)addActionSetWithName:(NSString *)name completionHandler:(void (^)(HMActionSet * _Nullable actionSet, NSError * _Nullable error))completionHandler
{
    if (!name) {
        CharonHomeKitFinish(completionHandler, nil, CharonHomeKitError(HMErrorCodeNilParameter, @"an action set needs a name"));
        return;
    }
    HMActionSet *set = [[HMActionSet alloc] charon_initWithStore:[CharonHomeKitStore shared] identifier:nil];
    [set updateName:name completionHandler:nil];
    [set charon_setHomeIdentifier:_charon_identifier];
    [self charon_append:CharonHomeKitUUIDString(set.uniqueIdentifier) to:@"actionSetOrder"];
    HMHome *home = self;
    CharonHomeKitTell(_charon_delegate, @selector(home:didAddActionSet:), ^(id target) {
        [(id<HMHomeDelegate>)target home:home didAddActionSet:set];
    });
    CharonHomeKitFinish(completionHandler, set, nil);
}

- (void)removeActionSet:(HMActionSet *)actionSet completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!actionSet) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeNilParameter, @"an action set is needed"));
        return;
    }
    if ([actionSet.actionSetType isEqualToString:HMActionSetTypeWakeUp] ||
        [actionSet.actionSetType isEqualToString:HMActionSetTypeSleep] ||
        [actionSet.actionSetType isEqualToString:HMActionSetTypeHomeArrival] ||
        [actionSet.actionSetType isEqualToString:HMActionSetTypeHomeDeparture]) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeCannotRemoveBuiltinActionSet,
                                                                        @"a built-in action set cannot be removed"));
        return;
    }
    [self charon_remove:CharonHomeKitUUIDString(actionSet.uniqueIdentifier) from:@"actionSetOrder" named:@"the action set"];
    HMHome *home = self;
    CharonHomeKitTell(_charon_delegate, @selector(home:didRemoveActionSet:), ^(id target) {
        [(id<HMHomeDelegate>)target home:home didRemoveActionSet:actionSet];
    });
    CharonHomeKitFinishError(completionHandler, nil);
}

- (void)charon_setHomeIdentifier:(NSString *)homeIdentifier
{
    self.charon_homeIdentifier = homeIdentifier;
}

- (NSMutableArray *)charon_orderFor:(NSString *)key
{
    return [CharonHomeKitStringListField(CharonHomeKitRecord(@"homes", _charon_identifier), key) mutableCopy];
}

- (void)charon_setOrder:(NSArray *)order for:(NSString *)key
{
    CharonHomeKitSetField(@"homes", _charon_identifier, key, order);
    [[CharonHomeKitStore shared] flushTableNamed:@"homes"];
}

- (void)charon_append:(NSString *)identifier to:(NSString *)key
{
    NSMutableArray *order = [self charon_orderFor:key];
    if (![order containsObject:identifier]) {
        [order addObject:identifier];
        [self charon_setOrder:order for:key];
    }
}

- (BOOL)charon_remove:(NSString *)identifier from:(NSString *)key named:(NSString *)what
{
    NSMutableArray *order = [self charon_orderFor:key];
    BOOL held = [order containsObject:identifier];
    if (held) {
        [order removeObject:identifier];
        [self charon_setOrder:order for:key];
    }
    (void)what;
    return held;
}

- (BOOL)charon_holdsAccessory:(HMAccessory *)accessory
{
    for (HMAccessory *held in self.accessories) {
        if ([held.identifier isEqual:accessory.identifier])
            return YES;
    }
    return NO;
}

- (BOOL)charon_nameInUse:(NSString *)name
{
    for (HMRoom *room in self.rooms) {
        if ([room.name isEqualToString:name])
            return YES;
    }
    for (HMZone *zone in self.zones) {
        if ([zone.name isEqualToString:name])
            return YES;
    }
    for (HMServiceGroup *group in self.serviceGroups) {
        if ([group.name isEqualToString:name])
            return YES;
    }
    return NO;
}

@end

#pragma mark - HMHomeManager

@implementation HMHomeManager
@synthesize charon_delegate = _charon_delegate;

- (instancetype)init
{
    return [super init];
}

- (id<HMHomeManagerDelegate>)delegate
{
    return _charon_delegate;
}

- (void)setDelegate:(id<HMHomeManagerDelegate>)delegate
{
    _charon_delegate = delegate;
}

- (HMHomeManagerAuthorizationStatus)authorizationStatus
{
    return HMHomeManagerAuthorizationStatusDetermined;
}

- (NSArray<HMHome *> *)homes
{
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *identifier in CharonHomeKitStringListField(CharonHomeKitRecord(@"homes", CharonHomeKitHomeOrderKey), @"homes"))
        [found addObject:CharonHomeKitHome(identifier)];
    return found;
}

- (HMHome *)primaryHome
{
    for (HMHome *home in self.homes) {
        if (home.primary)
            return home;
    }
    return self.homes.firstObject;
}

- (void)addHomeWithName:(NSString *)name completionHandler:(void (^)(HMHome * _Nullable home, NSError * _Nullable error))completionHandler
{
    if (!name) {
        CharonHomeKitFinish(completionHandler, nil, CharonHomeKitError(HMErrorCodeNilParameter, @"a home needs a name"));
        return;
    }
    for (HMHome *home in self.homes) {
        if ([home.name isEqualToString:name]) {
            CharonHomeKitFinish(completionHandler, nil, CharonHomeKitError(HMErrorCodeHomeWithSimilarNameExists,
                                                                            @"there is already a home with that name"));
            return;
        }
    }
    HMHome *home = [[HMHome alloc] charon_initWithStore:[CharonHomeKitStore shared] identifier:nil];
    [home updateName:name completionHandler:nil];
    CharonHomeKitSetField(@"homes", CharonHomeKitUUIDString(home.uniqueIdentifier), @"primary", @(self.homes.count == 0));

    CharonHomeKitStore *store = [CharonHomeKitStore shared];
    NSMutableDictionary *homes = [store tableNamed:@"homes"];
    NSMutableArray *order = [homes[CharonHomeKitHomeOrderKey][@"homes"] mutableCopy] ?: [NSMutableArray array];
    [order addObject:CharonHomeKitUUIDString(home.uniqueIdentifier)];
    homes[CharonHomeKitHomeOrderKey] = @{@"homes": order};
    [store flushTableNamed:@"homes"];

    HMHomeManager *manager = self;
    CharonHomeKitTell(_charon_delegate, @selector(homeManager:didAddHome:), ^(id target) {
        [(id<HMHomeManagerDelegate>)target homeManager:manager didAddHome:home];
    });
    CharonHomeKitFinish(completionHandler, home, nil);
}

- (void)removeHome:(HMHome *)home completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!home) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeNilParameter, @"a home is needed"));
        return;
    }
    if (![self.homes containsObject:CharonHomeKitHome(CharonHomeKitUUIDString(home.uniqueIdentifier))]) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeObjectNotAssociatedToAnyHome,
                                                                        @"the home is not one of this manager's"));
        return;
    }
    CharonHomeKitStore *store = [CharonHomeKitStore shared];
    NSMutableDictionary *homes = [store tableNamed:@"homes"];
    NSMutableArray *order = [homes[CharonHomeKitHomeOrderKey][@"homes"] mutableCopy] ?: [NSMutableArray array];
    [order removeObject:CharonHomeKitUUIDString(home.uniqueIdentifier)];
    homes[CharonHomeKitHomeOrderKey] = @{@"homes": order};
    [homes removeObjectForKey:CharonHomeKitUUIDString(home.uniqueIdentifier)];
    [store flushTableNamed:@"homes"];
    HMHomeManager *manager = self;
    CharonHomeKitTell(_charon_delegate, @selector(homeManager:didRemoveHome:), ^(id target) {
        [(id<HMHomeManagerDelegate>)target homeManager:manager didRemoveHome:home];
    });
    CharonHomeKitFinishError(completionHandler, nil);
}

- (void)updatePrimaryHome:(HMHome *)primaryHome completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!primaryHome) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeNilParameter, @"a home is needed"));
        return;
    }
    for (HMHome *home in self.homes)
        CharonHomeKitSetField(@"homes", CharonHomeKitUUIDString(home.uniqueIdentifier), @"primary", @(home == primaryHome));
    CharonHomeKitTell(_charon_delegate, @selector(homeManagerDidUpdatePrimaryHome:), ^(id target) {
        [(id<HMHomeManagerDelegate>)target homeManagerDidUpdatePrimaryHome:self];
    });
    CharonHomeKitFinishError(completionHandler, nil);
}

- (void)findVendorAccessoryWithHAPPublicKey:(NSData *)publicKey completionHandler:(void (^)(HMAccessory * _Nullable accessory, NSError * _Nullable error))completionHandler
{
    if (!publicKey.length) {
        CharonHomeKitFinish(completionHandler, nil, CharonHomeKitError(HMErrorCodeNilParameter, @"a public key is needed"));
        return;
    }
    NSMutableDictionary *pairings = [[CharonHomeKitStore shared] tableNamed:@"pairings"];
    for (NSString *identifier in pairings) {
        if ([pairings[identifier][@"ltpk"] isEqualToData:publicKey]) {
            for (HMHome *home in self.homes) {
                for (HMAccessory *accessory in home.accessories) {
                    if ([CharonHomeKitUUIDString(accessory.identifier) isEqualToString:identifier]) {
                        CharonHomeKitFinish(completionHandler, accessory, nil);
                        return;
                    }
                }
            }
        }
    }
    CharonHomeKitFinish(completionHandler, nil, CharonHomeKitError(HMErrorCodeNotFound,
                                                                    @"no paired accessory has that public key"));
}

@end
