#import "CharonHomeKitInternal.h"
#import "CharonHomeKitModel.h"
#import "CharonHomeKitStore.h"

@class HMCameraProfile;

@interface HMAccessoryProfile (CharonHomeKit10Internal)
+ (instancetype)charon_profileInStore:(CharonHomeKitStore *)store
                            identifier:(NSUUID *)identifier
                             accessory:(nullable HMAccessory *)accessory;
@end

@implementation HMAccessory (CharonHome10)

- (HMHome *)home
{
    NSString *homeIdentifier = self.charon_homeIdentifier;
    if (!homeIdentifier.length)
        return nil;
    return CharonHomeKitHome(homeIdentifier);
}

- (NSArray<HMCameraProfile *> *)cameraProfiles
{
    CharonHomeKitStore *store = [CharonHomeKitStore shared];
    NSMutableArray<HMCameraProfile *> *found = [NSMutableArray array];
    for (NSString *identifier in CharonHomeKitStringListField(CharonHomeKitRecord(@"accessories", self.charon_identifier),
                                                             @"cameraProfiles")) {
        HMCameraProfile *profile = [HMCameraProfile charon_profileInStore:store
                                                              identifier:CharonHomeKitUUID(identifier)
                                                               accessory:self];
        if (profile)
            [found addObject:profile];
    }
    return found;
}

@end
