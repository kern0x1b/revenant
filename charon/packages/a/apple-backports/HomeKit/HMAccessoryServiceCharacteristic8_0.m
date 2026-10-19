// The accessory graph of iOS 8.0: HMAccessory, HMService, HMCharacteristic,
// HMCharacteristicMetadata and HMCharacteristicWriteAction.
//
// The names, the services and the characteristics an accessory advertises and the room it is in are
// the graph's, and are answered from CharonHomeKitStore, so a graph an application built in one launch
// is there for the next. The value of a characteristic, whether the accessory is reachable and an
// identify are the accessory's own: the HAP code in this package (CharonHapCrypto.h,
// CharonHAPBignum.h) is the crypto HAP pairs with and opens no session, so those answer
// HMErrorCodeAccessoryNotReachable, which is what HomeKit answers for an accessory it cannot reach.
//
// One release's API per object file, which is what the band machinery needs: every class here arrived
// in iOS 8.0, whatever release a later member of one of them arrived in.
#import "CharonHomeKitInternal.h"

#pragma mark - HMAccessory

@implementation HMAccessory
@synthesize charon_identifier = _charon_identifier, charon_homeIdentifier = _charon_homeIdentifier, charon_delegate = _charon_delegate;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _charon_identifier = [CharonHomeKitNewIdentifier() copy];
        CharonHomeKitRecord(@"accessories", _charon_identifier);
    }
    return self;
}

- (NSString *)identifier
{
    return _charon_identifier;
}

- (NSString *)uniqueIdentifier
{
    return CharonHomeKitStringField(CharonHomeKitRecord(@"accessories", _charon_identifier), @"uniqueIdentifier", _charon_identifier);
}

- (NSString *)name
{
    return CharonHomeKitStringField(CharonHomeKitRecord(@"accessories", _charon_identifier), @"name", @"");
}

- (NSString *)category
{
    return [CharonHomeKitRecord(@"accessories", _charon_identifier)[@"category"] copy];
}

- (NSString *)room
{
    return [CharonHomeKitRecord(@"accessories", _charon_identifier)[@"room"] copy];
}

- (BOOL)bridged
{
    return CharonHomeKitBoolField(CharonHomeKitRecord(@"accessories", _charon_identifier), @"bridged", NO);
}

- (BOOL)blocked
{
    return CharonHomeKitBoolField(CharonHomeKitRecord(@"accessories", _charon_identifier), @"blocked", NO);
}

- (id<HMAccessoryDelegate>)delegate
{
    return _charon_delegate;
}

- (void)setDelegate:(id<HMAccessoryDelegate>)delegate
{
    _charon_delegate = delegate;
}

- (NSString *)manufacturer
{
    return CharonHomeKitStringField(CharonHomeKitRecord(@"accessories", _charon_identifier), @"manufacturer", @"");
}

- (NSString *)model
{
    return CharonHomeKitStringField(CharonHomeKitRecord(@"accessories", _charon_identifier), @"model", @"");
}

- (NSString *)firmwareVersion
{
    return CharonHomeKitStringField(CharonHomeKitRecord(@"accessories", _charon_identifier), @"firmwareVersion", @"");
}

- (BOOL)supportsIdentify
{
    // Whether the accessory advertises an Identify characteristic, which is what the property is: the
    // answer is the graph's, read off the accessory's own services.
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
    // Reachability is the accessory's own state and the graph does not hold it: an accessory that was
    // reachable when the last session ended is not reachable now, and a YES an application acted on
    // would be a lie. This port holds no session with any accessory -- the transport that would tell it
    // is not in the tree -- so the answer is the one a device with no session gives, and it is read
    // from the store's own record so that a session, when there is one, has somewhere to answer from.
    return CharonHomeKitBoolField(CharonHomeKitRecord(@"accessories", _charon_identifier), @"reachable", NO);
}

- (NSArray<NSString *> *)identifiersForBridgedAccessories
{
    return CharonHomeKitStringListField(CharonHomeKitRecord(@"accessories", _charon_identifier), @"bridgedIdentifiers");
}

- (NSArray<NSString *> *)uniqueIdentifiersForBridgedAccessories
{
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *identifier in self.identifiersForBridgedAccessories) {
        HMAccessory *bridged = CharonHomeKitAccessory(identifier, _charon_homeIdentifier);
        if (bridged)
            [found addObject:bridged.uniqueIdentifier];
    }
    return found;
}

