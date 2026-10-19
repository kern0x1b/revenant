// HMAccessorySetupResult, of iOS 15.4: what a successful setup hands back -- the home it went into and
// the accessories it added.
//
// One release's API per object file, and this class is of 15.4 alone.
//
// The 26.2 header, HMAccessorySetupResult.h:14-30:
//   HM_EXTERN NS_SWIFT_SENDABLE API_AVAILABLE(ios(15.4)) ... API_UNAVAILABLE(watchos, tvos, visionos)
//   @interface HMAccessorySetupResult : NSObject<NSCopying>
//     @property (readonly, copy) NSUUID *homeUniqueIdentifier;              line 20
//     @property (readonly, copy) NSArray<NSUUID *> *accessoryUniqueIdentifiers;  line 27
//     - (instancetype)init NS_UNAVAILABLE;                                  line 29
//     + (instancetype)new NS_UNAVAILABLE;                                  line 30
//
// **Both -init and +new stay unbound**, which is the release's own request and is a row of its own. So
// the port cannot build a result the way a caller would, and the graph's own entry point is
// -charon_initWithHomeIdentifier:accessoryIdentifiers: below, in the init family under a name of the
// port's own -- the same shape CharonHomeKitConstruction.h uses for the rest of the model.
//
// A result is a report, not a handle: it names the home and the accessories and holds nothing that can
// be changed afterwards, which is why both properties are `readonly, copy` and why the construction takes
// the two values and nothing else.

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
    // The two properties, copied again into a new object. Not a shallow copy of self: a result the caller
    // can push accessories into is not the report the header describes.
    HMAccessorySetupResult *copy = [[self class] allocWithZone:zone];
    copy->_homeUniqueIdentifier = [_homeUniqueIdentifier copy];
    copy->_accessoryUniqueIdentifiers = [_accessoryUniqueIdentifiers copy];
    return copy;
}

@end
