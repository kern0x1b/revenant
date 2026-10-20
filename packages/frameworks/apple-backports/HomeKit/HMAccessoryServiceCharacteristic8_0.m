#import "RevenantHomeKitInternal.h"

#pragma mark - HMAccessory

@implementation HMAccessory
@synthesize revenant_identifier = _revenant_identifier, revenant_homeIdentifier = _revenant_homeIdentifier, revenant_delegate = _revenant_delegate;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _revenant_identifier = [RevenantHomeKitNewIdentifier() copy];
        RevenantHomeKitRecord(@"accessories", _revenant_identifier);
    }
    return self;
}

- (NSString *)identifier
{
    return _revenant_identifier;
}

- (NSString *)uniqueIdentifier
{
    return RevenantHomeKitStringField(RevenantHomeKitRecord(@"accessories", _revenant_identifier), @"uniqueIdentifier", _revenant_identifier);
}

- (NSString *)name
{
    return RevenantHomeKitStringField(RevenantHomeKitRecord(@"accessories", _revenant_identifier), @"name", @"");
}

- (NSString *)category
{
    return [RevenantHomeKitRecord(@"accessories", _revenant_identifier)[@"category"] copy];
}

- (NSString *)room
{
    return [RevenantHomeKitRecord(@"accessories", _revenant_identifier)[@"room"] copy];
}

- (BOOL)bridged
{
    return RevenantHomeKitBoolField(RevenantHomeKitRecord(@"accessories", _revenant_identifier), @"bridged", NO);
}

- (BOOL)blocked
{
    return RevenantHomeKitBoolField(RevenantHomeKitRecord(@"accessories", _revenant_identifier), @"blocked", NO);
}

- (id<HMAccessoryDelegate>)delegate
{
    return _revenant_delegate;
}

- (void)setDelegate:(id<HMAccessoryDelegate>)delegate
{
    _revenant_delegate = delegate;
}

- (NSString *)manufacturer
{
    return RevenantHomeKitStringField(RevenantHomeKitRecord(@"accessories", _revenant_identifier), @"manufacturer", @"");
}

- (NSString *)model
{
    return RevenantHomeKitStringField(RevenantHomeKitRecord(@"accessories", _revenant_identifier), @"model", @"");
}

- (NSString *)firmwareVersion
{
    return RevenantHomeKitStringField(RevenantHomeKitRecord(@"accessories", _revenant_identifier), @"firmwareVersion", @"");
}

- (BOOL)supportsIdentify
{
    for (HMService *service in self.services) {
        for (HMCharacteristic *characteristic in service.characteristics) {
            if ([characteristic.characteristicType isEqualToString:HMCharacteristicTypeIdentify])
                return YES;
        }
    }
    return NO;
}

- (BOOL)reachable
{
    return RevenantHomeKitBoolField(RevenantHomeKitRecord(@"accessories", _revenant_identifier), @"reachable", NO);
}

- (NSArray<NSString *> *)identifiersForBridgedAccessories
{
    return RevenantHomeKitStringListField(RevenantHomeKitRecord(@"accessories", _revenant_identifier), @"bridgedIdentifiers");
}

- (NSArray<NSString *> *)uniqueIdentifiersForBridgedAccessories
{
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *identifier in self.identifiersForBridgedAccessories) {
        HMAccessory *bridged = RevenantHomeKitAccessory(identifier, _revenant_homeIdentifier);
        if (bridged)
            [found addObject:bridged.uniqueIdentifier];
    }
    return found;
}

- (NSArray<HMAccessory *> *)bridgedAccessories
{
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *identifier in self.identifiersForBridgedAccessories) {
        HMAccessory *bridged = RevenantHomeKitAccessory(identifier, _revenant_homeIdentifier);
        if (bridged)
            [found addObject:bridged];
    }
    return found;
}

- (NSArray<HMService *> *)services
{
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *identifier in RevenantHomeKitStringListField(RevenantHomeKitRecord(@"accessories", _revenant_identifier), @"services"))
        [found addObject:RevenantHomeKitService(identifier, _revenant_identifier)];
    return found;
}

- (void)identifyWithCompletionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    RevenantHomeKitFinishError(completionHandler, RevenantHomeKitErrorForAccessory(HMErrorCodeAccessoryNotReachable, self,
                                                                                @"identify needs a session with the accessory, and this port has none"));
}

