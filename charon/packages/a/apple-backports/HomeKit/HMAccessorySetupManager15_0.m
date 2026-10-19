// HMAccessorySetupManager, of iOS 15.0: the object an application asks to add an accessory to a home.
//
// One release's API per object file, and this class is of 15.0 alone. Its request and its result are
// 15.4 and are two other classes in two other objects; the cache ladder is what decides that a band from
// 15.0 links this object alone and a band from 15.4 links all three.
//
// The 26.2 header, HMAccessorySetupManager.h:23-39:
//   API_AVAILABLE(ios(15.0))
//   @interface HMAccessorySetupManager : NSObject
//     - (instancetype)init;                                                          line 28
//     - (void)performAccessorySetupUsingRequest:(HMAccessorySetupRequest *)request
//                          completionHandler:(void (^)(HMAccessorySetupResult *result,
//                                                       NSError *error))completionHandler;  line 39
//
// **-performAccessorySetupUsingRequest:completionHandler: is NOT carried, and the reason is hardware.**
// It adds an accessory that is physically present, over HomeKit's own transport to that accessory: the
// manager is a front for a pairing this machine has no radio for and no accessory to pair. So the member
// is left unbound and the registry carries it absent WITH that reason, which is a row of its own rather
// than a silent gap, and the check below is told to expect its absence and says so by name.
//
// **-init is carried, and it is the only member this object binds.** The release declares it available
// on an NSObject subclass, so a port that did not answer it would be missing API the device has.

#import "CharonHomeKitInternal.h"

@implementation HMAccessorySetupManager

- (instancetype)init
{
    // The release's own -init on a plain NSObject subclass, and nothing to refuse: the manager holds no
    // state of its own here, because the one thing it would manage -- an accessory -- is what the port
    // has no way to have.
    self = [super init];
    return self;
}

// -performAccessorySetupUsingRequest:completionHandler: is deliberately absent. See above: it is
// hardware, and the port has neither the accessory nor HomeKit's transport to reach one.

@end
