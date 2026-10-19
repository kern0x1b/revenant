// HKQueryAnchor: how far a query of this store has been answered.
//
// The class arrived in iOS 9.0, so it is a file of its own: one object carries the API of one
// release (COORDINATION section 5, "one release per object file, or check_registry fails").
//
// An anchor is the store's own write sequence. The release's anchor is an opaque value the caller
// keeps and hands back, and +anchorFromValue: is how it makes one of those from a value it was given -
// a value a caller persisted between launches, in the archive of a previous one. This port's value is
// the sequence, as a number, which is what the store keeps its own anchors in and what a caller
// persists the same way.

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

// How far this store's own write sequence has been answered. A position in the store is what the
// release's anchor is as well, and it is what lets an anchored query be asked again and be answered
// with only what came after it.
// The position, under the port's own name: no SDK header of any release declares -sequence on
// HKQueryAnchor, and the release's own anchor is an opaque value, so the number this class keeps is
// the port's and is named as the port's.
- (NSInteger)charon_sequence
{
    return _sequence;
}

// An anchor from the integer a caller obtained from the pre-9.0 form of HKAnchoredObjectQuery. That
// integer was a position in the health store, and this port's anchor is a position in its store, so
// handing one back here positions the query where the value it was taken from left off: the same
// number, the same meaning, which is what the release's own method is for.
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
