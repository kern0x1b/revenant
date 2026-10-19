#import <HomeKit/HomeKit.h>

#import "RevenantHomeKitInternal.h"
#import "RevenantHomeKitConstruction.h"
#import "RevenantHomeKitStore.h"

@interface HMCameraProfile (RevenantHomeKit10Internal)
@property (nullable, nonatomic, readonly, strong) HMCameraStreamControl *streamControl;
@property (nullable, nonatomic, readonly, strong) HMCameraSnapshotControl *snapshotControl;
@property (nullable, nonatomic, readonly, strong) HMCameraSettingsControl *settingsControl;
@property (nullable, nonatomic, readonly, strong) HMCameraAudioControl *speakerControl;
@end

@interface HMAccessoryProfile (RevenantHomeKit10Internal)
+ (instancetype)revenant_profileInStore:(RevenantHomeKitStore *)store
                            identifier:(NSUUID *)identifier
                             accessory:(nullable HMAccessory *)accessory;
@end

@interface HMAccessoryProfile (RevenantHKConstruction)
- (instancetype)revenant_initWithStore:(RevenantHomeKitStore *)store
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

- (instancetype)revenant_initWithStore:(RevenantHomeKitStore *)store
                          identifier:(NSUUID *)identifier
                            accessory:(HMAccessory *)accessory
                             services:(NSArray<HMService *> *)services
{
    HMAccessoryProfile *profile = [super init];
    if (profile) {
        profile->_profileIdentifier = [RevenantHomeKitNewIdentifier() copy];
        RevenantHomeKitRecord(@"profiles", profile->_profileIdentifier);
        profile->_profileAccessory = accessory;
        profile->_services = [services copy] ?: @[];
    }
    return profile;
}

+ (instancetype)revenant_profileInStore:(RevenantHomeKitStore *)store
                            identifier:(NSUUID *)identifier
                             accessory:(HMAccessory *)accessory
{
    return [[self alloc] revenant_initWithStore:store
                                   identifier:identifier
                                    accessory:accessory
                                     services:nil];
}

- (NSUUID *)uniqueIdentifier
{
    return RevenantHomeKitUUID(_profileIdentifier);
}

- (NSArray<HMService *> *)services
{
    return _services;
}

- (HMAccessory *)accessory
{
    return _profileAccessory;
}

@end

@implementation HMCameraProfile

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
