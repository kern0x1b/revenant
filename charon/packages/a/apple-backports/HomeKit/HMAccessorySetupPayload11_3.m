// HMAccessorySetupPayload, of iOS 11.3: the payload an accessory's HomeKit setup code produces, which
// a home is asked to add an accessory from.
//
// One release's API per object file. This file is of 11.3 alone, and the 13.0 initialiser that shares
// the class name is a separate object in HMAccessorySetupPayload13_0.m -- the gate refuses an object that
// carries the API of two releases, and the cache ladder decides which of the two a given band links:
// this one for 11.3 and 12.0, that one from 13.0, and a band from 13.0 up links both.
//
// The 26.2 header, HMAccessorySetupPayload.h:33-57:
//   HM_EXTERN API_AVAILABLE(ios(11.3)) API_UNAVAILABLE(macos, watchos, tvos, macCatalyst)
//       @interface HMAccessorySetupPayload : NSObject
//         - (instancetype)init NS_UNAVAILABLE;                                     line 36
//         + (instancetype)new NS_UNAVAILABLE;                                     line 37
//         - (nullable instancetype)initWithURL:(nullable NSURL *)setupPayloadURL;  line 46
//         - (nullable instancetype)initWithURL:(NSURL *)setupPayloadURL
//                            ownershipToken:(nullable HMAccessoryOwnershipToken *)ownershipToken
//             API_AVAILABLE(ios(13.0)) ...                                        line 57
//
// **The class declares no property.** That is the whole of the release's surface here: a payload is
// something a home is GIVEN, and the graph reads it by handing it on rather than by asking it. So the
// port holds the URL it was made from and the header's two unavailable methods stay unbound, which is
// what the release's own marks ask for and is a row of its own.
//
// **What the port cannot do.** A real device reads the payload's bytes and adds the accessory to the
// home over HomeKit's own transport, and neither half exists here: there is no HomeKit daemon to add
// an accessory to and no transport to reach it with. The port therefore does the part it can be
// responsible for -- it holds exactly what it was given, and it answers nil for the failure the header
// documents -- and facts/HomeKit/HMAccessorySetup.md records what a device does that this does not.
// Nothing here opens a network connection or reads a HomeKit store on this machine.

#import "CharonHomeKitInternal.h"

@implementation HMAccessorySetupPayload

@synthesize charon_setupPayloadURL = _charon_setupPayloadURL;
@synthesize charon_ownershipToken = _charon_ownershipToken;  // written by the 13.0 object's initialiser

// The header types both the parameter and the return nullable and says the object comes back "if
// successful or nil on error". There is one failure the port can actually recognise, and it is the one
// the header's own signature points at: with no URL there is no setup payload to add, so nil is the
// documented answer rather than a payload holding nothing. A URL the port is given is kept exactly as it
// was given -- the port does not re-encode it, resolve it, or open it -- because deciding whether the
// accessory behind it really is there is the HomeKit daemon's work and not this object's.
- (instancetype)initWithURL:(NSURL *)setupPayloadURL
{
    if (setupPayloadURL == nil) {
        return nil;
    }
    self = [super init];
    if (self) {
        _charon_setupPayloadURL = setupPayloadURL;
    }
    return self;
}

@end
