#import "RevenantHomeKitInternal.h"

#pragma mark - HMHome

@implementation HMHome
@synthesize revenant_identifier = _revenant_identifier, revenant_homeIdentifier = _revenant_homeIdentifier, revenant_delegate = _revenant_delegate;

REVENANT_HOMEKIT_NIL_INIT

- (instancetype)revenant_initWithStore:(RevenantHomeKitStore *)store identifier:(NSUUID *)identifier __attribute__((objc_method_family(init)))
{
    self = [super init];
    if (self) {
        _revenant_identifier = identifier ? [RevenantHomeKitUUIDString(identifier) copy]
                                        : [RevenantHomeKitNewIdentifier() copy];
        RevenantHomeKitRecord(@"homes", _revenant_identifier);
    }
    return self;
}

- (NSUUID *)uniqueIdentifier
{
    return RevenantHomeKitUUID(_revenant_identifier);
}

- (NSString *)name
{
    return RevenantHomeKitStringField(RevenantHomeKitRecord(@"homes", _revenant_identifier), @"name", @"");
}

- (BOOL)primary
{
    return RevenantHomeKitBoolField(RevenantHomeKitRecord(@"homes", _revenant_identifier), @"primary", NO);
}

- (id<HMHomeDelegate>)delegate
{
    return _revenant_delegate;
}

- (void)setDelegate:(id<HMHomeDelegate>)delegate
{
    _revenant_delegate = delegate;
}

- (HMUser *)currentUser
{
    NSString *current = RevenantHomeKitRecord(@"homes", _revenant_identifier)[@"currentUser"];
    return current ? RevenantHomeKitUser(current, _revenant_identifier) : nil;
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
    for (NSString *identifier in RevenantHomeKitStringListField(RevenantHomeKitRecord(@"homes", _revenant_identifier), @"roomOrder"))
        [found addObject:RevenantHomeKitRoom(identifier, _revenant_identifier)];
    return found;
}

- (HMRoom *)roomForEntireHome
{
    NSMutableDictionary *record = RevenantHomeKitRecord(@"homes", _revenant_identifier);
    NSString *identifier = record[@"entireHomeRoom"];
    if (identifier)
        return RevenantHomeKitRoom(identifier, _revenant_identifier);
    HMRoom *room = [[HMRoom alloc] revenant_initWithStore:[RevenantHomeKitStore shared] identifier:nil];
    [room updateName:@"Home" completionHandler:nil];
    record[@"entireHomeRoom"] = RevenantHomeKitUUIDString(room.uniqueIdentifier);
    NSMutableArray *order = [RevenantHomeKitStringListField(record, @"roomOrder") mutableCopy];
    [order addObject:RevenantHomeKitUUIDString(room.uniqueIdentifier)];
    record[@"roomOrder"] = order;
    [[RevenantHomeKitStore shared] flushTableNamed:@"homes"];
    return room;
}

- (NSArray<HMZone *> *)zones
{
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *identifier in RevenantHomeKitStringListField(RevenantHomeKitRecord(@"homes", _revenant_identifier), @"zoneOrder"))
        [found addObject:RevenantHomeKitZone(identifier, _revenant_identifier)];
    return found;
}

- (NSArray<HMUser *> *)users
{
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *identifier in RevenantHomeKitStringListField(RevenantHomeKitRecord(@"homes", _revenant_identifier), @"userOrder"))
        [found addObject:RevenantHomeKitUser(identifier, _revenant_identifier)];
    return found;
}

- (NSArray<HMServiceGroup *> *)serviceGroups
{
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *identifier in RevenantHomeKitStringListField(RevenantHomeKitRecord(@"homes", _revenant_identifier), @"serviceGroupOrder"))
        [found addObject:RevenantHomeKitServiceGroup(identifier, _revenant_identifier)];
    return found;
}

