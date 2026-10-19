// HMHome and HMHomeManager, of iOS 8.0: the root of the graph and the one place the set of homes is
// read and written. What an application builds through -addHomeWithName:completionHandler: is in
// CharonHomeKitStore before the handler is called, and is there for the next launch.
//
// One release's API per object file, which is what the band machinery needs.
#import "CharonHomeKitInternal.h"

#pragma mark - HMHome

@implementation HMHome
@synthesize charon_identifier = _charon_identifier, charon_homeIdentifier = _charon_homeIdentifier, charon_delegate = _charon_delegate;

// -init, as the release's own class answers it: the body read out of the arm64e cache of iOS 16.0
// releases the receiver and answers nil, which the macro below carries. A home is made through the
// port's own -charon_initWithStore:identifier: below, which is what CharonHomeKitModel.m's
// CharonHomeKitHome() calls - that file and not this one, because a band from iOS 8.0 on does not link
// this object and two files that no band drops (HMAccessoryHome10_0.m and CharonHomeKitDelegate.m)
// call that function - and +new is not defined here for the reason its comment in HMHomeManager
// gives.
CHARON_HOMEKIT_NIL_INIT

// The port's own designated initializer, and where a home's identity comes from: see
// CharonHomeKitConstruction.h for why this is not -init and what the method-family attribute is for.
// Every model call in this file and in HMHomeGraph8_0.m reaches a home through it, and so does
// CharonHomeKitHome() in CharonHomeKitModel.m, which is where the graph's own entry point is built -
// it is here rather than in a +new the release has no use for, and the entry point is there because
// this object is not in every band.
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
    // The current user is the one the store records as current for this home. There is no iCloud
    // account on this release to decide it from, so it is whatever -addUserWithCompletionHandler: last
    // made current, and nothing until then.
    NSString *current = CharonHomeKitRecord(@"homes", _charon_identifier)[@"currentUser"];
    return current ? CharonHomeKitUser(current, _charon_identifier) : nil;
}

- (HMHomeHubState)homeHubState
{
    // A home hub is the Apple TV or iPad that runs a home away from home. This release has neither in
    // the role, so the state is the one a home with no hub answers, and it is the daemon's absence the
    // port is reporting rather than a guess: see facts/HomeKit/HMHome.md.
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
    // The room that holds an accessory with no room of its own. HomeKit makes it on demand and it is
    // a real room, so it is written into the home's own list the first time it is asked for and is
    // there after that.
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
    // The home's triggers, in the order the home lists them. The kind is recorded with each one, so a
    // trigger read back is the kind it was created as rather than whichever subclass comes first.
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *identifier in CharonHomeKitStringListField(CharonHomeKitRecord(@"homes", _charon_identifier), @"triggerOrder")) {
        // The kind is recorded with each trigger, so one read back is the kind it was created as. The
        // event trigger of iOS 9.0 is not in the tree in this round, so a trigger recorded as one is
        // listed here as the timer trigger its own store says it is rather than as a class that is
        // not there; facts/HomeKit/HMHome.md says so.
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
    // The built-in action sets are the home's own and are listed with the rest. An application asking
    // for one by name gets that one, and an unknown type gets nil, which is what asking for an action
    // set that is not there answers.
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
    // A second room, zone or service group with a name this home already uses is refused, and the code
    // the release refuses it with: an application that lays out a home would otherwise get two rooms
    // it cannot tell apart.
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
    // Adding a user is adding a person, and there is no Apple ID on this release to add: the port
    // makes the user the process runs as, names it from the account the keychain already holds, and
    // says what it could not do through the error it passes alongside the user HomeKit also returns.
    // An application that checks only the user still gets a usable one, and one that reads the error
    // learns that no invitation was sent.
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
    // Adding an accessory to a home is a HAP pair-setup, and this port carries none: no HAP session, no
    // Bonjour browse, no Bluetooth LE scan. The refusal is the documented one for a pairing that did not
    // happen, and the graph is left exactly as it was.
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
        // A home keeps at least one user. The code is the release's own for an object a home will not do
        // without, which is what the release answers here too.
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

// Whether the graph holds an accessory at all, which is what adding and assigning both ask: an
// accessory is in a home when that home's own ordering names it, and the ordering is the graph.
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

// -init, as the release's own class answers it: the body read out of the arm64e cache of iOS 16.0 is
// `[self initWithHomeMangerConfiguration:[HMHomeManagerConfiguration defaultConfiguration]]`, so the
// manager comes up on its default configuration rather than bare, and it is not a raise. What the
// configuration holds on a device is the daemon's settings; the port's manager reads and writes the
// shared store, which is the same role, and its accessors already read it - so the default
// configuration is what this object already answers from and there is nothing else to store.
// facts/HomeKit/HMAccessoryProfile.md carries the body and the names out of it.
//
// +new is not defined here: the metaclass of this class carries no +new of its own in the cache of
// iOS 16.0, so the class inherits NSObject's, which is [[self alloc] init] and reaches the -init
// above. A definition here would put the selector in the port's metadata where the release's has none
// and would answer a caller what -init answers.
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
    // The status answers whether this process may read the homes. It may: the port's graph is the
    // application's own store, which no other application can reach, and there is nothing for the
    // system to refuse. The host, which has a daemon, answers for a process the daemon has not
    // authorized -- see facts/HomeKit/HMHome.md for the difference and what the host answers instead.
    return HMHomeManagerAuthorizationStatusDetermined;
}

- (NSArray<HMHome *> *)homes
{
    // The stored homes in the order the store lists them, so the order an application sees is the order
    // the graph was built in and the same on every launch.
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

    // The manager's own ordering, so that the homes come back in the order they were made. It is one
    // more row of the same table, so a store that grew a home and a store that grew its order cannot
    // disagree about which homes exist.
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
        // HMHomeManager.h:133 spells this one with the manager as its only argument; the delegate reads
        // the primary home off the manager, which is what the port has just written.
        [(id<HMHomeManagerDelegate>)target homeManagerDidUpdatePrimaryHome:self];
    });
    CharonHomeKitFinishError(completionHandler, nil);
}

- (void)findVendorAccessoryWithHAPPublicKey:(NSData *)publicKey completionHandler:(void (^)(HMAccessory * _Nullable accessory, NSError * _Nullable error))completionHandler
{
    // A vendor accessory is one whose HAP public key the vendor has published, and looking one up is a
    // search of what the port holds, not a call to a service: the store's pairings are the ones this
    // port has, and a key that is not among them names nothing.
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
