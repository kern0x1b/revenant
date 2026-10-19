// MPSGraphType, from the header of MPSGraphCore.h in the SDK of iOS 16.4. One object per release: the
// band machinery keeps an object whole or drops it whole, so a file here carries the API of exactly one
// release. It is the root of the shaped types and of nothing else, so it is bookkeeping.

#import "CharonMPSGraph.h"

@implementation MPSGraphType

- (id)copyWithZone:(NSZone *)zone
{
    // A type is a value: a copy is the object itself unless a subclass holds state that must be
    // duplicated, which MPSGraphShapedType does.
    return self;
}

+ (BOOL)supportsSecureCoding
{
    return NO;
}

@end
