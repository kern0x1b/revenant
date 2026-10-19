#import "CharonHomeKitInternal.h"

@implementation HMAccessorySetupResult

@synthesize homeUniqueIdentifier = _homeUniqueIdentifier,
          accessoryUniqueIdentifiers = _accessoryUniqueIdentifiers;

- (instancetype)charon_initWithHomeIdentifier:(NSUUID *)homeIdentifier
                       accessoryIdentifiers:(NSArray<NSUUID *> *)accessoryIdentifiers
    __attribute__((objc_method_family(init)))
{
    self = [super init];
    if (self) {
        _homeUniqueIdentifier = [homeIdentifier copy];
        _accessoryUniqueIdentifiers = [accessoryIdentifiers copy];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    HMAccessorySetupResult *copy = [[self class] allocWithZone:zone];
    copy->_homeUniqueIdentifier = [_homeUniqueIdentifier copy];
    copy->_accessoryUniqueIdentifiers = [_accessoryUniqueIdentifiers copy];
    return copy;
}

@end
