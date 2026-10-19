#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"

@implementation HKQueryAnchor {
    NSInteger _sequence;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (instancetype)charon_anchorWithSequence:(NSInteger)sequence
{
    HKQueryAnchor *anchor = [[HKQueryAnchor alloc] init];
    anchor->_sequence = sequence;
    return anchor;
}

- (instancetype)init
{
    return [super init];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    HKQueryAnchor *anchor = [super init];
    if (anchor)
        anchor->_sequence = [coder decodeIntForKey:@"sequence"];
    return anchor;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInt:_sequence forKey:@"sequence"];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [HKQueryAnchor charon_anchorWithSequence:_sequence];
}

- (NSInteger)charon_sequence
{
    return _sequence;
}

+ (instancetype)anchorFromValue:(NSUInteger)value
{
    return [self charon_anchorWithSequence:(NSInteger)value];
}

- (BOOL)isEqual:(id)other
{
    if (self == other)
        return YES;
    if (![other isKindOfClass:[HKQueryAnchor class]])
        return NO;
    return _sequence == ((HKQueryAnchor *)other).charon_sequence;
}

- (NSUInteger)hash
{
    return (NSUInteger)_sequence;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"HKQueryAnchor at %ld", (long)_sequence];
}

@end
