// HMAccessoryVendor26_1.m - the two 26.1 members of HMAccessory that a vendor service would fill, in a
// 26.1 object of their own.
//
// HMAccessory+Vendor.h:17 and :24 are the two declarations:
//
//   @property (nonatomic, readonly, getter=isVendorAccessory) BOOL vendorAccessory
//       API_AVAILABLE(ios(26.1), watchos(26.1), tvos(26.1)) API_UNAVAILABLE(macos);
//   @property (nullable, nonatomic, readonly, copy) NSNumber *HAPInstanceID NS_REFINED_FOR_SWIFT
//       API_AVAILABLE(ios(26.1), watchos(26.1), tvos(26.1)) API_UNAVAILABLE(macos);
//
// Both are `readonly` and both describe what a vendor has published about an accessory: the header's own
// account of the pair is that a vendor accessory is one whose HAP public key the vendor has published,
// and the instance identifier is the identifier the vendor published with it. This port holds no vendor
// service to ask and no published key to read, so every accessory it holds answers NO and nil - which is
// what the header's own answer would be for an accessory no vendor has published, and what `nullable`
// allows for the identifier.
//
// Neither needs storage, so a category is the whole of the shape here and no ivar is involved. The
// object is its own file because an object holds API of exactly one release
// (modules/apple/backports.lua's releases_in, read by tools/release-split.lua) and the class is 8.0, in
// HMAccessoryServiceCharacteristic8_0.m.

#import <Foundation/Foundation.h>
#import <HomeKit/HomeKit.h>

@implementation HMAccessory (CharonHomeKit26_1)

// HMAccessory+Vendor.h:17, `readonly` with getter=isVendorAccessory. NO for every accessory this port
// holds, because the question is whether a vendor published a key for it and this release has no vendor
// service at all. A hard NO is the answer and not a stub: there is nothing that could ever make it YES.
- (BOOL)isVendorAccessory
{
    return NO;
}

// HMAccessory+Vendor.h:24, `nullable, readonly, copy` over an NSNumber - Apple's own type for it, not a
// string, and the reason a caller reads it rather than the identifier. nil is the answer for every
// accessory this port holds, for the same reason, and nil is what the header's `nullable` allows.
- (NSNumber *)HAPInstanceID
{
    return nil;
}

@end