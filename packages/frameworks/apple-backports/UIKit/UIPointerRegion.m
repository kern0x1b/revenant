#import "RevenantPointer.h"

@interface UIPointerRegionRequest (RevenantPointer)
- (instancetype)initRevenantWithLocation:(CGPoint)location modifiers:(UIKeyModifierFlags)modifiers;
@end

@interface UIPointerRegion (RevenantPointer)
- (instancetype)initRevenantWithRect:(CGRect)rect identifier:(id<NSObject>)identifier;
@end

@implementation UIPointerRegion {
@private
    CGRect _rect;
    id<NSObject> _identifier;
    UIAxis _latchingAxes;
}

+ (instancetype)regionWithRect:(CGRect)rect identifier:(id<NSObject>)identifier
{
    return [[self alloc] initRevenantWithRect:rect identifier:identifier];
}

- (instancetype)initRevenantWithRect:(CGRect)rect identifier:(id<NSObject>)identifier
{
    if ((self = [super init])) {
        _rect = rect;
        _identifier = identifier;
    }
    return self;
}

- (CGRect)rect
{
    return _rect;
}

- (id<NSObject>)identifier
{
    return _identifier;
}

- (UIAxis)latchingAxes
{
    return _latchingAxes;
}

- (void)setLatchingAxes:(UIAxis)latchingAxes
{
    _latchingAxes = latchingAxes;
}

- (id)copyWithZone:(NSZone *)zone
{
    UIPointerRegion *copy = [[[self class] allocWithZone:zone] initRevenantWithRect:_rect identifier:_identifier];
    copy->_latchingAxes = _latchingAxes;
    return copy;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[UIPointerRegion class]])
        return NO;
    UIPointerRegion *other = object;
    id<NSObject> identifier = other->_identifier;
    return CGRectEqualToRect(_rect, other->_rect) && (_identifier == identifier || [_identifier isEqual:identifier]) && _latchingAxes == other->_latchingAxes;
}

- (NSUInteger)hash
{
    return revenant_hash_part(_rect.origin.x) ^ revenant_hash_part(_rect.origin.y) ^ revenant_hash_part(_rect.size.width) ^ revenant_hash_part(_rect.size.height)
        ^ _identifier.hash ^ (NSUInteger)_latchingAxes;
}

- (NSString *)description
{
    NSMutableString *text = [NSMutableString stringWithFormat:@"<%@: %p; rect = (%g %g; %g %g)", [self class], self, (double)_rect.origin.x, (double)_rect.origin.y,
                                                              (double)_rect.size.width, (double)_rect.size.height];
    if (_identifier)
        [text appendFormat:@"; identifier = %@", _identifier];
    NSString *axes = revenant_axes_text(_latchingAxes);
    if (axes)
        [text appendFormat:@"; latchingAxes = (%@)", axes];
    [text appendString:@">"];
    return text;
}

@end

@implementation UIPointerRegionRequest {
@private
    CGPoint _location;
    UIKeyModifierFlags _modifiers;
}

- (instancetype)initRevenantWithLocation:(CGPoint)location modifiers:(UIKeyModifierFlags)modifiers
{
    if ((self = [super init])) {
        _location = location;
        _modifiers = modifiers;
    }
    return self;
}

- (CGPoint)location
{
    return _location;
}

- (UIKeyModifierFlags)modifiers
{
    return _modifiers;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; location = %@>", [self class], self, NSStringFromCGPoint(_location)];
}

@end