- (NSArray<HMAccessory *> *)accessories
{
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *identifier in RevenantHomeKitStringListField(RevenantHomeKitRecord(@"homes", _revenant_identifier), @"accessoryOrder"))
        [found addObject:RevenantHomeKitAccessory(identifier, _revenant_identifier)];
    return found;
}

- (NSArray<HMTrigger *> *)triggers
{
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *identifier in RevenantHomeKitStringListField(RevenantHomeKitRecord(@"homes", _revenant_identifier), @"triggerOrder")) {
        [found addObject:RevenantHomeKitTimerTrigger(identifier, _revenant_identifier)];
    }
    return found;
}

- (NSArray<HMActionSet *> *)actionSets
{
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *identifier in RevenantHomeKitStringListField(RevenantHomeKitRecord(@"homes", _revenant_identifier), @"actionSetOrder"))
        [found addObject:RevenantHomeKitActionSet(identifier, _revenant_identifier)];
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
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeNilParameter, @"a home needs a name"));
        return;
    }
    RevenantHomeKitSetField(@"homes", _revenant_identifier, @"name", name);
    HMHome *home = self;
    RevenantHomeKitTell(_revenant_delegate, @selector(homeDidUpdateName:), ^(id target) {
        [(id<HMHomeDelegate>)target homeDidUpdateName:home];
    });
    RevenantHomeKitFinishError(completionHandler, nil);
}

- (void)addRoomWithName:(NSString *)name completionHandler:(void (^)(HMRoom * _Nullable room, NSError * _Nullable error))completionHandler
{
    if (!name) {
        RevenantHomeKitFinish(completionHandler, nil, RevenantHomeKitError(HMErrorCodeNilParameter, @"a room needs a name"));
        return;
    }
    if ([self revenant_nameInUse:name]) {
        RevenantHomeKitFinish(completionHandler, nil,
                            RevenantHomeKitError(HMErrorCodeObjectWithSimilarNameExistsInHome,
                                               @"this home already has a room, zone or service group with that name"));
        return;
    }
    HMRoom *room = [[HMRoom alloc] revenant_initWithStore:[RevenantHomeKitStore shared] identifier:nil];
    [room updateName:name completionHandler:nil];
    [self revenant_append:RevenantHomeKitUUIDString(room.uniqueIdentifier) to:@"roomOrder"];
    HMHome *home = self;
    RevenantHomeKitTell(_revenant_delegate, @selector(home:didAddRoom:), ^(id target) {
        [(id<HMHomeDelegate>)target home:home didAddRoom:room];
    });
    RevenantHomeKitFinish(completionHandler, room, nil);
}

- (void)addZoneWithName:(NSString *)name completionHandler:(void (^)(HMZone * _Nullable zone, NSError * _Nullable error))completionHandler
{
    if (!name) {
        RevenantHomeKitFinish(completionHandler, nil, RevenantHomeKitError(HMErrorCodeNilParameter, @"a zone needs a name"));
        return;
    }
    if ([self revenant_nameInUse:name]) {
        RevenantHomeKitFinish(completionHandler, nil,
                            RevenantHomeKitError(HMErrorCodeObjectWithSimilarNameExistsInHome,
                                               @"this home already has a room, zone or service group with that name"));
        return;
    }
    HMZone *zone = [[HMZone alloc] revenant_initWithStore:[RevenantHomeKitStore shared] identifier:nil];
    [zone updateName:name completionHandler:nil];
    [self revenant_append:RevenantHomeKitUUIDString(zone.uniqueIdentifier) to:@"zoneOrder"];
    HMHome *home = self;
    RevenantHomeKitTell(_revenant_delegate, @selector(home:didAddZone:), ^(id target) {
        [(id<HMHomeDelegate>)target home:home didAddZone:zone];
    });
    RevenantHomeKitFinish(completionHandler, zone, nil);
}