- (void)updateName:(NSString *)name completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!name) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitErrorForAccessory(HMErrorCodeNilParameter, self, @"an accessory needs a name"));
        return;
    }
    RevenantHomeKitSetField(@"accessories", _revenant_identifier, @"name", name);
    HMAccessory *accessory = self;
    RevenantHomeKitTell(_revenant_delegate, @selector(accessoryDidUpdateName:), ^(id target) {
        [(id<HMAccessoryDelegate>)target accessoryDidUpdateName:accessory];
    });
    RevenantHomeKitFinishError(completionHandler, nil);
}

- (void)revenant_setHomeIdentifier:(NSString *)homeIdentifier
{
    self.revenant_homeIdentifier = homeIdentifier;
}

- (void)revenant_setRoom:(NSString *)roomIdentifier
{
    RevenantHomeKitSetField(@"accessories", _revenant_identifier, @"room", roomIdentifier);
}

- (void)revenant_setServiceIdentifiers:(NSArray<NSString *> *)identifiers
{
    RevenantHomeKitSetField(@"accessories", _revenant_identifier, @"services", identifiers);
}

@end

HMAccessory *RevenantHomeKitAccessory(NSString *identifier, NSString *homeIdentifier)
{
    HMAccessory *accessory = [[HMAccessory alloc] init];
    accessory.revenant_identifier = identifier;
    accessory.revenant_homeIdentifier = homeIdentifier;
    return accessory;
}

#pragma mark - HMService

@implementation HMService
@synthesize revenant_identifier = _revenant_identifier, revenant_accessoryIdentifier = _revenant_accessoryIdentifier;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _revenant_identifier = [RevenantHomeKitNewIdentifier() copy];
        RevenantHomeKitRecord(@"services", _revenant_identifier);
    }
    return self;
}

- (NSString *)uniqueIdentifier
{
    return _revenant_identifier;
}

- (NSString *)name
{
    return RevenantHomeKitStringField(RevenantHomeKitRecord(@"services", _revenant_identifier), @"name", @"");
}

- (NSString *)localizedDescription
{
    return self.name;
}

- (NSString *)serviceType
{
    return RevenantHomeKitStringField(RevenantHomeKitRecord(@"services", _revenant_identifier), @"serviceType", HMServiceTypeAccessoryInformation);
}

- (NSString *)associatedServiceType
{
    return [RevenantHomeKitRecord(@"services", _revenant_identifier)[@"associatedServiceType"] copy];
}

- (HMAccessory *)accessory
{
    return _revenant_accessoryIdentifier ? RevenantHomeKitAccessory(_revenant_accessoryIdentifier, nil) : nil;
}

- (BOOL)userInteractive
{
    return RevenantHomeKitBoolField(RevenantHomeKitRecord(@"services", _revenant_identifier), @"userInteractive", YES);
}

- (HMService *)primaryService
{
    NSString *identifier = RevenantHomeKitRecord(@"services", _revenant_identifier)[@"primaryService"];
    return identifier ? RevenantHomeKitService(identifier, _revenant_accessoryIdentifier) : nil;
}

- (NSArray<HMService *> *)linkedServices
{
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *identifier in RevenantHomeKitStringListField(RevenantHomeKitRecord(@"services", _revenant_identifier), @"linkedServices"))
        [found addObject:RevenantHomeKitService(identifier, _revenant_accessoryIdentifier)];
    return found;
}

- (NSArray<HMCharacteristic *> *)characteristics
{
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *identifier in RevenantHomeKitStringListField(RevenantHomeKitRecord(@"services", _revenant_identifier), @"characteristics"))
        [found addObject:RevenantHomeKitCharacteristic(identifier, _revenant_identifier)];
    return found;
}

- (void)updateName:(NSString *)name completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!name) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeNilParameter, @"a service needs a name"));
        return;
    }
    RevenantHomeKitSetField(@"services", _revenant_identifier, @"name", name);
    HMAccessory *accessory = self.accessory;
    HMService *service = self;
    RevenantHomeKitTell(accessory.delegate, @selector(accessory:didUpdateNameForService:), ^(id target) {
        [(id<HMAccessoryDelegate>)target accessory:accessory didUpdateNameForService:service];
    });
    RevenantHomeKitFinishError(completionHandler, nil);
}

