#import "RevenantHomeKitInternal.h"

@implementation HMAccessControl

REVENANT_HOMEKIT_UNAVAILABLE_INIT

- (instancetype)revenant_initWithStore:(RevenantHomeKitStore *)store identifier:(NSUUID *)identifier __attribute__((objc_method_family(init)))
{
    (void)store;
    (void)identifier;
    self = [super init];
    return self;
}

@end