- (void)addServiceGroupWithName:(NSString *)name completionHandler:(void (^)(HMServiceGroup * _Nullable group, NSError * _Nullable error))completionHandler
{
    if (!name) {
        RevenantHomeKitFinish(completionHandler, nil, RevenantHomeKitError(HMErrorCodeNilParameter, @"a service group needs a name"));
        return;
    }
    if ([self revenant_nameInUse:name]) {
        RevenantHomeKitFinish(completionHandler, nil,
                            RevenantHomeKitError(HMErrorCodeObjectWithSimilarNameExistsInHome,
                                               @"this home already has a room, zone or service group with that name"));
        return;
    }
    HMServiceGroup *group = [[HMServiceGroup alloc] revenant_initWithStore:[RevenantHomeKitStore shared] identifier:nil];
    [group updateName:name completionHandler:nil];
    [self revenant_append:RevenantHomeKitUUIDString(group.uniqueIdentifier) to:@"serviceGroupOrder"];
    HMHome *home = self;
    RevenantHomeKitTell(_revenant_delegate, @selector(home:didAddServiceGroup:), ^(id target) {
        [(id<HMHomeDelegate>)target home:home didAddServiceGroup:group];
    });
    RevenantHomeKitFinish(completionHandler, group, nil);
}

- (void)addUserWithCompletionHandler:(void (^)(HMUser * _Nullable user, NSError * _Nullable error))completionHandler
{
    HMUser *user = [[HMUser alloc] revenant_initWithStore:[RevenantHomeKitStore shared] identifier:nil];
    [user revenant_setName:@"Me"];
    [self revenant_append:RevenantHomeKitUUIDString(user.uniqueIdentifier) to:@"userOrder"];
    RevenantHomeKitSetField(@"homes", _revenant_identifier, @"currentUser", RevenantHomeKitUUIDString(user.uniqueIdentifier));
    HMHome *home = self;
    RevenantHomeKitTell(_revenant_delegate, @selector(home:didAddUser:), ^(id target) {
        [(id<HMHomeDelegate>)target home:home didAddUser:user];
    });
    RevenantHomeKitFinish(completionHandler, user,
                        RevenantHomeKitError(HMErrorCodeUserManagementFailed,
                                           @"there is no Apple ID on this release to invite a person from, so the user is the one this process runs as"));
}

- (void)manageUsersWithCompletionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    RevenantHomeKitFinishError(completionHandler,
                             RevenantHomeKitError(HMErrorCodeUserManagementFailed,
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
            return RevenantHomeKitHomeAccessControl(self, held);
    }
    return nil;
}

- (void)addAccessory:(HMAccessory *)accessory completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!accessory) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeNilParameter, @"an accessory is needed"));
        return;
    }
    if ([self revenant_holdsAccessory:accessory]) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeObjectAlreadyAssociatedToHome,
                                                                        @"the accessory is already in a home"));
        return;
    }
    RevenantHomeKitFinishError(completionHandler, RevenantHomeKitErrorForAccessory(HMErrorCodeAccessoryPairingFailed, accessory,
                                                                                @"adding an accessory needs a completed HAP pair-setup, which this port does not carry"));
}

- (void)removeAccessory:(HMAccessory *)accessory completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!accessory) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeNilParameter, @"an accessory is needed"));
        return;
    }
    if (![self revenant_holdsAccessory:accessory]) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeObjectNotAssociatedToAnyHome,
                                                                        @"the accessory is not in this home"));
        return;
    }
    NSMutableArray *order = [self revenant_orderFor:@"accessoryOrder"];
    [order removeObject:RevenantHomeKitUUIDString(accessory.identifier)];
    [self revenant_setOrder:order for:@"accessoryOrder"];
    HMHome *home = self;
    RevenantHomeKitTell(_revenant_delegate, @selector(home:didRemoveAccessory:), ^(id target) {
        [(id<HMHomeDelegate>)target home:home didRemoveAccessory:accessory];
    });
    RevenantHomeKitFinishError(completionHandler, nil);
}

