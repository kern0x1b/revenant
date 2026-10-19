#ifndef CHARON_HOMEKIT_INTERNAL_H
#define CHARON_HOMEKIT_INTERNAL_H

#import <Foundation/Foundation.h>
#import <HomeKit/HomeKit.h>
#import <CoreLocation/CoreLocation.h>
#import "CharonHomeKitModel.h"
#import "CharonHomeKitConstruction.h"

NS_ASSUME_NONNULL_BEGIN

HMAccessory *CharonHomeKitAccessory(NSString *identifier, NSString * _Nullable homeIdentifier);
HMAction *CharonHomeKitAction(NSString *identifier, NSString * _Nullable homeIdentifier);
HMService *CharonHomeKitService(NSString *identifier, NSString * _Nullable accessoryIdentifier);
HMCharacteristic *CharonHomeKitCharacteristic(NSString *identifier, NSString * _Nullable serviceIdentifier);
HMAccessoryCategory *CharonHomeKitAccessoryCategory(NSString *categoryType);
HMNumberRange *CharonHomeKitNumberRange(NSNumber * _Nullable minimum, NSNumber * _Nullable maximum);
HMAccessory *CharonHomeKitAccessory(NSString *identifier, NSString * _Nullable homeIdentifier);
HMAction *CharonHomeKitAction(NSString *identifier, NSString * _Nullable homeIdentifier);
HMService *CharonHomeKitService(NSString *identifier, NSString * _Nullable accessoryIdentifier);
HMCharacteristic *CharonHomeKitCharacteristic(NSString *identifier, NSString * _Nullable serviceIdentifier);
HMAccessoryCategory *CharonHomeKitAccessoryCategory(NSString *categoryType);

HMCharacteristicMetadata *CharonHomeKitCharacteristicMetadataForRecord(NSMutableDictionary *record);

NSString * _Nullable CharonHomeKitAccessoryCategoryDescription(NSString * _Nullable categoryType);

@interface HMAccessoryCategory () @property (nonatomic, copy, nullable) NSString *charon_categoryType; @end
@interface HMNumberRange () @property (nonatomic, strong, nullable) NSNumber *charon_minValue;
@property (nonatomic, strong, nullable) NSNumber *charon_maxValue; @end
@interface HMAccessory () @property (nonatomic, copy) NSString *charon_identifier;
@property (nonatomic, copy, nullable) NSString *charon_homeIdentifier;
@property (nonatomic, weak, nullable) id<HMAccessoryDelegate> charon_delegate; @end
@interface HMAction () @property (nonatomic, copy) NSString *charon_identifier; @end
@interface HMService () @property (nonatomic, copy) NSString *charon_identifier;
@property (nonatomic, copy, nullable) NSString *charon_accessoryIdentifier; @end
@interface HMCharacteristic () @property (nonatomic, copy) NSString *charon_identifier;
@property (nonatomic, copy, nullable) NSString *charon_serviceIdentifier; @end
@interface HMCharacteristicMetadata () @property (nonatomic, strong) NSMutableDictionary *charon_record; @end
@interface HMCharacteristicWriteAction () @property (nonatomic, strong, nullable) HMCharacteristic *charon_characteristic;
@property (nonatomic, strong, nullable) id charon_targetValue; @end

@interface HMAccessory (CharonHomeKitStore)
- (void)charon_setHomeIdentifier:(NSString * _Nullable)homeIdentifier;
- (void)charon_setRoom:(NSString * _Nullable)roomIdentifier;
- (void)charon_setServiceIdentifiers:(NSArray<NSString *> *)identifiers;
@end
@interface HMService (CharonHomeKitStore)
- (void)charon_setAccessoryIdentifier:(NSString * _Nullable)accessoryIdentifier;
- (void)charon_setCharacteristicIdentifiers:(NSArray<NSString *> *)identifiers;
@end
@interface HMCharacteristic (CharonHomeKitStore)
- (void)charon_setServiceIdentifier:(NSString * _Nullable)serviceIdentifier;
- (void)charon_setValue:(id)value;
- (void)charon_setProperties:(NSArray<NSString *> *)properties;
@end

