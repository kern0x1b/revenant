#ifndef REVENANT_HOMEKIT_INTERNAL_H
#define REVENANT_HOMEKIT_INTERNAL_H

#import <Foundation/Foundation.h>
#import <HomeKit/HomeKit.h>
#import <CoreLocation/CoreLocation.h>
#import "RevenantHomeKitModel.h"
#import "RevenantHomeKitConstruction.h"

NS_ASSUME_NONNULL_BEGIN

HMAccessory *RevenantHomeKitAccessory(NSString *identifier, NSString * _Nullable homeIdentifier);
HMAction *RevenantHomeKitAction(NSString *identifier, NSString * _Nullable homeIdentifier);
HMService *RevenantHomeKitService(NSString *identifier, NSString * _Nullable accessoryIdentifier);
HMCharacteristic *RevenantHomeKitCharacteristic(NSString *identifier, NSString * _Nullable serviceIdentifier);
HMAccessoryCategory *RevenantHomeKitAccessoryCategory(NSString *categoryType);
HMNumberRange *RevenantHomeKitNumberRange(NSNumber * _Nullable minimum, NSNumber * _Nullable maximum);
HMAccessory *RevenantHomeKitAccessory(NSString *identifier, NSString * _Nullable homeIdentifier);
HMAction *RevenantHomeKitAction(NSString *identifier, NSString * _Nullable homeIdentifier);
HMService *RevenantHomeKitService(NSString *identifier, NSString * _Nullable accessoryIdentifier);
HMCharacteristic *RevenantHomeKitCharacteristic(NSString *identifier, NSString * _Nullable serviceIdentifier);
HMAccessoryCategory *RevenantHomeKitAccessoryCategory(NSString *categoryType);

HMCharacteristicMetadata *RevenantHomeKitCharacteristicMetadataForRecord(NSMutableDictionary *record);

NSString * _Nullable RevenantHomeKitAccessoryCategoryDescription(NSString * _Nullable categoryType);

@interface HMAccessoryCategory () @property (nonatomic, copy, nullable) NSString *revenant_categoryType; @end
@interface HMNumberRange () @property (nonatomic, strong, nullable) NSNumber *revenant_minValue;
@property (nonatomic, strong, nullable) NSNumber *revenant_maxValue; @end
@interface HMAccessory () @property (nonatomic, copy) NSString *revenant_identifier;
@property (nonatomic, copy, nullable) NSString *revenant_homeIdentifier;
@property (nonatomic, weak, nullable) id<HMAccessoryDelegate> revenant_delegate; @end
@interface HMAction () @property (nonatomic, copy) NSString *revenant_identifier; @end
@interface HMService () @property (nonatomic, copy) NSString *revenant_identifier;
@property (nonatomic, copy, nullable) NSString *revenant_accessoryIdentifier; @end
@interface HMCharacteristic () @property (nonatomic, copy) NSString *revenant_identifier;
@property (nonatomic, copy, nullable) NSString *revenant_serviceIdentifier; @end
@interface HMCharacteristicMetadata () @property (nonatomic, strong) NSMutableDictionary *revenant_record; @end
@interface HMCharacteristicWriteAction () @property (nonatomic, strong, nullable) HMCharacteristic *revenant_characteristic;
@property (nonatomic, strong, nullable) id revenant_targetValue; @end

@interface HMAccessory (RevenantHomeKitStore)
- (void)revenant_setHomeIdentifier:(NSString * _Nullable)homeIdentifier;
- (void)revenant_setRoom:(NSString * _Nullable)roomIdentifier;
- (void)revenant_setServiceIdentifiers:(NSArray<NSString *> *)identifiers;
@end
@interface HMService (RevenantHomeKitStore)
- (void)revenant_setAccessoryIdentifier:(NSString * _Nullable)accessoryIdentifier;
- (void)revenant_setCharacteristicIdentifiers:(NSArray<NSString *> *)identifiers;
@end
@interface HMCharacteristic (RevenantHomeKitStore)
- (void)revenant_setServiceIdentifier:(NSString * _Nullable)serviceIdentifier;
- (void)revenant_setValue:(id)value;
- (void)revenant_setProperties:(NSArray<NSString *> *)properties;
@end

