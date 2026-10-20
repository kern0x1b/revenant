#ifndef REVENANT_HOMEKIT_CONSTRUCTION_H
#define REVENANT_HOMEKIT_CONSTRUCTION_H

#import <Foundation/Foundation.h>
#import <HomeKit/HomeKit.h>

@class RevenantHomeKitStore;

#define REVENANT_HOMEKIT_CONSTRUCTION(cls) \
    @interface cls (RevenantHomeKitConstruction) \
    - (instancetype)revenant_initWithStore:(RevenantHomeKitStore *)store \
                               identifier:(NSUUID * _Nullable)identifier \
    __attribute__((objc_method_family(init))); \
    @end

REVENANT_HOMEKIT_CONSTRUCTION(HMRoom)
REVENANT_HOMEKIT_CONSTRUCTION(HMZone)
REVENANT_HOMEKIT_CONSTRUCTION(HMUser)
REVENANT_HOMEKIT_CONSTRUCTION(HMServiceGroup)
REVENANT_HOMEKIT_CONSTRUCTION(HMActionSet)
REVENANT_HOMEKIT_CONSTRUCTION(HMHome)
REVENANT_HOMEKIT_CONSTRUCTION(HMHomeManager)
REVENANT_HOMEKIT_CONSTRUCTION(HMTrigger)
REVENANT_HOMEKIT_CONSTRUCTION(HMTimerTrigger)
REVENANT_HOMEKIT_CONSTRUCTION(HMEventTrigger)
REVENANT_HOMEKIT_CONSTRUCTION(HMCharacteristicEvent)
REVENANT_HOMEKIT_CONSTRUCTION(HMLocationEvent)
REVENANT_HOMEKIT_CONSTRUCTION(HMEvent)
REVENANT_HOMEKIT_CONSTRUCTION(HMAccessControl)
REVENANT_HOMEKIT_CONSTRUCTION(HMHomeAccessControl)
REVENANT_HOMEKIT_CONSTRUCTION(HMTimeEvent)
REVENANT_HOMEKIT_CONSTRUCTION(HMDurationEvent)
REVENANT_HOMEKIT_CONSTRUCTION(HMMutableDurationEvent)
REVENANT_HOMEKIT_CONSTRUCTION(HMCalendarEvent)
REVENANT_HOMEKIT_CONSTRUCTION(HMMutableCalendarEvent)
REVENANT_HOMEKIT_CONSTRUCTION(HMSignificantTimeEvent)
REVENANT_HOMEKIT_CONSTRUCTION(HMMutableSignificantTimeEvent)
REVENANT_HOMEKIT_CONSTRUCTION(HMPresenceEvent)
REVENANT_HOMEKIT_CONSTRUCTION(HMMutablePresenceEvent)
REVENANT_HOMEKIT_CONSTRUCTION(HMMutableCharacteristicEvent)
REVENANT_HOMEKIT_CONSTRUCTION(HMCharacteristicThresholdRangeEvent)
REVENANT_HOMEKIT_CONSTRUCTION(HMMutableCharacteristicThresholdRangeEvent)
REVENANT_HOMEKIT_CONSTRUCTION(HMNumberRange)

#undef REVENANT_HOMEKIT_CONSTRUCTION

#define REVENANT_HOMEKIT_NIL_INIT                                                             \
    -(instancetype)init                                                                     \
    {                                                                                      \
        return nil;                                                                        \
    }

#define REVENANT_HOMEKIT_UNAVAILABLE_INIT                                                     \
    -(instancetype)init                                                                     \
    {                                                                                      \
        [NSException raise:NSInternalInconsistencyException                                 \
                        format:@"%@ is unavailable", NSStringFromSelector(_cmd)];           \
        return nil;                                                                        \
    }

NSUUID *RevenantHomeKitUUID(NSString * _Nullable identifier);
NSString * _Nullable RevenantHomeKitUUIDString(NSUUID * _Nullable identifier);
NSString *RevenantHomeKitNewIdentifier(void);

#endif
