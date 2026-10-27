#import "RevenantPointer.h"
#import <objc/message.h>

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Woverriding-method-mismatch"
#pragma clang diagnostic ignored "-Wmethod-signatures"

static const NSUInteger RevenantShapeDefaultRadius = 8;

@interface UIPointerShape (RevenantPointer)
- (instancetype)initRevenant;
@end

@implementation UIPointerShape {
@private
    NSInteger _type;
    CGRect _rect;
    CGFloat _cornerRadius;
    BOOL _radiusSet;
    UIBezierPath *_path;
    CGFloat _beamLength;
    BOOL _beamHorizontal;
}

+ (instancetype)shapeWithPath:(UIBezierPath *)path
{
    UIPointerShape *shape = [[self alloc] initRevenant];
    shape->_type = 1;
    shape->_path = [path copy];
    return shape;
}

+ (instancetype)shapeWithRoundedRect:(CGRect)rect
{
    UIPointerShape *shape = [[self alloc] initRevenant];
    shape->_rect = rect;
    return shape;
}

+ (instancetype)shapeWithRoundedRect:(CGRect)rect cornerRadius:(CGFloat)cornerRadius
{
    UIPointerShape *shape = [self shapeWithRoundedRect:rect];
    if (cornerRadius != CGFLOAT_MIN) {
        shape->_cornerRadius = cornerRadius;
        shape->_radiusSet = YES;
    }
    return shape;
}

+ (instancetype)beamWithPreferredLength:(CGFloat)length axis:(UIAxis)axis
{
    UIPointerShape *shape = [[self alloc] initRevenant];
    shape->_type = 2;
    shape->_beamLength = length;
    shape->_beamHorizontal = axis == UIAxisHorizontal;
    return shape;
}

- (instancetype)initRevenant
{
    return [super init];
}

- (instancetype)init
{
    if ((self = [super init]))
        _radiusSet = YES;
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    UIPointerShape *copy = [[[self class] allocWithZone:zone] initRevenant];
    copy->_type = _type;
    copy->_rect = _rect;
    copy->_cornerRadius = _cornerRadius;
    copy->_radiusSet = _radiusSet;
    copy->_path = [_path copy];
    copy->_beamLength = _beamLength;
    copy->_beamHorizontal = _beamHorizontal;
    return copy;
}

- (UIBezierPath *)revenant_path
{
    return _path;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[UIPointerShape class]])
        return NO;
    UIPointerShape *other = object;
    if (_type != other->_type)
        return NO;
    switch (_type) {
    case 1:
        if (_path == other->_path)
            return YES;
        return _path && other->_path && CGPathEqualToPath(_path.CGPath, other->_path.CGPath);
    case 2:
        return _beamLength == other->_beamLength && _beamHorizontal == other->_beamHorizontal;
    }
    return CGRectEqualToRect(_rect, other->_rect) && _radiusSet == other->_radiusSet && _cornerRadius == other->_cornerRadius;
}

- (NSUInteger)hash
{
    CGRect rect = _type == 1 ? (_path ? CGPathGetBoundingBox(_path.CGPath) : CGRectZero) : _rect;
    if (_type == 2)
        return revenant_hash_part(_beamLength) ^ (_beamHorizontal ? 17 : 16);
    return revenant_hash_part(rect.origin.x) ^ revenant_hash_part(rect.origin.y) ^ revenant_hash_part(rect.size.width) ^ revenant_hash_part(rect.size.height)
        ^ (_type == 0 && _radiusSet ? revenant_hash_part(_cornerRadius) : 0) ^ RevenantShapeDefaultRadius ^ (NSUInteger)_type;
}

- (NSString *)description
{
    NSMutableString *text = [NSMutableString stringWithFormat:@"<%@: %p", [self class], self];
    if (_type == 1) {
        [text appendFormat:@"; path = <UIBezierPath: %p>", _path];
    } else if (_type == 2) {
        [text appendFormat:@"; beamLength = %g (%@)", (double)_beamLength, _beamHorizontal ? @"horizontal" : @"vertical"];
    } else {
        [text appendFormat:@"; rect = (%g %g; %g %g)", (double)_rect.origin.x, (double)_rect.origin.y, (double)_rect.size.width, (double)_rect.size.height];
        if (_radiusSet && _cornerRadius != 0)
            [text appendFormat:@"; cornerRadius = %g", (double)_cornerRadius];
    }
    [text appendString:@">"];
    return text;
}

@end

@interface UIPointerEffect (RevenantPointer)
- (instancetype)initRevenantWithPreview:(UITargetedPreview *)preview;
@end

@implementation UIPointerEffect {
@private
    UITargetedPreview *_preview;
}

+ (instancetype)effectWithPreview:(UITargetedPreview *)preview
{
    return [[self alloc] initRevenantWithPreview:preview];
}

+ (instancetype)automaticEffectWithPreview:(UITargetedPreview *)preview
{
    return [UIPointerEffect effectWithPreview:preview];
}

+ (instancetype)highlightEffectWithPreview:(UITargetedPreview *)preview
{
    return [[UIPointerHighlightEffect alloc] initRevenantWithPreview:preview];
}

+ (instancetype)liftEffectWithPreview:(UITargetedPreview *)preview
{
    return [[UIPointerLiftEffect alloc] initRevenantWithPreview:preview];
}

+ (instancetype)hoverEffectWithPreview:(UITargetedPreview *)preview preferredTintMode:(UIPointerEffectTintMode)mode prefersShadow:(BOOL)shadow prefersScaledContent:(BOOL)scaled
{
    UIPointerHoverEffect *effect = [[UIPointerHoverEffect alloc] initRevenantWithPreview:preview];
    effect.preferredTintMode = mode;
    effect.prefersShadow = shadow;
    effect.prefersScaledContent = scaled;
    return effect;
}

