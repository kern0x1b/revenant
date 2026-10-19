// The two 10.0 members of HMAccessory that say where the accessory is: the home it belongs to, and the
// camera profiles it publishes.
//
// One object per release: this file is of 10.0 alone, and both members are declared on the 8.0 class.
//
// **HMAccessory.home.** The 26.2 header, HMAccessory.h:37:
//   @property (nullable, nonatomic, readonly, weak) HMHome *home
//       API_AVAILABLE(ios(10.0), watchos(3.0), tvos(10.0), macCatalyst(14.0)) API_UNAVAILABLE(macos);
// nullable, weak, readonly, and of 10.0. The port's accessory already carries the identifier of the home
// it belongs to - charon_homeIdentifier, the same field the home graph's own entry points are given - so
// the answer is that home, materialised by the graph's own CharonHomeKitHome(identifier). There is no
// second way to reach a home in this library, and nothing is invented: an accessory with no home
// identifier answers nil, which is what nullable allows.
//
// **HMAccessory.cameraProfiles.** The header declares it in HMAccessory+Camera.h:28:
//   @property (nullable, nonatomic, readonly, copy) NSArray<HMCameraProfile *> *cameraProfiles
//       API_AVAILABLE(ios(10.0), ...) API_UNAVAILABLE(macos);
// **copy**, where home above is **weak**, and an NSArray where home is a single object - the two
// attributes differ and the AST check compares each of them. The element type is HMCameraProfile, which
// this port carries in HMAccessoryProfile10_0.m of the same release, so the answer's type exists and this
// accessor is written with it.
//
// The profiles are the ones the graph holds for this accessory, read from the accessory's own record
// through the graph's own list field - the same helper the home's rooms and zones are read with - and each
// is built by HMAccessoryProfile's own graph initialiser, so there is no second way to make a profile in
// this library. An accessory that publishes none answers an empty array: the header's nullable allows it
// and an array is what the property is, so a caller can iterate the answer without asking whether there
// is one.

#import "CharonHomeKitInternal.h"
#import "CharonHomeKitModel.h"
#import "CharonHomeKitStore.h"

// The element type of the answer. The class is of the same release, in the file named above; the
// declaration here is only so the compiler knows the name before that file is read.
@class HMCameraProfile;

// The graph's own way of making a profile, so the accessor below does not invent a second one.
@interface HMAccessoryProfile (CharonHomeKit10Internal)
+ (instancetype)charon_profileInStore:(CharonHomeKitStore *)store
                            identifier:(NSUUID *)identifier
                             accessory:(nullable HMAccessory *)accessory;
@end

// A category, not a second @implementation of the class: the class is implemented once, in
// HMAccessoryServiceCharacteristic8_0.m, and a second definition of it is a duplicate symbol at the link.
@implementation HMAccessory (CharonHome10)

// The header's own word for the home: nullable, so an accessory that belongs to no home answers nil, and
// the one that does is the home its own identifier names, built by the graph's entry point rather than
// a second construction of a home.
- (HMHome *)home
{
    NSString *homeIdentifier = self.charon_homeIdentifier;
    if (!homeIdentifier.length)
        return nil;
    return CharonHomeKitHome(homeIdentifier);
}

// HMAccessory+Camera.h:28 - nullable, readonly, copy, and an NSArray. The accessory's own record holds
// the order of its profiles, the way a home's record holds the order of its rooms, and each profile is
// made by the graph's own initialiser for that class.
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