- (void)assignAccessory:(HMAccessory *)accessory toRoom:(HMRoom *)room completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!accessory || !room) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeNilParameter, @"an accessory and a room are needed"));
        return;
    }
    if (![self revenant_holdsAccessory:accessory]) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeObjectNotAssociatedToAnyHome,
                                                                        @"the accessory is not in this home"));
        return;
    }
    if (room == self.roomForEntireHome) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeRoomForHomeCannotBeUpdated,
                                                                        @"the room for the entire home cannot hold one accessory"));
        return;
    }
    [accessory revenant_setRoom:RevenantHomeKitUUIDString(room.uniqueIdentifier)];
    HMHome *home = self;
    RevenantHomeKitTell(_revenant_delegate, @selector(home:didUpdateRoom:forAccessory:), ^(id target) {
        [(id<HMHomeDelegate>)target home:home didUpdateRoom:room forAccessory:accessory];
    });
    RevenantHomeKitFinishError(completionHandler, nil);
}

- (void)unblockAccessory:(HMAccessory *)accessory completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!accessory) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeNilParameter, @"an accessory is needed"));
        return;
    }
    RevenantHomeKitSetField(@"accessories", RevenantHomeKitUUIDString(accessory.identifier), @"blocked", @NO);
    HMHome *home = self;
    RevenantHomeKitTell(_revenant_delegate, @selector(home:didUnblockAccessory:), ^(id target) {
        [(id<HMHomeDelegate>)target home:home didUnblockAccessory:accessory];
    });
    RevenantHomeKitFinishError(completionHandler, nil);
}

- (void)removeRoom:(HMRoom *)room completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!room) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeNilParameter, @"a room is needed"));
        return;
    }
    if (room == self.roomForEntireHome) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeRoomForHomeCannotBeUpdated,
                                                                        @"the room for the entire home cannot be removed"));
        return;
    }
    NSMutableArray *order = [self revenant_orderFor:@"roomOrder"];
    if (![order containsObject:RevenantHomeKitUUIDString(room.uniqueIdentifier)]) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeObjectNotAssociatedToAnyHome,
                                                                        @"the room is not in this home"));
        return;
    }
    [order removeObject:RevenantHomeKitUUIDString(room.uniqueIdentifier)];
    [self revenant_setOrder:order for:@"roomOrder"];
    HMHome *home = self;
    RevenantHomeKitTell(_revenant_delegate, @selector(home:didRemoveRoom:), ^(id target) {
        [(id<HMHomeDelegate>)target home:home didRemoveRoom:room];
    });
    RevenantHomeKitFinishError(completionHandler, nil);
}

- (void)removeZone:(HMZone *)zone completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (![self revenant_remove:RevenantHomeKitUUIDString(zone.uniqueIdentifier) from:@"zoneOrder" named:@"the zone"]) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeObjectNotAssociatedToAnyHome,
                                                                        @"the zone is not in this home"));
        return;
    }
    HMHome *home = self;
    RevenantHomeKitTell(_revenant_delegate, @selector(home:didRemoveZone:), ^(id target) {
        [(id<HMHomeDelegate>)target home:home didRemoveZone:zone];
    });
    RevenantHomeKitFinishError(completionHandler, nil);
}

- (void)removeServiceGroup:(HMServiceGroup *)group completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (![self revenant_remove:RevenantHomeKitUUIDString(group.uniqueIdentifier) from:@"serviceGroupOrder" named:@"the service group"]) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeObjectNotAssociatedToAnyHome,
                                                                        @"the service group is not in this home"));
        return;
    }
    HMHome *home = self;
    RevenantHomeKitTell(_revenant_delegate, @selector(home:didRemoveServiceGroup:), ^(id target) {
        [(id<HMHomeDelegate>)target home:home didRemoveServiceGroup:group];
    });
    RevenantHomeKitFinishError(completionHandler, nil);
}

