// HMAccessoryCategory, of iOS 9.0: what an accessory's category is, by type.
//
// **What is not here, and why.** -localizedDescription is a localized string: the value the release
// returns is the one its own localization table holds for the running language, not a fixed English
// name. No release on this machine ships a HomeKit resource bundle this port could read, so there is
// nothing to read the value from, and a name written
// here would be one no release ships -- a value that looks right and describes nothing. The property
// is registered absent with that reason rather than answered with a guess. See
// facts/HomeKit/HMAccessoryCategory.md.
//
// What is absent is not a HomeKit in the caches: by substring count with a boundary, HMAccessory is in
// the held arm64 caches of 8.0, 9.0, 11.0 and 12.0. What is absent is a HomeKit framework to link on
// this host, and the SDK's own HomeKit headers mark their types API_UNAVAILABLE(macos).
#import "CharonHomeKitInternal.h"

@implementation HMAccessoryCategory

@synthesize charon_categoryType = _charon_categoryType;

- (instancetype)init
{
    self = [super init];
    return self;
}

- (NSString *)categoryType
{
    return [self.charon_categoryType copy];
}

@end

HMAccessoryCategory *CharonHomeKitAccessoryCategory(NSString *categoryType)
{
    HMAccessoryCategory *category = [[HMAccessoryCategory alloc] init];
    category.charon_categoryType = categoryType;
    return category;
}
