#import "CharonHomeKitInternal.h"

@implementation HMAccessControl

CHARON_HOMEKIT_UNAVAILABLE_INIT

- (instancetype)charon_initWithStore:(CharonHomeKitStore *)store identifier:(NSUUID *)identifier __attribute__((objc_method_family(init)))
{
    (void)store;
    (void)identifier;
    self = [super init];
    return self;
}

@end
