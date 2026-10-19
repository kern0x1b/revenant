// HMAccessoryProfile, of iOS 10.0, and HMCameraProfile, the 10.0 subclass of it: what an accessory
// publishes about itself.
//
// One object per release: this file is of 10.0 alone.
//
// A profile is a description, not a device. `uniqueIdentifier` is the profile's own, `services` are the
// accessory's services as the profile lists them, and `accessory` is the accessory it belongs to - a weak
// reference, because the profile does not keep the accessory alive, exactly as the header says.
//
// The 26.2 header, HMAccessoryProfile.h:19-20, 27, 32, 37:
//   HM_EXTERN NS_SWIFT_SENDABLE API_AVAILABLE(ios(10.0), watchos(3.0), tvos(10.0), macCatalyst(14.0))
//       API_UNAVAILABLE(macos);
//   @interface HMAccessoryProfile : NSObject
//     @property (nonatomic, readonly, copy) NSUUID *uniqueIdentifier;          line 27
//     @property (nonatomic, readonly, strong) NSArray<HMService *> *services;   line 32
//     @property (nonatomic, readonly, weak) HMAccessory *accessory;            line 37
// None of the three is nullable, and that is what the contract check asserts: a profile that answered nil
// for a property the header types as nonnull would be answering something the release does not.
//
// HMCameraProfile, HMCameraProfile.h:25-26, subclasses this one and adds four optional controls:
//   @property (nullable, nonatomic, readonly, strong) HMCameraStreamControl *streamControl;    line 33
//   @property (nullable, nonatomic, readonly, strong) HMCameraSnapshotControl *snapshotControl; line 38
//   @property (nullable, nonatomic, readonly, strong) HMCameraSettingsControl *settingsControl;  line 43
//   @property (nullable, nonatomic, readonly, strong) HMCameraAudioControl *speakerControl;     line 48
// All four are **nullable**, unlike the three above, and that difference is the property's own: an
// accessory's camera does not have to publish every control, and nil is how it says which.
//
// A profile is made the way the release makes the objects it has no public initialiser for: the header
// declares none for this class, and the graph's own entry point is the one place a profile is created, so
// -charon_initWithStore:identifier: on this class is that path and the accessory's accessor reuses it
// rather than building a second kind of profile.

#import <HomeKit/HomeKit.h>

#import "CharonHomeKitInternal.h"
#import "CharonHomeKitConstruction.h"
#import "CharonHomeKitStore.h"

// The four camera controls exist in the SDK and the port does not carry them, so a camera profile's four
// controls are answered as nil - which is what the header's nullable allows and what an accessory that
// publishes no control says. Each is named here so the reason is in one place.
@interface HMCameraProfile (CharonHomeKit10Internal)
@property (nullable, nonatomic, readonly, strong) HMCameraStreamControl *streamControl;
@property (nullable, nonatomic, readonly, strong) HMCameraSnapshotControl *snapshotControl;
@property (nullable, nonatomic, readonly, strong) HMCameraSettingsControl *settingsControl;
@property (nullable, nonatomic, readonly, strong) HMCameraAudioControl *speakerControl;
@end

// The graph's one way of making a profile that already exists: the accessory accessor in
// HMAccessoryHome10_0.m asks for it, so a profile is never built a second way. The four camera controls
// are not asked for here - a profile built for the graph publishes none, which is the header's nullable.
@interface HMAccessoryProfile (CharonHomeKit10Internal)
+ (instancetype)charon_profileInStore:(CharonHomeKitStore *)store
                            identifier:(NSUUID *)identifier
                             accessory:(nullable HMAccessory *)accessory;
@end

@interface HMAccessoryProfile (CharonHKConstruction)
- (instancetype)charon_initWithStore:(CharonHomeKitStore *)store
                          identifier:(NSUUID *_Nullable)identifier
                               accessory:(nullable HMAccessory *)accessory
                                services:(nullable NSArray<HMService *> *)services
    __attribute__((objc_method_family(init)));
@end

@implementation HMAccessoryProfile {
    NSString *_profileIdentifier;
    __weak HMAccessory *_profileAccessory;
    NSArray<HMService *> *_services;
}

- (instancetype)charon_initWithStore:(CharonHomeKitStore *)store
                          identifier:(NSUUID *)identifier
                            accessory:(HMAccessory *)accessory
                             services:(NSArray<HMService *> *)services
{
    HMAccessoryProfile *profile = [super init];
    if (profile) {
        // The release's own identifiers come from the graph, not from a counter here: an accessory's
        // profile is something the accessory publishes, and its identity is part of that record.
        profile->_profileIdentifier = [CharonHomeKitNewIdentifier() copy];
        CharonHomeKitRecord(@"profiles", profile->_profileIdentifier);
        profile->_profileAccessory = accessory;
        profile->_services = [services copy] ?: @[];
    }
    return profile;
}

// The class form of the same path, so a caller holding a class rather than a profile - a subclass, which
// is what -cameraProfiles answers - gets a subclass. +[self alloc] is that subclass, so this is one way
// of making a profile and not two.
+ (instancetype)charon_profileInStore:(CharonHomeKitStore *)store
                            identifier:(NSUUID *)identifier
                             accessory:(HMAccessory *)accessory
{
    return [[self alloc] charon_initWithStore:store
                                   identifier:identifier
                                    accessory:accessory
                                     services:nil];
}

// HMAccessoryProfile.h:27 - nonnull, readonly, copy. A profile always has an identity of its own.
- (NSUUID *)uniqueIdentifier
{
    return CharonHomeKitUUID(_profileIdentifier);
}

// HMAccessoryProfile.h:32 - nonnull, so an array always, and empty when the profile lists no services.
- (NSArray<HMService *> *)services
{
    return _services;
}

// HMAccessoryProfile.h:37 - weak, so this is not a second owner of the accessory.
- (HMAccessory *)accessory
{
    return _profileAccessory;
}

@end

@implementation HMCameraProfile

// The four controls of HMCameraProfile.h:33, 38, 43 and 48, all **nullable**. A camera publishes the
// controls it has, and nil is how it says which it does not. This port carries no control class, so it
// publishes none, and nil is what the header's own nullability allows - it is not a stand-in for a
// value, it is the answer for an accessory that has published nothing. Each is written out rather than
// synthesized, so the reason is on the class and not in a property list.
- (HMCameraStreamControl *)streamControl
{
    return nil;
}

- (HMCameraSnapshotControl *)snapshotControl
{
    return nil;
}

- (HMCameraSettingsControl *)settingsControl
{
    return nil;
}

- (HMCameraAudioControl *)speakerControl
{
    return nil;
}

@end