- (void)removeUser:(HMUser *)user completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!user) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeNilParameter, @"a user is needed"));
        return;
    }
    NSMutableArray *order = [self revenant_orderFor:@"userOrder"];
    if (![order containsObject:RevenantHomeKitUUIDString(user.uniqueIdentifier)]) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeObjectNotAssociatedToAnyHome,
                                                                        @"the user is not in this home"));
        return;
    }
    if (order.count == 1) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeCannotRemoveBuiltinActionSet,
                                                                        @"a home keeps at least one user"));
        return;
    }
    [order removeObject:RevenantHomeKitUUIDString(user.uniqueIdentifier)];
    [self revenant_setOrder:order for:@"userOrder"];
    if ([RevenantHomeKitRecord(@"homes", _revenant_identifier)[@"currentUser"] isEqualToString:RevenantHomeKitUUIDString(user.uniqueIdentifier)])
        RevenantHomeKitSetField(@"homes", _revenant_identifier, @"currentUser", order.firstObject);
    HMHome *home = self;
    RevenantHomeKitTell(_revenant_delegate, @selector(home:didRemoveUser:), ^(id target) {
        [(id<HMHomeDelegate>)target home:home didRemoveUser:user];
    });
    RevenantHomeKitFinishError(completionHandler, nil);
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
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeNilParameter, @"a trigger is needed"));
        return;
    }
    [trigger revenant_setHomeIdentifier:_revenant_identifier];
    [self revenant_append:RevenantHomeKitUUIDString(trigger.uniqueIdentifier) to:@"triggerOrder"];
    HMHome *home = self;
    RevenantHomeKitTell(_revenant_delegate, @selector(home:didAddTrigger:), ^(id target) {
        [(id<HMHomeDelegate>)target home:home didAddTrigger:trigger];
    });
    RevenantHomeKitFinishError(completionHandler, nil);
}

- (void)removeTrigger:(HMTrigger *)trigger completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!trigger) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeNilParameter, @"a trigger is needed"));
        return;
    }
    [self revenant_remove:RevenantHomeKitUUIDString(trigger.uniqueIdentifier) from:@"triggerOrder" named:@"the trigger"];
    HMHome *home = self;
    RevenantHomeKitTell(_revenant_delegate, @selector(home:didRemoveTrigger:), ^(id target) {
        [(id<HMHomeDelegate>)target home:home didRemoveTrigger:trigger];
    });
    RevenantHomeKitFinishError(completionHandler, nil);
}

- (void)addActionSetWithName:(NSString *)name completionHandler:(void (^)(HMActionSet * _Nullable actionSet, NSError * _Nullable error))completionHandler
{
    if (!name) {
        RevenantHomeKitFinish(completionHandler, nil, RevenantHomeKitError(HMErrorCodeNilParameter, @"an action set needs a name"));
        return;
    }
    HMActionSet *set = [[HMActionSet alloc] revenant_initWithStore:[RevenantHomeKitStore shared] identifier:nil];
    [set updateName:name completionHandler:nil];
    [set revenant_setHomeIdentifier:_revenant_identifier];
    [self revenant_append:RevenantHomeKitUUIDString(set.uniqueIdentifier) to:@"actionSetOrder"];
    HMHome *home = self;
    RevenantHomeKitTell(_revenant_delegate, @selector(home:didAddActionSet:), ^(id target) {
        [(id<HMHomeDelegate>)target home:home didAddActionSet:set];
    });
    RevenantHomeKitFinish(completionHandler, set, nil);
}