#pragma mark - the home graph's own entry points

HMRoom *RevenantHomeKitRoom(NSString *identifier, NSString * _Nullable homeIdentifier);
HMZone *RevenantHomeKitZone(NSString *identifier, NSString * _Nullable homeIdentifier);
HMUser *RevenantHomeKitUser(NSString *identifier, NSString * _Nullable homeIdentifier);
HMServiceGroup *RevenantHomeKitServiceGroup(NSString *identifier, NSString * _Nullable homeIdentifier);
HMHome *RevenantHomeKitHome(NSString *identifier);
HMActionSet *RevenantHomeKitActionSet(NSString *identifier, NSString * _Nullable homeIdentifier);
HMAction *RevenantHomeKitAction(NSString *identifier, NSString * _Nullable homeIdentifier);
HMTrigger *RevenantHomeKitTrigger(NSString *identifier, NSString * _Nullable homeIdentifier);
HMTimerTrigger *RevenantHomeKitTimerTrigger(NSString *identifier, NSString * _Nullable homeIdentifier);

@interface HMRoom () @property (nonatomic, copy) NSString *revenant_identifier;
@property (nonatomic, copy, nullable) NSString *revenant_homeIdentifier; @end
@interface HMZone () @property (nonatomic, copy) NSString *revenant_identifier;
@property (nonatomic, copy, nullable) NSString *revenant_homeIdentifier; @end
@interface HMUser () @property (nonatomic, copy) NSString *revenant_identifier;
@property (nonatomic, copy, nullable) NSString *revenant_homeIdentifier; @end
@interface HMServiceGroup () @property (nonatomic, copy) NSString *revenant_identifier;
@property (nonatomic, copy, nullable) NSString *revenant_homeIdentifier; @end
@interface HMActionSet () @property (nonatomic, copy) NSString *revenant_identifier;
@property (nonatomic, copy, nullable) NSString *revenant_homeIdentifier; @end
@interface HMActionSet (RevenantHomeKitStore) - (void)revenant_setHomeIdentifier:(NSString * _Nullable)homeIdentifier; @end
@interface HMTrigger () @property (nonatomic, copy) NSString *revenant_identifier;
@property (nonatomic, copy, nullable) NSString *revenant_homeIdentifier; @end
@interface HMHome () @property (nonatomic, copy) NSString *revenant_identifier;
@property (nonatomic, copy, nullable) NSString *revenant_homeIdentifier;
@property (nonatomic, weak, nullable) id<HMHomeDelegate> revenant_delegate; @end
@interface HMHomeManager () @property (nonatomic, weak, nullable) id<HMHomeManagerDelegate> revenant_delegate; @end

@interface HMHome (RevenantHomeKitStore)
- (void)revenant_setHomeIdentifier:(NSString * _Nullable)homeIdentifier;
- (NSMutableArray *)revenant_orderFor:(NSString *)key;
- (void)revenant_setOrder:(NSArray *)order for:(NSString *)key;
- (void)revenant_append:(NSString *)identifier to:(NSString *)key;
- (BOOL)revenant_remove:(NSString *)identifier from:(NSString *)key named:(NSString *)what;
- (BOOL)revenant_nameInUse:(NSString *)name;
- (BOOL)revenant_holdsAccessory:(HMAccessory *)accessory;
@end
@interface HMUser (RevenantHomeKitStore)
- (void)revenant_setName:(NSString *)name;
@property (nonatomic, strong, nullable) id revenant_homeAccessControl;
@end
@interface HMTrigger (RevenantHomeKitStore) - (void)revenant_setHomeIdentifier:(NSString * _Nullable)homeIdentifier; @end
@interface HMTimerTrigger (RevenantHomeKitStore)
- (void)revenant_applyName:(NSString * _Nullable)name;
- (void)revenant_applyFireDate:(NSDate * _Nullable)fireDate;
- (void)revenant_applyRecurrence:(NSDateComponents * _Nullable)recurrence;
@end
@interface NSObject (RevenantHomeKitDelegate)
- (void)revenant_tellHome:(SEL)selector object:(id)object block:(void (^)(id<HMHomeDelegate> delegate, HMHome *home, id object))block;
@end


