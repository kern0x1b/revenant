// The range layer of TextKit 2: a range between two locations, a selection over ranges, an element of the
// document, a paragraph, and the navigation that answers what a selection moved does. Five classes, and what each
// of them is came from the 26.2 headers of NSTextRange.h, NSTextSelection.h, NSTextSelectionNavigation.h and
// NSTextElement.h; what the host's own UIKit answers is in facts/UIKit/NSTextRange15.md.
//
// An NSTextLocation is a protocol with one method, a comparison, and a range is two of them. Every question a
// range is asked is a comparison of the two locations the ranges are made of, so that is all this file has to
// know about a location, and it is why a range works over any document type at all: the content manager's own
// location, the paragraph's, a test's.

#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-qualifiers"

@implementation NSTextRange

@synthesize location = _location;
@synthesize endLocation = _endLocation;

- (instancetype)initWithLocation:(id<NSTextLocation>)location endLocation:(id<NSTextLocation>)endLocation
{
    // A range whose end is nil is empty at its start, which is what the header for the two-argument initializer
    // says, and which is the one thing an end location of nil has to mean: a range with no end has no contents.
    if ((self = [super init]))
        _location = location;
    // A range with no end of its own has the start as its end, which is what the host answers and what makes
    // the end of a range exclusive in the only way that works: nothing is in a range whose end is its start.
    _endLocation = endLocation ? endLocation : location;
    return self;
}

- (instancetype)initWithLocation:(id<NSTextLocation>)location
{
    return [self initWithLocation:location endLocation:nil];
}

- (instancetype)init
{
    // The header marks this one unavailable, and a range is two locations: there is no range without them. The
    // host faults on it (M9), which is not an answer a caller can survive or read, so this raises instead - a
    // catchable refusal that names the initialiser to use, and never a range with no locations in it.
    [NSException raise:NSInternalInconsistencyException
                format:@"%@ cannot be made without two locations: use -initWithLocation:endLocation:",
                       NSStringFromClass([self class])];
    return nil;
}

- (BOOL)isEmpty
{
    // By value and not by identity: a range is empty when its two locations are the same place, and two
    // location objects that stand for the same place are one place. The identity test says a range made of two
    // equal locations is not empty, and the grid of forty-nine pairs in facts/UIKit/NSTextRange15.md is what
    // found it (M1).
    return [_location isEqual:_endLocation];
}

- (BOOL)isEqualToTextRange:(NSTextRange *)textRange
{
    if (!textRange)
        return NO;
    return [_location isEqual:textRange.location] && [_endLocation isEqual:textRange.endLocation];
}

- (BOOL)containsLocation:(id<NSTextLocation>)location
{
    if (!location)
        return NO;
    // The header's own rule, which is what makes a range's end exclusive: (location <= l) && (l < endLocation).
    // An empty range has its end at its start, so nothing is in it, itself included.
    if ([location compare:_location] == NSOrderedAscending)
        return NO;
    return [location compare:_endLocation] == NSOrderedAscending;
}

- (BOOL)containsRange:(NSTextRange *)textRange
{
    if (!textRange || [self isEmpty])
        return NO;
    if ([textRange.location compare:_location] == NSOrderedAscending)
        return NO;
    // An empty range is in this one exactly when its one location is, which is the rule for a location: so
    // 0...10 holds 3...3 and 0...0 and does not hold 10...10, whose location is at its end (M1). A range with
    // contents is held whole, closed at both ends: 0...10 holds 0...10 and 0...5, and 0...15 holds 0...10.
    if ([textRange isEmpty])
        return [self containsLocation:textRange.location];
    return [textRange.endLocation compare:_endLocation] != NSOrderedDescending;
}

- (BOOL)intersectsWithTextRange:(NSTextRange *)textRange
{
    if (!textRange || [self isEmpty] || [textRange isEmpty])
        return NO;
    // Two ranges share contents exactly when each one starts before the other one ends, from the same grid
    // (M1). Ranges that touch at a boundary share nothing - 0...5 and 5...15 do not - and an empty range is in
    // no range, so it shares nothing with any.
    if ([textRange.location compare:_endLocation] != NSOrderedAscending)
        return NO;
    return [_location compare:textRange.endLocation] == NSOrderedAscending;
}

- (instancetype)textRangeByIntersectingWithTextRange:(NSTextRange *)textRange
{
    if (!textRange)
        return nil;
    // The overlap is the later of the two starts and the earlier of the two ends, and there is one whenever the
    // ranges share contents or one of them is inside the other - which is why the intersection of 0...10 and
    // 0...15 is 0...10 and of 0...10 and 5...5 is 5...5 (M1). Ranges that only touch share nothing and neither
    // is inside the other, so 0...5 with 5...10 has no intersection at all, and 0...10 with 20...25 has none.
    if (![self containsRange:textRange] && ![textRange containsRange:self] && ![self intersectsWithTextRange:textRange])
        return nil;
    id<NSTextLocation> start = [textRange.location compare:_location] == NSOrderedAscending ? _location : textRange.location;
    id<NSTextLocation> end = [textRange.endLocation compare:_endLocation] == NSOrderedAscending ? textRange.endLocation : _endLocation;
    return [[[self class] alloc] initWithLocation:start endLocation:end];
}

- (instancetype)textRangeByFormingUnionWithTextRange:(NSTextRange *)textRange
{
    if (!textRange)
        return self;
    // An empty range has nothing to add, so a union with one is the range that has contents: 0...0 with 5...10
    // is 5...10, and 3...3 with 0...10 is 0...10 (M1). Two of them have nothing between them either, and the
    // host answers the range it was handed rather than one spanning the gap: 0...0 with 3...3 is 3...3, and in
    // the other order it is 0...0.
    if ([self isEmpty])
        return textRange;
    if ([textRange isEmpty])
        return self;
    // Otherwise the envelope: the earlier of the two starts and the later of the two ends.
    id<NSTextLocation> start = [textRange.location compare:_location] == NSOrderedAscending ? textRange.location : _location;
    id<NSTextLocation> end = [_endLocation compare:textRange.endLocation] == NSOrderedAscending ? textRange.endLocation : _endLocation;
    return [[[self class] alloc] initWithLocation:start endLocation:end];
}

// The host's own text for a range, which is its two locations and nothing else: "0...10", and "3...3" for a
// range that is empty at 3. There is no class and no address, so a range printed in a log names the part of the
// document it is in and nothing else.
- (NSString *)description
{
    return [NSString stringWithFormat:@"%@...%@", _location, _endLocation];
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[NSTextRange class]])
        return NO;
    return [self isEqualToTextRange:object];
}

- (NSUInteger)hash
{
    // The two locations' own hashes, combined. The host's own hash is not a function of the range's value - two
    // equal ranges measured with different hashes, M2 - and a hash that disagrees with equality breaks every
    // dictionary and set the range goes into, so this one is by value and the divergence is recorded rather than
    // copied.
    return _location.hash ^ _endLocation.hash * 31;
}

@end