- (NSArray<HMAccessory *> *)bridgedAccessories
{
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *identifier in self.identifiersForBridgedAccessories) {
        HMAccessory *bridged = CharonHomeKitAccessory(identifier, _charon_homeIdentifier);
        if (bridged)
            [found addObject:bridged];
    }
    return found;
}

- (NSArray<HMService *> *)services
{
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *identifier in CharonHomeKitStringListField(CharonHomeKitRecord(@"accessories", _charon_identifier), @"services"))
        [found addObject:CharonHomeKitService(identifier, _charon_identifier)];
    return found;
}

- (void)identifyWithCompletionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    // Identify is the accessory's own light, beep or display, so with no session to it the answer is
    // the one for an accessory that cannot be reached, rather than a claim that something blinked.
    CharonHomeKitFinishError(completionHandler, CharonHomeKitErrorForAccessory(HMErrorCodeAccessoryNotReachable, self,
                                                                                @"identify needs a session with the accessory, and this port has none"));
}

- (void)updateName:(NSString *)name completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!name) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitErrorForAccessory(HMErrorCodeNilParameter, self, @"an accessory needs a name"));
        return;
    }
    CharonHomeKitSetField(@"accessories", _charon_identifier, @"name", name);
    HMAccessory *accessory = self;
    CharonHomeKitTell(_charon_delegate, @selector(accessoryDidUpdateName:), ^(id target) {
        [(id<HMAccessoryDelegate>)target accessoryDidUpdateName:accessory];
    });
    CharonHomeKitFinishError(completionHandler, nil);
}

- (void)charon_setHomeIdentifier:(NSString *)homeIdentifier
{
    self.charon_homeIdentifier = homeIdentifier;
}

- (void)charon_setRoom:(NSString *)roomIdentifier
{
    CharonHomeKitSetField(@"accessories", _charon_identifier, @"room", roomIdentifier);
}

- (void)charon_setServiceIdentifiers:(NSArray<NSString *> *)identifiers
{
    CharonHomeKitSetField(@"accessories", _charon_identifier, @"services", identifiers);
}

@end

HMAccessory *CharonHomeKitAccessory(NSString *identifier, NSString *homeIdentifier)
{
    HMAccessory *accessory = [[HMAccessory alloc] init];
    accessory.charon_identifier = identifier;
    accessory.charon_homeIdentifier = homeIdentifier;
    return accessory;
}

#pragma mark - HMService

@implementation HMService
@synthesize charon_identifier = _charon_identifier, charon_accessoryIdentifier = _charon_accessoryIdentifier;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _charon_identifier = [CharonHomeKitNewIdentifier() copy];
        CharonHomeKitRecord(@"services", _charon_identifier);
    }
    return self;
}

- (NSString *)uniqueIdentifier
{
    return _charon_identifier;
}

- (NSString *)name
{
    return CharonHomeKitStringField(CharonHomeKitRecord(@"services", _charon_identifier), @"name", @"");
}

- (NSString *)localizedDescription
{
    return self.name;
}

- (NSString *)serviceType
{
    return CharonHomeKitStringField(CharonHomeKitRecord(@"services", _charon_identifier), @"serviceType", HMServiceTypeAccessoryInformation);
}

- (NSString *)associatedServiceType
{
    return [CharonHomeKitRecord(@"services", _charon_identifier)[@"associatedServiceType"] copy];
}

- (HMAccessory *)accessory
{
    return _charon_accessoryIdentifier ? CharonHomeKitAccessory(_charon_accessoryIdentifier, nil) : nil;
}

- (BOOL)userInteractive
{
    return CharonHomeKitBoolField(CharonHomeKitRecord(@"services", _charon_identifier), @"userInteractive", YES);
}

- (HMService *)primaryService
{
    NSString *identifier = CharonHomeKitRecord(@"services", _charon_identifier)[@"primaryService"];
    return identifier ? CharonHomeKitService(identifier, _charon_accessoryIdentifier) : nil;
}

- (NSArray<HMService *> *)linkedServices
{
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *identifier in CharonHomeKitStringListField(CharonHomeKitRecord(@"services", _charon_identifier), @"linkedServices"))
        [found addObject:CharonHomeKitService(identifier, _charon_accessoryIdentifier)];
    return found;
}

- (NSArray<HMCharacteristic *> *)characteristics
{
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *identifier in CharonHomeKitStringListField(CharonHomeKitRecord(@"services", _charon_identifier), @"characteristics"))
        [found addObject:CharonHomeKitCharacteristic(identifier, _charon_identifier)];
    return found;
}

