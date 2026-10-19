#import <Foundation/Foundation.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation NSUUID (CharonCompare)

- (NSComparisonResult)compare:(NSUUID *)otherUUID
{
    if (self == otherUUID)
        return NSOrderedSame;
    uuid_t mine = {0}, theirs = {0};
    [self getUUIDBytes:mine];
    [otherUUID getUUIDBytes:theirs];
    int order = memcmp(mine, theirs, sizeof mine);
    return order < 0 ? NSOrderedAscending : order > 0 ? NSOrderedDescending : NSOrderedSame;
}

@end