#pragma mark - the home graph's own entry points

HMRoom *CharonHomeKitRoom(NSString *identifier, NSString * _Nullable homeIdentifier);
HMZone *CharonHomeKitZone(NSString *identifier, NSString * _Nullable homeIdentifier);
HMUser *CharonHomeKitUser(NSString *identifier, NSString * _Nullable homeIdentifier);
HMServiceGroup *CharonHomeKitServiceGroup(NSString *identifier, NSString * _Nullable homeIdentifier);
HMHome *CharonHomeKitHome(NSString *identifier);
HMActionSet *CharonHomeKitActionSet(NSString *identifier, NSString * _Nullable homeIdentifier);
HMAction *CharonHomeKitAction(NSString *identifier, NSString * _Nullable homeIdentifier);
HMTrigger *CharonHomeKitTrigger(NSString *identifier, NSString * _Nullable homeIdentifier);
HMTimerTrigger *CharonHomeKitTimerTrigger(NSString *identifier, NSString * _Nullable homeIdentifier);

@interface HMRoom () @property (nonatomic, copy) NSString *charon_identifier;
@property (nonatomic, copy, nullable) NSString *charon_homeIdentifier; @end
@interface HMZone () @property (nonatomic, copy) NSString *charon_identifier;
@property (nonatomic, copy, nullable) NSString *charon_homeIdentifier; @end
@interface HMUser () @property (nonatomic, copy) NSString *charon_identifier;
@property (nonatomic, copy, nullable) NSString *charon_homeIdentifier; @end
@interface HMServiceGroup () @property (nonatomic, copy) NSString *charon_identifier;
@property (nonatomic, copy, nullable) NSString *charon_homeIdentifier; @end
@interface HMActionSet () @property (nonatomic, copy) NSString *charon_identifier;
@property (nonatomic, copy, nullable) NSString *charon_homeIdentifier; @end
@interface HMActionSet (CharonHomeKitStore) - (void)charon_setHomeIdentifier:(NSString * _Nullable)homeIdentifier; @end
@interface HMTrigger () @property (nonatomic, copy) NSString *charon_identifier;
@property (nonatomic, copy, nullable) NSString *charon_homeIdentifier; @end
@interface HMHome () @property (nonatomic, copy) NSString *charon_identifier;
@property (nonatomic, copy, nullable) NSString *charon_homeIdentifier;
@property (nonatomic, weak, nullable) id<HMHomeDelegate> charon_delegate; @end
@interface HMHomeManager () @property (nonatomic, weak, nullable) id<HMHomeManagerDelegate> charon_delegate; @end

@interface HMHome (CharonHomeKitStore)
- (void)charon_setHomeIdentifier:(NSString * _Nullable)homeIdentifier;
- (NSMutableArray *)charon_orderFor:(NSString *)key;
- (void)charon_setOrder:(NSArray *)order for:(NSString *)key;
- (void)charon_append:(NSString *)identifier to:(NSString *)key;
- (BOOL)charon_remove:(NSString *)identifier from:(NSString *)key named:(NSString *)what;
- (BOOL)charon_nameInUse:(NSString *)name;
- (BOOL)charon_holdsAccessory:(HMAccessory *)accessory;
@end
@interface HMUser (CharonHomeKitStore)
- (void)charon_setName:(NSString *)name;
@property (nonatomic, strong, nullable) id charon_homeAccessControl;
@end
@interface HMTrigger (CharonHomeKitStore) - (void)charon_setHomeIdentifier:(NSString * _Nullable)homeIdentifier; @end
@interface HMTimerTrigger (CharonHomeKitStore)
- (void)charon_applyName:(NSString * _Nullable)name;
- (void)charon_applyFireDate:(NSDate * _Nullable)fireDate;
- (void)charon_applyRecurrence:(NSDateComponents * _Nullable)recurrence;
@end
@interface NSObject (CharonHomeKitDelegate)
- (void)charon_tellHome:(SEL)selector object:(id)object block:(void (^)(id<HMHomeDelegate> delegate, HMHome *home, id object))block;
@end