- (void)updateName:(NSString *)name completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!name) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeNilParameter, @"a service needs a name"));
        return;
    }
    CharonHomeKitSetField(@"services", _charon_identifier, @"name", name);
    HMAccessory *accessory = self.accessory;
    HMService *service = self;
    CharonHomeKitTell(accessory.delegate, @selector(accessory:didUpdateNameForService:), ^(id target) {
        [(id<HMAccessoryDelegate>)target accessory:accessory didUpdateNameForService:service];
    });
    CharonHomeKitFinishError(completionHandler, nil);
}

- (void)updateAssociatedServiceType:(NSString *)associatedServiceType completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (!associatedServiceType) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeNilParameter, @"an associated service type is needed"));
        return;
    }
    CharonHomeKitSetField(@"services", _charon_identifier, @"associatedServiceType", associatedServiceType);
    HMAccessory *accessory = self.accessory;
    HMService *service = self;
    CharonHomeKitTell(accessory.delegate, @selector(accessory:didUpdateAssociatedServiceTypeForService:), ^(id target) {
        [(id<HMAccessoryDelegate>)target accessory:accessory didUpdateAssociatedServiceTypeForService:service];
    });
    CharonHomeKitFinishError(completionHandler, nil);
}

- (void)charon_setAccessoryIdentifier:(NSString *)accessoryIdentifier
{
    self.charon_accessoryIdentifier = accessoryIdentifier;
}

- (void)charon_setCharacteristicIdentifiers:(NSArray<NSString *> *)identifiers
{
    CharonHomeKitSetField(@"services", _charon_identifier, @"characteristics", identifiers);
}

@end

HMService *CharonHomeKitService(NSString *identifier, NSString *accessoryIdentifier)
{
    HMService *service = [[HMService alloc] init];
    service.charon_identifier = identifier;
    service.charon_accessoryIdentifier = accessoryIdentifier;
    return service;
}

#pragma mark - HMCharacteristic

@implementation HMCharacteristic
@synthesize charon_identifier = _charon_identifier, charon_serviceIdentifier = _charon_serviceIdentifier;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _charon_identifier = [CharonHomeKitNewIdentifier() copy];
        CharonHomeKitRecord(@"characteristics", _charon_identifier);
    }
    return self;
}

- (NSString *)uniqueIdentifier
{
    return _charon_identifier;
}

- (NSString *)characteristicType
{
    return CharonHomeKitStringField(CharonHomeKitRecord(@"characteristics", _charon_identifier), @"type", HMCharacteristicTypeIdentifier);
}

- (NSString *)localizedDescription
{
    return CharonHomeKitStringField(CharonHomeKitRecord(@"characteristics", _charon_identifier), @"localizedDescription", @"");
}

- (HMService *)service
{
    return _charon_serviceIdentifier ? CharonHomeKitService(_charon_serviceIdentifier, nil) : nil;
}

- (id)value
{
    return [CharonHomeKitRecord(@"characteristics", _charon_identifier)[@"value"] copy];
}

- (NSArray<NSString *> *)properties
{
    return CharonHomeKitStringListField(CharonHomeKitRecord(@"characteristics", _charon_identifier), @"properties");
}

- (HMCharacteristicMetadata *)metadata
{
    return CharonHomeKitCharacteristicMetadataForRecord(CharonHomeKitRecord(@"characteristics", _charon_identifier));
}

- (BOOL)notificationEnabled
{
    return CharonHomeKitBoolField(CharonHomeKitRecord(@"characteristics", _charon_identifier), @"notificationEnabled", NO);
}

- (void)readValueWithCompletionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    // The value is the accessory's, and it is read over HAP. This port holds no session with an
    // accessory it has not paired, so the read answers the way HomeKit answers for an accessory that
    // is not reachable, and the characteristic's own graph fields stay readable.
    CharonHomeKitFinishError(completionHandler, CharonHomeKitErrorForAccessory(HMErrorCodeAccessoryNotReachable, self.service.accessory,
                                                                                @"reading a value needs a session with the accessory, and this port has none"));
}

- (void)writeValue:(id)value completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    // The graph is asked first, because its answer holds whether or not there is a session: a
    // characteristic that does not take writes is read-only whatever the accessory is doing.
    if (![(NSArray *)self.properties containsObject:HMCharacteristicPropertyWritable]) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitErrorForAccessory(HMErrorCodeReadOnlyCharacteristic, self.service.accessory,
                                                                                     @"the characteristic does not take writes"));
        return;
    }
    CharonHomeKitFinishError(completionHandler, CharonHomeKitErrorForAccessory(HMErrorCodeAccessoryNotReachable, self.service.accessory,
                                                                                @"writing a value needs a session with the accessory, and this port has none"));
}

