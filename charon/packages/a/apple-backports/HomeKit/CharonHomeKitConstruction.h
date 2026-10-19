// The port's own construction of the graph's classes.
//
// **Why this exists.** The 26.2 headers mark `-init` and `+new` NS_UNAVAILABLE on HMRoom, HMZone,
// HMUser, HMServiceGroup, HMActionSet, HMHome, HMHomeManager, HMTrigger and HMTimerTrigger: an
// application is not meant to make those, the manager is a shared object on a real device, and the rest
// are made through the graph. The port has to make them -- it is the thing that keeps the graph -- and
// `[[HMRoom alloc] init]` does not compile against those marks.
//
// **Why the method is named the way it is.** A method may only assign `self` when it is in the `init`
// method family, and clang decides that from the attribute, not from the spelling: a selector called
// `charon_init…` is not in the family, and writing `self = [super init]` in it is rejected with
// "cannot assign to 'self' outside of a method in the init family". `objc_method_family(init)` puts it
// in the family under a name that is the port's own, so nothing here collides with the header's.
//
// The store is a parameter rather than a global so that the class does not reach for the singleton
// behind the caller's back, and the identifier is an NSUUID because that is what Apple's headers give
// the uniqueIdentifier family; the store's own keys are the UUID's string, and the pair of functions at
// the bottom is the conversion every graph edge is written with.
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

// **-init, where Apple's own class has one and the header closes it.** The 26.2 headers mark `-init`
// NS_UNAVAILABLE on the classes above, which decides nothing at run time, and Apple's own class
// implements it on ten of them. What it does is read out of the code of the arm64e cache of iOS 16.0 -
// facts/HomeKit/HMAccessoryProfile.md carries every body, the literal each one names and the symbol the
// call resolves to - and the port answers with that body rather than with NSObject's, which is what a
// caller reaches today and which is a different answer for all ten. Three shapes, and nothing else:
//
//   * six of them - HMActionSet, HMHome, HMRoom, HMServiceGroup, HMTimerTrigger, HMZone - release the
//     receiver and answer nil (`_objc_release` with the receiver in x0, then x0 = 0). ARC has no
//     `[self release]` and the port does not perform one, so what a caller reaches is nil, which is
//     what the body makes observable;
//   * two of them - HMAccessControl, HMUser - raise `NSInternalInconsistencyException` whose reason is
//     Apple's own sentence for the selector, built by `+[NSString stringWithFormat:@"%@ is
//     unavailable", NSStringFromSelector(_cmd)]`. It is built from the selector and not written out,
//     because that is how the framework builds it, and the sentence a caller sees is then "init is
//     unavailable";
//   * the other two - HMAction, HMHomeManager - construct, and each answers with the port's own
//     construction rather than with a macro, in the file that defines the class.
//
// +new is not in this header and is not in any of those classes: the metaclass of all ten carries no
// +new of its own in the cache of iOS 16.0, so each of them inherits NSObject's, which is `[[self
// alloc] init]` and therefore reaches the -init measured above.
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

// The identifier of an object as the type Apple's headers give it, and as the string the store keys it
// by. HomeKit's uniqueIdentifier family is an NSUUID; a property list holds strings; every accessor is
// written with this pair, so a record's key and the value handed back cannot disagree about which.
NSUUID *CharonHomeKitUUID(NSString * _Nullable identifier);
NSString * _Nullable CharonHomeKitUUIDString(NSUUID * _Nullable identifier);
// A fresh identifier, in the shape HomeKit's own have.
NSString *CharonHomeKitNewIdentifier(void);

#endif
