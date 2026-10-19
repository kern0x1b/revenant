// HMAccessorySetupPayload, of iOS 13.0: the initialiser that takes the accessory's ownership token
// along with its setup payload URL.
//
// One release's API per object file. This file is of 13.0 alone; the 11.3 initialiser of the same class
// is a separate object in HMAccessorySetupPayload11_3.m, and a band from 13.0 up links both, because the
// 11.3 one is API the device has and this one is API added to it.
//
// The 26.2 header declares it at HMAccessorySetupPayload.h:48-57, with the two arguments below:
//   - (nullable instancetype)initWithURL:(NSURL *)setupPayloadURL
//                    ownershipToken:(nullable HMAccessoryOwnershipToken *)ownershipToken
//        API_AVAILABLE(ios(13.0))API_UNAVAILABLE(macos, watchos, tvos);
//
// **The difference from 11.3 is the token, and it is a difference in what a device can check.** With the
// token the device can prove the caller owns the accessory before it adds it; without one it adds the
// accessory on the strength of the setup code alone. The port records which of the two a payload was
// made with, and records the token opaquely, because HMAccessoryOwnershipToken is a class the port does
// not carry -- see the facts file -- and there is nothing here that could make one.
//
// **What the port cannot do.** Verifying that the token proves ownership is the accessory's and the
// daemon's work; the port has neither the accessory nor a HomeKit transport, so it neither sends the
// token anywhere nor opens a connection. Nothing in this file touches the network or a real HomeKit store
// on this machine.

#import "CharonHomeKitInternal.h"

// A CATEGORY, not a second @implementation: two objects linked into one binary cannot both define
// the class (the 6.1.3 gate stopped on duplicate _OBJC_CLASS_$_HMAccessorySetupPayload), so the object that
// holds the class is the 11.3 one and this adds the 13.0 initialiser to it. The token's storage is that
// object's, declared in the shared header; the token is held as the SDK's own type and read only for its
// presence, because the port does not carry HMAccessoryOwnershipToken and cannot inspect one - copying its
// bytes would claim a check the port never made. A nil token is not an error, the header types it nullable.
@implementation HMAccessorySetupPayload (Charon13_0)

- (instancetype)initWithURL:(NSURL *)setupPayloadURL
         ownershipToken:(HMAccessoryOwnershipToken *)ownershipToken
{
    // The header makes the URL nonnull here and the return nullable, and those two go together: this
    // overload was added for a caller that has a real setup payload URL, and the documented nil comes
    // back when it does not have one.
    if (setupPayloadURL == nil) {
        return nil;
    }
    self = [super init];
    if (self) {
        // The URL goes into the 11.3 object's own storage, through the setter that object defines, so a
        // payload read by either object's accessor sees the URL it was made with.
        self.charon_setupPayloadURL = setupPayloadURL;
        self.charon_ownershipToken = ownershipToken;
    }
    return self;
}

@end
