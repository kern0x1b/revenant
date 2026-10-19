#import "RevenantHomeKitInternal.h"
#import "RevenantHomeKitModel.h"
#import "RevenantHomeKitStore.h"

@class HMCameraProfile;

@interface HMAccessoryProfile (RevenantHomeKit10Internal)
+ (instancetype)revenant_profileInStore:(RevenantHomeKitStore *)store
                            identifier:(NSUUID *)identifier
                             accessory:(nullable HMAccessory *)accessory;
@end

@implementation HMAccessory (RevenantHome10)

- (HMHome *)home
{
    NSString *homeIdentifier = self.revenant_homeIdentifier;
    if (!homeIdentifier.length)
        return nil;
    return RevenantHomeKitHome(homeIdentifier);
}

- (NSArray<HMCameraProfile *> *)cameraProfiles
{
    RevenantHomeKitStore *store = [RevenantHomeKitStore shared];
    NSMutableArray<HMCameraProfile *> *found = [NSMutableArray array];
    for (NSString *identifier in RevenantHomeKitStringListField(RevenantHomeKitRecord(@"accessories", self.revenant_identifier),
                                                             @"cameraProfiles")) {
        HMCameraProfile *profile = [HMCameraProfile revenant_profileInStore:store
                                                              identifier:RevenantHomeKitUUID(identifier)
                                                               accessory:self];
        if (profile)
            [found addObject:profile];
    }
    return found;
}

@end
