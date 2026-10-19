#import "CharonMenus.h"

@implementation UIPreviewTarget {
@private
    UIView *_container;
    CGPoint _center;
    CGAffineTransform _transform;
}

- (instancetype)initWithContainer:(UIView *)container center:(CGPoint)center transform:(CGAffineTransform)transform
{
    if (!container)
        [NSException raise:NSInternalInconsistencyException format:@"The preview target must have a valid container."];
    if (!charon_window_of(container))
        [NSException raise:NSInternalInconsistencyException format:@"UIPreviewTarget requires that the container view is in a window, but it is not. (container: %@)",
                                                                   charon_short_description(container)];
    if ((self = [super init])) {
        _container = container;
        _center = center;
        _transform = transform;
    }
    return self;
}

- (instancetype)initWithContainer:(UIView *)container center:(CGPoint)center
{
    return [self initWithContainer:container center:center transform:CGAffineTransformIdentity];
}

- (UIView *)container
{
    return _container;
}

- (CGPoint)center
{
    return _center;
}

- (CGAffineTransform)transform
{
    return _transform;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[UIPreviewTarget class]])
        return NO;
    UIPreviewTarget *other = object;
    return _container == other.container && CGPointEqualToPoint(_center, other.center) && CGAffineTransformEqualToTransform(_transform, other.transform);
}

- (NSUInteger)hash
{
    return [_container hash] ^ (NSUInteger)(_center.x * 31) ^ (NSUInteger)(_center.y * 17) ^ (NSUInteger)(_transform.a * 13) ^ (NSUInteger)(_transform.tx * 7);
}

- (NSString *)description
{
    NSMutableString *text = [NSMutableString stringWithFormat:@"<%@: %p; container = %@; center = (%g %g)", [self class], self,
                                                              charon_short_description(_container), (double)_center.x, (double)_center.y];
    if (!CGAffineTransformIsIdentity(_transform))
        [text appendFormat:@"; transform = %@", NSStringFromCGAffineTransform(_transform)];
    [text appendString:@">"];
    return text;
}

@end
