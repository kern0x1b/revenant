// HMAccessControl, of iOS 11.2: the generic base of the two access controls HomeKit has. It carries
// nothing of its own -- the header declares a class and an unavailable -init -- and it is here because
// HMHomeAccessControl is a subclass of it, and a subclass cannot link without its base.
//
// One release's API per object file, which is what the band machinery needs.
#import "CharonHomeKitInternal.h"

@implementation HMAccessControl

// -init, as the release's own class answers it: the body read out of the arm64e cache of iOS 16.0
// raises NSInternalInconsistencyException whose reason is Apple's own sentence for the selector, and
// facts/HomeKit/HMAccessoryProfile.md carries the body, the literal and the names out of it.
CHARON_HOMEKIT_UNAVAILABLE_INIT

// The release marks -init and +new unavailable, so the class is made through the port's own
// construction; see CharonHomeKitConstruction.h for why the method family attribute is what lets it
// assign self.
- (instancetype)charon_initWithStore:(CharonHomeKitStore *)store identifier:(NSUUID *)identifier __attribute__((objc_method_family(init)))
{
    (void)store;
    (void)identifier;
    self = [super init];
    return self;
}

@end