- (void)enableNotification:(BOOL)enable completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (![(NSArray *)self.properties containsObject:HMCharacteristicPropertySupportsEventNotification]) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitErrorForAccessory(HMErrorCodeNotificationNotSupported, self.service.accessory,
                                                                                     @"the characteristic does not notify"));
        return;
    }
    CharonHomeKitFinishError(completionHandler, CharonHomeKitErrorForAccessory(HMErrorCodeAccessoryNotReachable, self.service.accessory,
                                                                                @"subscribing needs a session with the accessory, and this port has none"));
}

- (void)updateAuthorizationData:(NSData *)authorizationData completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (![(NSArray *)self.properties containsObject:HMCharacteristicPropertyRequiresAuthorizationData]) {
        CharonHomeKitFinishError(completionHandler, CharonHomeKitError(HMErrorCodeOperationNotSupported,
                                                                        @"the characteristic does not take authorization data"));
        return;
    }
    CharonHomeKitFinishError(completionHandler, CharonHomeKitErrorForAccessory(HMErrorCodeInvalidOrMissingAuthorizationData, self.service.accessory,
                                                                                @"the authorization data needs a session with the accessory, and this port has none"));
}

- (void)charon_setServiceIdentifier:(NSString *)serviceIdentifier
{
    self.charon_serviceIdentifier = serviceIdentifier;
}

- (void)charon_setValue:(id)value
{
    CharonHomeKitSetField(@"characteristics", _charon_identifier, @"value", value);
}

- (void)charon_setProperties:(NSArray<NSString *> *)properties
{
    CharonHomeKitSetField(@"characteristics", _charon_identifier, @"properties", properties);
}

@end

HMCharacteristic *CharonHomeKitCharacteristic(NSString *identifier, NSString *serviceIdentifier)
{
    HMCharacteristic *characteristic = [[HMCharacteristic alloc] init];
    characteristic.charon_identifier = identifier;
    characteristic.charon_serviceIdentifier = serviceIdentifier;
    return characteristic;
}

#pragma mark - HMCharacteristicMetadata

// The metadata belongs to the characteristic that holds it and has no identifier of its own, so it is
// built from that characteristic's record. This is the port's own way in, which is why it is a C
// function and not an initialiser: the release declares no initialiser for this class either.
HMCharacteristicMetadata *CharonHomeKitCharacteristicMetadataForRecord(NSMutableDictionary *record)
{
    HMCharacteristicMetadata *metadata = [[HMCharacteristicMetadata alloc] init];
    metadata.charon_record = record ?: [[NSMutableDictionary alloc] init];
    return metadata;
}

@implementation HMCharacteristicMetadata
@synthesize charon_record = _charon_record;

- (instancetype)init
{
    self = [super init];
    if (self)
        _charon_record = [[NSMutableDictionary alloc] init];
    return self;
}

- (NSString *)format
{
    return CharonHomeKitStringField(_charon_record, @"format", HMCharacteristicMetadataFormatBool);
}

- (NSString *)units
{
    return [_charon_record[@"units"] copy];
}

- (NSNumber *)minimumValue
{
    return [_charon_record[@"minimumValue"] copy];
}

- (NSNumber *)maximumValue
{
    return [_charon_record[@"maximumValue"] copy];
}

- (NSNumber *)stepValue
{
    return [_charon_record[@"stepValue"] copy];
}

- (NSNumber *)maxLength
{
    return [_charon_record[@"maxLength"] copy];
}

- (NSArray *)validValues
{
    return [_charon_record[@"validValues"] copy];
}

- (NSString *)manufacturerDescription
{
    return [_charon_record[@"manufacturerDescription"] copy];
}

@end

#pragma mark - HMCharacteristicWriteAction

@implementation HMCharacteristicWriteAction
@synthesize charon_characteristic = _charon_characteristic, charon_targetValue = _charon_targetValue;

- (instancetype)initWithCharacteristic:(HMCharacteristic *)characteristic targetValue:(id)targetValue
{
    self = [super init];
    if (self) {
        _charon_characteristic = characteristic;
        _charon_targetValue = [targetValue copy];
    }
    return self;
}

- (HMCharacteristic *)characteristic
{
    return _charon_characteristic;
}

- (id)targetValue
{
    return _charon_targetValue;
}

- (void)updateTargetValue:(id)targetValue completionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    _charon_targetValue = [targetValue copy];
    CharonHomeKitFinishError(completionHandler, nil);
}

@end