- (void)removeActionSet:(HMActionSet *)actionSet completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!actionSet) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeNilParameter, @"an action set is needed"));
        return;
    }
    if ([actionSet.actionSetType isEqualToString:HMActionSetTypeWakeUp] ||
        [actionSet.actionSetType isEqualToString:HMActionSetTypeSleep] ||
        [actionSet.actionSetType isEqualToString:HMActionSetTypeHomeArrival] ||
        [actionSet.actionSetType isEqualToString:HMActionSetTypeHomeDeparture]) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeCannotRemoveBuiltinActionSet,
                                                                        @"a built-in action set cannot be removed"));
        return;
    }
    [self revenant_remove:RevenantHomeKitUUIDString(actionSet.uniqueIdentifier) from:@"actionSetOrder" named:@"the action set"];
    HMHome *home = self;
    RevenantHomeKitTell(_revenant_delegate, @selector(home:didRemoveActionSet:), ^(id target) {
        [(id<HMHomeDelegate>)target home:home didRemoveActionSet:actionSet];
    });
    RevenantHomeKitFinishError(completionHandler, nil);
}

- (void)revenant_setHomeIdentifier:(NSString *)homeIdentifier
{
    self.revenant_homeIdentifier = homeIdentifier;
}

- (NSMutableArray *)revenant_orderFor:(NSString *)key
{
    return [RevenantHomeKitStringListField(RevenantHomeKitRecord(@"homes", _revenant_identifier), key) mutableCopy];
}

- (void)revenant_setOrder:(NSArray *)order for:(NSString *)key
{
    RevenantHomeKitSetField(@"homes", _revenant_identifier, key, order);
    [[RevenantHomeKitStore shared] flushTableNamed:@"homes"];
}

- (void)revenant_append:(NSString *)identifier to:(NSString *)key
{
    NSMutableArray *order = [self revenant_orderFor:key];
    if (![order containsObject:identifier]) {
        [order addObject:identifier];
        [self revenant_setOrder:order for:key];
    }
}

- (BOOL)revenant_remove:(NSString *)identifier from:(NSString *)key named:(NSString *)what
{
    NSMutableArray *order = [self revenant_orderFor:key];
    BOOL held = [order containsObject:identifier];
    if (held) {
        [order removeObject:identifier];
        [self revenant_setOrder:order for:key];
    }
    (void)what;
    return held;
}

- (BOOL)revenant_holdsAccessory:(HMAccessory *)accessory
{
    for (HMAccessory *held in self.accessories) {
        if ([held.identifier isEqual:accessory.identifier])
            return YES;
    }
    return NO;
}

- (BOOL)revenant_nameInUse:(NSString *)name
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
@synthesize revenant_delegate = _revenant_delegate;

- (instancetype)init
{
    return [super init];
}

- (id<HMHomeManagerDelegate>)delegate
{
    return _revenant_delegate;
}

- (void)setDelegate:(id<HMHomeManagerDelegate>)delegate
{
    _revenant_delegate = delegate;
}

- (HMHomeManagerAuthorizationStatus)authorizationStatus
{
    return HMHomeManagerAuthorizationStatusDetermined;
}

- (NSArray<HMHome *> *)homes
{
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *identifier in RevenantHomeKitStringListField(RevenantHomeKitRecord(@"homes", RevenantHomeKitHomeOrderKey), @"homes"))
        [found addObject:RevenantHomeKitHome(identifier)];
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
        RevenantHomeKitFinish(completionHandler, nil, RevenantHomeKitError(HMErrorCodeNilParameter, @"a home needs a name"));
        return;
    }
    for (HMHome *home in self.homes) {
        if ([home.name isEqualToString:name]) {
            RevenantHomeKitFinish(completionHandler, nil, RevenantHomeKitError(HMErrorCodeHomeWithSimilarNameExists,
                                                                            @"there is already a home with that name"));
            return;
        }
    }
    HMHome *home = [[HMHome alloc] revenant_initWithStore:[RevenantHomeKitStore shared] identifier:nil];
    [home updateName:name completionHandler:nil];
    RevenantHomeKitSetField(@"homes", RevenantHomeKitUUIDString(home.uniqueIdentifier), @"primary", @(self.homes.count == 0));

    RevenantHomeKitStore *store = [RevenantHomeKitStore shared];
    NSMutableDictionary *homes = [store tableNamed:@"homes"];
    NSMutableArray *order = [homes[RevenantHomeKitHomeOrderKey][@"homes"] mutableCopy] ?: [NSMutableArray array];
    [order addObject:RevenantHomeKitUUIDString(home.uniqueIdentifier)];
    homes[RevenantHomeKitHomeOrderKey] = @{@"homes": order};
    [store flushTableNamed:@"homes"];

    HMHomeManager *manager = self;
    RevenantHomeKitTell(_revenant_delegate, @selector(homeManager:didAddHome:), ^(id target) {
        [(id<HMHomeManagerDelegate>)target homeManager:manager didAddHome:home];
    });
    RevenantHomeKitFinish(completionHandler, home, nil);
}

