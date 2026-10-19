#ifndef CHARON_HOMEKIT_CONSTRUCTION_H
#define CHARON_HOMEKIT_CONSTRUCTION_H

#import <Foundation/Foundation.h>
#import <HomeKit/HomeKit.h>

@class CharonHomeKitStore;

#define CHARON_HOMEKIT_CONSTRUCTION(cls) \
    @interface cls (CharonHomeKitConstruction) \
    - (instancetype)charon_initWithStore:(CharonHomeKitStore *)store \
                               identifier:(NSUUID * _Nullable)identifier \
    __attribute__((objc_method_family(init))); \
    @end

CHARON_HOMEKIT_CONSTRUCTION(HMRoom)
CHARON_HOMEKIT_CONSTRUCTION(HMZone)
CHARON_HOMEKIT_CONSTRUCTION(HMUser)
CHARON_HOMEKIT_CONSTRUCTION(HMServiceGroup)
CHARON_HOMEKIT_CONSTRUCTION(HMActionSet)
CHARON_HOMEKIT_CONSTRUCTION(HMHome)
CHARON_HOMEKIT_CONSTRUCTION(HMHomeManager)
CHARON_HOMEKIT_CONSTRUCTION(HMTrigger)
CHARON_HOMEKIT_CONSTRUCTION(HMTimerTrigger)
CHARON_HOMEKIT_CONSTRUCTION(HMEventTrigger)
CHARON_HOMEKIT_CONSTRUCTION(HMCharacteristicEvent)
CHARON_HOMEKIT_CONSTRUCTION(HMLocationEvent)
CHARON_HOMEKIT_CONSTRUCTION(HMEvent)
CHARON_HOMEKIT_CONSTRUCTION(HMAccessControl)
CHARON_HOMEKIT_CONSTRUCTION(HMHomeAccessControl)
CHARON_HOMEKIT_CONSTRUCTION(HMTimeEvent)
CHARON_HOMEKIT_CONSTRUCTION(HMDurationEvent)
CHARON_HOMEKIT_CONSTRUCTION(HMMutableDurationEvent)
CHARON_HOMEKIT_CONSTRUCTION(HMCalendarEvent)
CHARON_HOMEKIT_CONSTRUCTION(HMMutableCalendarEvent)
CHARON_HOMEKIT_CONSTRUCTION(HMSignificantTimeEvent)
CHARON_HOMEKIT_CONSTRUCTION(HMMutableSignificantTimeEvent)
CHARON_HOMEKIT_CONSTRUCTION(HMPresenceEvent)
CHARON_HOMEKIT_CONSTRUCTION(HMMutablePresenceEvent)
CHARON_HOMEKIT_CONSTRUCTION(HMMutableCharacteristicEvent)
CHARON_HOMEKIT_CONSTRUCTION(HMCharacteristicThresholdRangeEvent)
CHARON_HOMEKIT_CONSTRUCTION(HMMutableCharacteristicThresholdRangeEvent)
CHARON_HOMEKIT_CONSTRUCTION(HMNumberRange)

#undef CHARON_HOMEKIT_CONSTRUCTION

#define CHARON_HOMEKIT_NIL_INIT                                                             \
    -(instancetype)init                                                                     \
    {                                                                                      \
        return nil;                                                                        \
    }

#define CHARON_HOMEKIT_UNAVAILABLE_INIT                                                     \
    -(instancetype)init                                                                     \
    {                                                                                      \
        [NSException raise:NSInternalInconsistencyException                                 \
                        format:@"%@ is unavailable", NSStringFromSelector(_cmd)];           \
        return nil;                                                                        \
    }

NSUUID *CharonHomeKitUUID(NSString * _Nullable identifier);
NSString * _Nullable CharonHomeKitUUIDString(NSUUID * _Nullable identifier);
NSString *CharonHomeKitNewIdentifier(void);

#endif