- (instancetype)initRevenantWithPreview:(UITargetedPreview *)preview
{
    if ((self = [super init]))
        _preview = preview;
    return self;
}

- (UITargetedPreview *)preview
{
    return _preview;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initRevenantWithPreview:_preview];
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[self class]])
        return NO;
    UITargetedPreview *other = [(UIPointerEffect *)object preview];
    return _preview == other || [_preview isEqual:other];
}

- (NSUInteger)hash
{
    return _preview.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p>", [self class], self];
}

@end

@implementation UIPointerHighlightEffect
@end

@implementation UIPointerLiftEffect
@end

@implementation UIPointerHoverEffect {
@private
    UIPointerEffectTintMode _preferredTintMode;
    BOOL _prefersShadow;
    BOOL _prefersScaledContent;
}

- (instancetype)initRevenantWithPreview:(UITargetedPreview *)preview
{
    if ((self = [super initRevenantWithPreview:preview])) {
        _preferredTintMode = UIPointerEffectTintModeOverlay;
        _prefersScaledContent = YES;
    }
    return self;
}

- (UIPointerEffectTintMode)preferredTintMode
{
    return _preferredTintMode;
}

- (void)setPreferredTintMode:(UIPointerEffectTintMode)preferredTintMode
{
    _preferredTintMode = preferredTintMode;
}

- (BOOL)prefersShadow
{
    return _prefersShadow;
}

- (void)setPrefersShadow:(BOOL)prefersShadow
{
    _prefersShadow = prefersShadow;
}

- (BOOL)prefersScaledContent
{
    return _prefersScaledContent;
}

- (void)setPrefersScaledContent:(BOOL)prefersScaledContent
{
    _prefersScaledContent = prefersScaledContent;
}

- (id)copyWithZone:(NSZone *)zone
{
    UIPointerHoverEffect *copy = [super copyWithZone:zone];
    copy->_preferredTintMode = _preferredTintMode;
    copy->_prefersShadow = _prefersShadow;
    copy->_prefersScaledContent = _prefersScaledContent;
    return copy;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![super isEqual:object])
        return NO;
    UIPointerHoverEffect *other = object;
    return _preferredTintMode == other->_preferredTintMode && _prefersShadow == other->_prefersShadow && _prefersScaledContent == other->_prefersScaledContent;
}

- (NSUInteger)hash
{
    return [super hash] ^ (NSUInteger)_preferredTintMode ^ (_prefersShadow ? 1 : 0) ^ (_prefersScaledContent ? 1 : 0);
}

@end

@interface UIPointerStyle (RevenantPointer)
- (instancetype)initRevenantWithType:(NSInteger)type effect:(UIPointerEffect *)effect shape:(UIPointerShape *)shape axes:(UIAxis)axes;
@end

@implementation UIPointerStyle {
@private
    NSInteger _type;
    UIPointerEffect *_effect;
    UIPointerShape *_shape;
    UIAxis _axes;
    NSArray<UIPointerAccessory *> *_accessories;
}

+ (instancetype)styleWithEffect:(UIPointerEffect *)effect shape:(UIPointerShape *)shape
{
    return [[self alloc] initRevenantWithType:1 effect:effect shape:shape axes:(UIAxis)0];
}

+ (instancetype)styleWithShape:(UIPointerShape *)shape constrainedAxes:(UIAxis)axes
{
    return [[self alloc] initRevenantWithType:2 effect:nil shape:shape axes:axes];
}

+ (instancetype)hiddenPointerStyle
{
    return [[self alloc] initRevenantWithType:0 effect:nil shape:nil axes:(UIAxis)0];
}

+ (instancetype)systemPointerStyle
{
    return [[self alloc] initRevenantWithType:3 effect:nil shape:nil axes:(UIAxis)0];
}

- (instancetype)initRevenantWithType:(NSInteger)type effect:(UIPointerEffect *)effect shape:(UIPointerShape *)shape axes:(UIAxis)axes
{
    struct objc_super parent = {self, class_getSuperclass([UIPointerStyle class])};
    if ((self = ((id (*)(struct objc_super *, SEL))objc_msgSendSuper)(&parent, @selector(init)))) {
        _type = type;
        _effect = effect;
        _shape = shape;
        _axes = axes;
    }
    return self;
}

- (UIPointerEffect *)revenant_effect
{
    return _effect;
}

- (UIPointerShape *)revenant_shape
{
    return _shape;
}

- (UIAxis)revenant_axes
{
    return _axes;
}

- (NSArray<UIPointerAccessory *> *)accessories
{
    return _accessories;
}

- (void)setAccessories:(NSArray<UIPointerAccessory *> *)accessories
{
    _accessories = [accessories copy];
}

- (id)copyWithZone:(NSZone *)zone
{
    UIPointerStyle *copy = [[[self class] allocWithZone:zone] initRevenantWithType:_type effect:[_effect copy] shape:[_shape copy] axes:_axes];
    copy->_accessories = [_accessories copy];
    return copy;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[UIPointerStyle class]])
        return NO;
    UIPointerStyle *other = object;
    return _type == other->_type && _axes == other->_axes && (_effect == other->_effect || [_effect isEqual:other->_effect])
        && (_shape == other->_shape || [_shape isEqual:other->_shape]);
}

- (NSUInteger)hash
{
    return (NSUInteger)_type ^ (NSUInteger)_axes ^ _effect.hash ^ _shape.hash;
}

- (NSString *)description
{
    NSString *type = _type == 0 ? @"hidden" : _type == 1 ? @"content effect" : _type == 3 ? @"system" : @"shape";
    return [NSString stringWithFormat:@"<%@: %p; type = %@>", [self class], self, type];
}

@end