- (void)removeHome:(HMHome *)home completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!home) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeNilParameter, @"a home is needed"));
        return;
    }
    if (![self.homes containsObject:RevenantHomeKitHome(RevenantHomeKitUUIDString(home.uniqueIdentifier))]) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeObjectNotAssociatedToAnyHome,
                                                                        @"the home is not one of this manager's"));
        return;
    }
    RevenantHomeKitStore *store = [RevenantHomeKitStore shared];
    NSMutableDictionary *homes = [store tableNamed:@"homes"];
    NSMutableArray *order = [homes[RevenantHomeKitHomeOrderKey][@"homes"] mutableCopy] ?: [NSMutableArray array];
    [order removeObject:RevenantHomeKitUUIDString(home.uniqueIdentifier)];
    homes[RevenantHomeKitHomeOrderKey] = @{@"homes": order};
    [homes removeObjectForKey:RevenantHomeKitUUIDString(home.uniqueIdentifier)];
    [store flushTableNamed:@"homes"];
    HMHomeManager *manager = self;
    RevenantHomeKitTell(_revenant_delegate, @selector(homeManager:didRemoveHome:), ^(id target) {
        [(id<HMHomeManagerDelegate>)target homeManager:manager didRemoveHome:home];
    });
    RevenantHomeKitFinishError(completionHandler, nil);
}

- (void)updatePrimaryHome:(HMHome *)primaryHome completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!primaryHome) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeNilParameter, @"a home is needed"));
        return;
    }
    for (HMHome *home in self.homes)
        RevenantHomeKitSetField(@"homes", RevenantHomeKitUUIDString(home.uniqueIdentifier), @"primary", @(home == primaryHome));
    RevenantHomeKitTell(_revenant_delegate, @selector(homeManagerDidUpdatePrimaryHome:), ^(id target) {
        [(id<HMHomeManagerDelegate>)target homeManagerDidUpdatePrimaryHome:self];
    });
    RevenantHomeKitFinishError(completionHandler, nil);
}

- (void)findVendorAccessoryWithHAPPublicKey:(NSData *)publicKey completionHandler:(void (^)(HMAccessory * _Nullable accessory, NSError * _Nullable error))completionHandler
{
    if (!publicKey.length) {
        RevenantHomeKitFinish(completionHandler, nil, RevenantHomeKitError(HMErrorCodeNilParameter, @"a public key is needed"));
        return;
    }
    NSMutableDictionary *pairings = [[RevenantHomeKitStore shared] tableNamed:@"pairings"];
    for (NSString *identifier in pairings) {
        if ([pairings[identifier][@"ltpk"] isEqualToData:publicKey]) {
            for (HMHome *home in self.homes) {
                for (HMAccessory *accessory in home.accessories) {
                    if ([RevenantHomeKitUUIDString(accessory.identifier) isEqualToString:identifier]) {
                        RevenantHomeKitFinish(completionHandler, accessory, nil);
                        return;
                    }
                }
            }
        }
    }
    RevenantHomeKitFinish(completionHandler, nil, RevenantHomeKitError(HMErrorCodeNotFound,
                                                                    @"no paired accessory has that public key"));
}

@end