- (void)updateAssociatedServiceType:(NSString *)associatedServiceType completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!associatedServiceType) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeNilParameter, @"an associated service type is needed"));
        return;
    }
    RevenantHomeKitSetField(@"services", _revenant_identifier, @"associatedServiceType", associatedServiceType);
    HMAccessory *accessory = self.accessory;
    HMService *service = self;
    RevenantHomeKitTell(accessory.delegate, @selector(accessory:didUpdateAssociatedServiceTypeForService:), ^(id target) {
        [(id<HMAccessoryDelegate>)target accessory:accessory didUpdateAssociatedServiceTypeForService:service];
    });
    RevenantHomeKitFinishError(completionHandler, nil);
}

- (void)revenant_setAccessoryIdentifier:(NSString *)accessoryIdentifier
{
    self.revenant_accessoryIdentifier = accessoryIdentifier;
}

- (void)revenant_setCharacteristicIdentifiers:(NSArray<NSString *> *)identifiers
{
    RevenantHomeKitSetField(@"services", _revenant_identifier, @"characteristics", identifiers);
}

@end

HMService *RevenantHomeKitService(NSString *identifier, NSString *accessoryIdentifier)
{
    HMService *service = [[HMService alloc] init];
    service.revenant_identifier = identifier;
    service.revenant_accessoryIdentifier = accessoryIdentifier;
    return service;
}

#pragma mark - HMCharacteristic

@implementation HMCharacteristic
@synthesize revenant_identifier = _revenant_identifier, revenant_serviceIdentifier = _revenant_serviceIdentifier;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _revenant_identifier = [RevenantHomeKitNewIdentifier() copy];
        RevenantHomeKitRecord(@"characteristics", _revenant_identifier);
    }
    return self;
}

- (NSString *)uniqueIdentifier
{
    return _revenant_identifier;
}

- (NSString *)characteristicType
{
    return RevenantHomeKitStringField(RevenantHomeKitRecord(@"characteristics", _revenant_identifier), @"type", HMCharacteristicTypeIdentifier);
}

- (NSString *)localizedDescription
{
    return RevenantHomeKitStringField(RevenantHomeKitRecord(@"characteristics", _revenant_identifier), @"localizedDescription", @"");
}

- (HMService *)service
{
    return _revenant_serviceIdentifier ? RevenantHomeKitService(_revenant_serviceIdentifier, nil) : nil;
}

- (id)value
{
    return [RevenantHomeKitRecord(@"characteristics", _revenant_identifier)[@"value"] copy];
}

- (NSArray<NSString *> *)properties
{
    return RevenantHomeKitStringListField(RevenantHomeKitRecord(@"characteristics", _revenant_identifier), @"properties");
}

- (HMCharacteristicMetadata *)metadata
{
    return RevenantHomeKitCharacteristicMetadataForRecord(RevenantHomeKitRecord(@"characteristics", _revenant_identifier));
}

- (BOOL)notificationEnabled
{
    return RevenantHomeKitBoolField(RevenantHomeKitRecord(@"characteristics", _revenant_identifier), @"notificationEnabled", NO);
}

- (void)readValueWithCompletionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    RevenantHomeKitFinishError(completionHandler, RevenantHomeKitErrorForAccessory(HMErrorCodeAccessoryNotReachable, self.service.accessory,
                                                                                @"reading a value needs a session with the accessory, and this port has none"));
}

- (void)writeValue:(id)value completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (![(NSArray *)self.properties containsObject:HMCharacteristicPropertyWritable]) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitErrorForAccessory(HMErrorCodeReadOnlyCharacteristic, self.service.accessory,
                                                                                     @"the characteristic does not take writes"));
        return;
    }
    RevenantHomeKitFinishError(completionHandler, RevenantHomeKitErrorForAccessory(HMErrorCodeAccessoryNotReachable, self.service.accessory,
                                                                                @"writing a value needs a session with the accessory, and this port has none"));
}