#pragma mark - the events of iOS 9.0

HMEvent *CharonHomeKitEvent(NSString *identifier, NSString *kind);
HMEventTrigger *CharonHomeKitEventTrigger(NSString *identifier, NSString * _Nullable homeIdentifier);
HMHomeAccessControl *CharonHomeKitHomeAccessControl(HMHome *home, HMUser *user);

@interface HMEvent () @property (nonatomic, copy) NSString *charon_identifier; @end
@interface HMCharacteristicEvent () @property (nonatomic, strong, nullable) HMCharacteristic *charon_characteristic;
@property (nonatomic, strong, nullable) id charon_triggerValue; @end
@interface HMLocationEvent () @property (nonatomic, strong, nullable) CLCircularRegion *charon_region; @end
@interface HMEventTrigger () @property (nonatomic, copy) NSString *charon_identifier;
@property (nonatomic, copy, nullable) NSString *charon_homeIdentifier; @end
@interface HMHomeAccessControl () @property (nonatomic, weak, nullable) HMHome *charon_home;
@property (nonatomic, strong, nullable) HMUser *charon_user; @end

@interface HMEventTrigger (CharonHomeKitStore)
- (void)charon_setHomeIdentifier:(NSString * _Nullable)homeIdentifier;
- (void)charon_applyName:(NSString * _Nullable)name;
- (void)charon_applyEvents:(NSArray<HMEvent *> * _Nullable)events forKey:(NSString *)key;
- (void)charon_applyPredicate:(NSPredicate * _Nullable)predicate;
- (NSArray<HMEvent *> *)charon_eventsForKey:(NSString *)key;
@end

#pragma mark - the time events of iOS 11.0


@interface HMDurationEvent () @property (nonatomic, strong, nullable) NSNumber *charon_duration; @end
@interface HMMutableDurationEvent () @end
@interface HMCalendarEvent () @property (nonatomic, strong, nullable) NSDateComponents *charon_fireDateComponents; @end
@interface HMMutableCalendarEvent () @end
@interface HMSignificantTimeEvent () @property (nonatomic, copy, nullable) NSString *charon_significantEvent;
@property (nonatomic, strong, nullable) NSNumber *charon_offset; @end
@interface HMMutableSignificantTimeEvent () @end
@interface HMPresenceEvent () @property (nonatomic, strong, nullable) NSNumber *charon_presenceEventType;
@property (nonatomic, strong, nullable) NSNumber *charon_presenceUserType; @end
@interface HMMutablePresenceEvent () @end
@interface HMMutableCharacteristicEvent () @end

@interface HMAccessorySetupPayload () @property (nonatomic, strong, nullable) NSURL *charon_setupPayloadURL;
@property (nonatomic, strong, nullable) HMAccessoryOwnershipToken *charon_ownershipToken;
@end

@interface HMAccessorySetupResult (CharonHomeKitSetup)
- (instancetype)charon_initWithHomeIdentifier:(NSUUID *)homeIdentifier
                       accessoryIdentifiers:(NSArray<NSUUID *> *)accessoryIdentifiers
    __attribute__((objc_method_family(init)));
@end
@interface HMCharacteristicThresholdRangeEvent () @property (nonatomic, strong, nullable) HMCharacteristic *charon_characteristic;
@property (nonatomic, strong, nullable) HMNumberRange *charon_thresholdRange; @end
@interface HMMutableCharacteristicThresholdRangeEvent () @end

NS_ASSUME_NONNULL_END

#endif
