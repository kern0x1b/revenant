#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-qualifiers"

@implementation NSTextRange

@synthesize location = _location;
@synthesize endLocation = _endLocation;

- (instancetype)initWithLocation:(id<NSTextLocation>)location endLocation:(id<NSTextLocation>)endLocation
{
    if ((self = [super init]))
        _location = location;
    _endLocation = endLocation ? endLocation : location;
    return self;
}

- (instancetype)initWithLocation:(id<NSTextLocation>)location
{
    return [self initWithLocation:location endLocation:nil];
}

- (instancetype)init
{
    [NSException raise:NSInternalInconsistencyException
                format:@"%@ cannot be made without two locations: use -initWithLocation:endLocation:",
                       NSStringFromClass([self class])];
    return nil;
}

- (BOOL)isEmpty
{
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
    if ([textRange isEmpty])
        return [self containsLocation:textRange.location];
    return [textRange.endLocation compare:_endLocation] != NSOrderedDescending;
}

- (BOOL)intersectsWithTextRange:(NSTextRange *)textRange
{
    if (!textRange || [self isEmpty] || [textRange isEmpty])
        return NO;
    if ([textRange.location compare:_endLocation] != NSOrderedAscending)
        return NO;
    return [_location compare:textRange.endLocation] == NSOrderedAscending;
}

- (instancetype)textRangeByIntersectingWithTextRange:(NSTextRange *)textRange
{
    if (!textRange)
        return nil;
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
    if ([self isEmpty])
        return textRange;
    if ([textRange isEmpty])
        return self;
    id<NSTextLocation> start = [textRange.location compare:_location] == NSOrderedAscending ? textRange.location : _location;
    id<NSTextLocation> end = [_endLocation compare:textRange.endLocation] == NSOrderedAscending ? textRange.endLocation : _endLocation;
    return [[[self class] alloc] initWithLocation:start endLocation:end];
}

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
    return _location.hash ^ _endLocation.hash * 31;
}

@end