#pragma mark - the events of iOS 9.0

HMEvent *RevenantHomeKitEvent(NSString *identifier, NSString *kind);
HMEventTrigger *RevenantHomeKitEventTrigger(NSString *identifier, NSString * _Nullable homeIdentifier);
HMHomeAccessControl *RevenantHomeKitHomeAccessControl(HMHome *home, HMUser *user);

@interface HMEvent () @property (nonatomic, copy) NSString *revenant_identifier; @end
@interface HMCharacteristicEvent () @property (nonatomic, strong, nullable) HMCharacteristic *revenant_characteristic;
@property (nonatomic, strong, nullable) id revenant_triggerValue; @end
@interface HMLocationEvent () @property (nonatomic, strong, nullable) CLCircularRegion *revenant_region; @end
@interface HMEventTrigger () @property (nonatomic, copy) NSString *revenant_identifier;
@property (nonatomic, copy, nullable) NSString *revenant_homeIdentifier; @end
@interface HMHomeAccessControl () @property (nonatomic, weak, nullable) HMHome *revenant_home;
@property (nonatomic, strong, nullable) HMUser *revenant_user; @end

@interface HMEventTrigger (RevenantHomeKitStore)
- (void)revenant_setHomeIdentifier:(NSString * _Nullable)homeIdentifier;
- (void)revenant_applyName:(NSString * _Nullable)name;
- (void)revenant_applyEvents:(NSArray<HMEvent *> * _Nullable)events forKey:(NSString *)key;
- (void)revenant_applyPredicate:(NSPredicate * _Nullable)predicate;
- (NSArray<HMEvent *> *)revenant_eventsForKey:(NSString *)key;
@end

#pragma mark - the time events of iOS 11.0


@interface HMDurationEvent () @property (nonatomic, strong, nullable) NSNumber *revenant_duration; @end
@interface HMMutableDurationEvent () @end
@interface HMCalendarEvent () @property (nonatomic, strong, nullable) NSDateComponents *revenant_fireDateComponents; @end
@interface HMMutableCalendarEvent () @end
@interface HMSignificantTimeEvent () @property (nonatomic, copy, nullable) NSString *revenant_significantEvent;
@property (nonatomic, strong, nullable) NSNumber *revenant_offset; @end
@interface HMMutableSignificantTimeEvent () @end
@interface HMPresenceEvent () @property (nonatomic, strong, nullable) NSNumber *revenant_presenceEventType;
@property (nonatomic, strong, nullable) NSNumber *revenant_presenceUserType; @end
@interface HMMutablePresenceEvent () @end
@interface HMMutableCharacteristicEvent () @end

@interface HMAccessorySetupPayload () @property (nonatomic, strong, nullable) NSURL *revenant_setupPayloadURL;
@property (nonatomic, strong, nullable) HMAccessoryOwnershipToken *revenant_ownershipToken;
@end

@interface HMAccessorySetupResult (RevenantHomeKitSetup)
- (instancetype)revenant_initWithHomeIdentifier:(NSUUID *)homeIdentifier
                       accessoryIdentifiers:(NSArray<NSUUID *> *)accessoryIdentifiers
    __attribute__((objc_method_family(init)));
@end
@interface HMCharacteristicThresholdRangeEvent () @property (nonatomic, strong, nullable) HMCharacteristic *revenant_characteristic;
@property (nonatomic, strong, nullable) HMNumberRange *revenant_thresholdRange; @end
@interface HMMutableCharacteristicThresholdRangeEvent () @end

NS_ASSUME_NONNULL_END

#endif