- (void)enableNotification:(BOOL)enable completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (![(NSArray *)self.properties containsObject:HMCharacteristicPropertySupportsEventNotification]) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitErrorForAccessory(HMErrorCodeNotificationNotSupported, self.service.accessory,
                                                                                     @"the characteristic does not notify"));
        return;
    }
    RevenantHomeKitFinishError(completionHandler, RevenantHomeKitErrorForAccessory(HMErrorCodeAccessoryNotReachable, self.service.accessory,
                                                                                @"subscribing needs a session with the accessory, and this port has none"));
}

- (void)updateAuthorizationData:(NSData *)authorizationData completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (![(NSArray *)self.properties containsObject:HMCharacteristicPropertyRequiresAuthorizationData]) {
        RevenantHomeKitFinishError(completionHandler, RevenantHomeKitError(HMErrorCodeOperationNotSupported,
                                                                        @"the characteristic does not take authorization data"));
        return;
    }
    RevenantHomeKitFinishError(completionHandler, RevenantHomeKitErrorForAccessory(HMErrorCodeInvalidOrMissingAuthorizationData, self.service.accessory,
                                                                                @"the authorization data needs a session with the accessory, and this port has none"));
}

- (void)revenant_setServiceIdentifier:(NSString *)serviceIdentifier
{
    self.revenant_serviceIdentifier = serviceIdentifier;
}

- (void)revenant_setValue:(id)value
{
    RevenantHomeKitSetField(@"characteristics", _revenant_identifier, @"value", value);
}

- (void)revenant_setProperties:(NSArray<NSString *> *)properties
{
    RevenantHomeKitSetField(@"characteristics", _revenant_identifier, @"properties", properties);
}

@end

HMCharacteristic *RevenantHomeKitCharacteristic(NSString *identifier, NSString *serviceIdentifier)
{
    HMCharacteristic *characteristic = [[HMCharacteristic alloc] init];
    characteristic.revenant_identifier = identifier;
    characteristic.revenant_serviceIdentifier = serviceIdentifier;
    return characteristic;
}

#pragma mark - HMCharacteristicMetadata

HMCharacteristicMetadata *RevenantHomeKitCharacteristicMetadataForRecord(NSMutableDictionary *record)
{
    HMCharacteristicMetadata *metadata = [[HMCharacteristicMetadata alloc] init];
    metadata.revenant_record = record ?: [[NSMutableDictionary alloc] init];
    return metadata;
}

@implementation HMCharacteristicMetadata
@synthesize revenant_record = _revenant_record;

- (instancetype)init
{
    self = [super init];
    if (self)
        _revenant_record = [[NSMutableDictionary alloc] init];
    return self;
}

- (NSString *)format
{
    return RevenantHomeKitStringField(_revenant_record, @"format", HMCharacteristicMetadataFormatBool);
}

- (NSString *)units
{
    return [_revenant_record[@"units"] copy];
}

- (NSNumber *)minimumValue
{
    return [_revenant_record[@"minimumValue"] copy];
}

- (NSNumber *)maximumValue
{
    return [_revenant_record[@"maximumValue"] copy];
}

- (NSNumber *)stepValue
{
    return [_revenant_record[@"stepValue"] copy];
}

- (NSNumber *)maxLength
{
    return [_revenant_record[@"maxLength"] copy];
}

- (NSArray *)validValues
{
    return [_revenant_record[@"validValues"] copy];
}

- (NSString *)manufacturerDescription
{
    return [_revenant_record[@"manufacturerDescription"] copy];
}

@end

#pragma mark - HMCharacteristicWriteAction

@implementation HMCharacteristicWriteAction
@synthesize revenant_characteristic = _revenant_characteristic, revenant_targetValue = _revenant_targetValue;

- (instancetype)initWithCharacteristic:(HMCharacteristic *)characteristic targetValue:(id)targetValue
{
    self = [super init];
    if (self) {
        _revenant_characteristic = characteristic;
        _revenant_targetValue = [targetValue copy];
    }
    return self;
}

- (HMCharacteristic *)characteristic
{
    return _revenant_characteristic;
}

- (id)targetValue
{
    return _revenant_targetValue;
}

- (void)updateTargetValue:(id)targetValue completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    _revenant_targetValue = [targetValue copy];
    RevenantHomeKitFinishError(completionHandler, nil);
}

@end
