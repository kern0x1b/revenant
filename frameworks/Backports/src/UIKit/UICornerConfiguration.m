#import "RevenantUICorner.h"
#import "RevenantCornerPath.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

typedef NS_ENUM(NSInteger, RevenantCornerRadiusKind) {
    RevenantCornerRadiusFixed,
    RevenantCornerRadiusContainerConcentric,
};

@interface UICornerRadius () {
    @package
    RevenantCornerRadiusKind _kind;
    CGFloat _value;
}
- (instancetype)initWithKind:(RevenantCornerRadiusKind)kind value:(CGFloat)value;
@end

@implementation UICornerRadius

+ (instancetype)fixedRadius:(CGFloat)radius
{
    return [[self alloc] initWithKind:RevenantCornerRadiusFixed value:radius];
}

+ (instancetype)containerConcentricRadius
{
    return [self containerConcentricRadiusWithMinimum:0];
}

+ (instancetype)containerConcentricRadiusWithMinimum:(CGFloat)minimum
{
    return [[self alloc] initWithKind:RevenantCornerRadiusContainerConcentric value:minimum];
}

- (instancetype)initWithKind:(RevenantCornerRadiusKind)kind value:(CGFloat)value
{
    self = [super init];
    if (self) {
        _kind = kind;
        _value = value;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (BOOL)isEqual:(id)other
{
    if (other == self)
        return YES;
    return [other isKindOfClass:[UICornerRadius class]] && ((UICornerRadius *)other)->_kind == _kind &&
           ((UICornerRadius *)other)->_value == _value;
}

- (NSUInteger)hash
{
    return (NSUInteger)_kind * 31u + [@(_value) hash];
}

- (NSString *)description
{
    return _kind == RevenantCornerRadiusFixed ? [NSString stringWithFormat:@"fixed(%g)", _value]
                                              : [NSString stringWithFormat:@"containerConcentric(minimum: %g)", _value];
}

@end

enum { RevenantTopLeft, RevenantTopRight, RevenantBottomLeft, RevenantBottomRight, RevenantCornerCount };

@interface UICornerConfiguration () {
    @package
    UICornerRadius *_radius[RevenantCornerCount];
    NSUInteger _group[RevenantCornerCount];
    BOOL _capsule;
    CGFloat _maximumRadius;
}
- (instancetype)initRevenant;
+ (instancetype)revenant_configurationWithRadii:(UICornerRadius *const *)radii groups:(const NSUInteger *)groups;
@end

@implementation UICornerConfiguration

+ (instancetype)revenant_configurationWithRadii:(UICornerRadius *const *)radii groups:(const NSUInteger *)groups
{
    UICornerConfiguration *configuration = [[self alloc] initRevenant];
    for (int corner = 0; corner < RevenantCornerCount; corner++) {
        configuration->_radius[corner] = radii[corner];
        configuration->_group[corner] = groups[corner];
    }
    return configuration;
}

- (instancetype)initRevenant
{
    return [super init];
}

+ (instancetype)configurationWithRadius:(UICornerRadius *)radius
{
    UICornerRadius *radii[RevenantCornerCount] = {radius, radius, radius, radius};
    const NSUInteger groups[RevenantCornerCount] = {0, 1, 2, 3};
    return [self revenant_configurationWithRadii:radii groups:groups];
}

+ (instancetype)configurationWithTopLeftRadius:(UICornerRadius *)topLeftRadius
                                topRightRadius:(UICornerRadius *)topRightRadius
                              bottomLeftRadius:(UICornerRadius *)bottomLeftRadius
                             bottomRightRadius:(UICornerRadius *)bottomRightRadius
{
    UICornerRadius *radii[RevenantCornerCount] = {topLeftRadius, topRightRadius, bottomLeftRadius, bottomRightRadius};
    const NSUInteger groups[RevenantCornerCount] = {0, 1, 2, 3};
    return [self revenant_configurationWithRadii:radii groups:groups];
}

+ (instancetype)capsuleConfiguration
{
    return [self capsuleConfigurationWithMaximumRadius:CGFLOAT_MAX];
}

+ (instancetype)capsuleConfigurationWithMaximumRadius:(CGFloat)maximumRadius
{
    UICornerConfiguration *configuration = [[self alloc] initRevenant];
    configuration->_capsule = YES;
    configuration->_maximumRadius = maximumRadius;
    return configuration;
}

+ (instancetype)configurationWithUniformRadius:(UICornerRadius *)radius
{
    UICornerRadius *radii[RevenantCornerCount] = {radius, radius, radius, radius};
    const NSUInteger groups[RevenantCornerCount] = {0, 0, 0, 0};
    return [self revenant_configurationWithRadii:radii groups:groups];
}

+ (instancetype)configurationWithUniformTopRadius:(UICornerRadius *)topRadius uniformBottomRadius:(UICornerRadius *)bottomRadius
{
    UICornerRadius *radii[RevenantCornerCount] = {topRadius, topRadius, bottomRadius, bottomRadius};
    const NSUInteger groups[RevenantCornerCount] = {0, 0, 1, 1};
    return [self revenant_configurationWithRadii:radii groups:groups];
}

+ (instancetype)configurationWithUniformLeftRadius:(UICornerRadius *)leftRadius uniformRightRadius:(UICornerRadius *)rightRadius
{
    UICornerRadius *radii[RevenantCornerCount] = {leftRadius, rightRadius, leftRadius, rightRadius};
    const NSUInteger groups[RevenantCornerCount] = {0, 1, 0, 1};
    return [self revenant_configurationWithRadii:radii groups:groups];
}

+ (instancetype)configurationWithUniformTopRadius:(UICornerRadius *)topRadius
                                 bottomLeftRadius:(UICornerRadius *)bottomLeftRadius
                                bottomRightRadius:(UICornerRadius *)bottomRightRadius
{
    UICornerRadius *radii[RevenantCornerCount] = {topRadius, topRadius, bottomLeftRadius, bottomRightRadius};
    const NSUInteger groups[RevenantCornerCount] = {0, 0, 2, 3};
    return [self revenant_configurationWithRadii:radii groups:groups];
}

+ (instancetype)configurationWithUniformBottomRadius:(UICornerRadius *)bottomRadius
                                       topLeftRadius:(UICornerRadius *)topLeftRadius
                                      topRightRadius:(UICornerRadius *)topRightRadius
{
    UICornerRadius *radii[RevenantCornerCount] = {topLeftRadius, topRightRadius, bottomRadius, bottomRadius};
    const NSUInteger groups[RevenantCornerCount] = {0, 1, 2, 2};
    return [self revenant_configurationWithRadii:radii groups:groups];
}

+ (instancetype)configurationWithUniformLeftRadius:(UICornerRadius *)leftRadius
                                    topRightRadius:(UICornerRadius *)topRightRadius
                                 bottomRightRadius:(UICornerRadius *)bottomRightRadius
{
    UICornerRadius *radii[RevenantCornerCount] = {leftRadius, topRightRadius, leftRadius, bottomRightRadius};
    const NSUInteger groups[RevenantCornerCount] = {0, 1, 0, 3};
    return [self revenant_configurationWithRadii:radii groups:groups];
}

+ (instancetype)configurationWithUniformRightRadius:(UICornerRadius *)rightRadius
                                      topLeftRadius:(UICornerRadius *)topLeftRadius
                                   bottomLeftRadius:(UICornerRadius *)bottomLeftRadius
{
    UICornerRadius *radii[RevenantCornerCount] = {topLeftRadius, rightRadius, bottomLeftRadius, rightRadius};
    const NSUInteger groups[RevenantCornerCount] = {0, 1, 2, 1};
    return [self revenant_configurationWithRadii:radii groups:groups];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (BOOL)isEqual:(id)other
{
    if (other == self)
        return YES;
    if (![other isKindOfClass:[UICornerConfiguration class]])
        return NO;
    UICornerConfiguration *that = other;
    if (that->_capsule != _capsule)
        return NO;
    if (_capsule)
        return that->_maximumRadius == _maximumRadius;
    for (int corner = 0; corner < RevenantCornerCount; corner++) {
        if (that->_group[corner] != _group[corner] || (that->_radius[corner] != _radius[corner] && ![that->_radius[corner] isEqual:_radius[corner]]))
            return NO;
    }
    return YES;
}

- (NSUInteger)hash
{
    if (_capsule)
        return [@(_maximumRadius) hash];
    NSUInteger hash = 17;
    for (int corner = 0; corner < RevenantCornerCount; corner++)
        hash = hash * 31u + [_radius[corner] hash] + _group[corner];
    return hash;
}

- (NSString *)description
{
    if (_capsule)
        return _maximumRadius == CGFLOAT_MAX ? @"capsule()" : [NSString stringWithFormat:@"capsule(maximumRadius: %g)", _maximumRadius];
    return [NSString stringWithFormat:@"corners(topLeft: %@, topRight: %@, bottomLeft: %@, bottomRight: %@)",
            _radius[RevenantTopLeft], _radius[RevenantTopRight], _radius[RevenantBottomLeft], _radius[RevenantBottomRight]];
}

@end

@implementation UIView (RevenantCornerConfiguration)

static char RevenantViewCornerConfigurationKey;
static char RevenantViewCornerMaskKey;

static RevenantCornerRadii revenant_effective_radii(UIView *view, UICornerConfiguration *configuration);

static CGFloat revenant_corner_radius_of(RevenantCornerRadii radii, int corner)
{
    switch (corner) {
    case RevenantTopLeft: return radii.topLeft;
    case RevenantTopRight: return radii.topRight;
    case RevenantBottomLeft: return radii.bottomLeft;
    default: return radii.bottomRight;
    }
}

static CGFloat revenant_container_radius(UIView *container, int corner)
{
    UICornerConfiguration *configuration = objc_getAssociatedObject(container, &RevenantViewCornerConfigurationKey);
    if (configuration)
        return revenant_corner_radius_of(revenant_effective_radii(container, configuration), corner);
    CALayer *layer = container.layer;
    static const CACornerMask masks[RevenantCornerCount] = {kCALayerMinXMinYCorner, kCALayerMaxXMinYCorner,
                                                            kCALayerMinXMaxYCorner, kCALayerMaxXMaxYCorner};
    if (layer.cornerRadius <= 0 || !(layer.maskedCorners & masks[corner]))
        return 0;
    return MIN(layer.cornerRadius, MIN(layer.bounds.size.width, layer.bounds.size.height) / 2);
}

static CGFloat revenant_radius_value(UIView *view, UICornerRadius *radius, int corner)
{
    if (radius == nil)
        return 0;
    if (radius->_kind == RevenantCornerRadiusFixed)
        return radius->_value;
    BOOL left = corner == RevenantTopLeft || corner == RevenantBottomLeft;
    BOOL top = corner == RevenantTopLeft || corner == RevenantTopRight;
    CGRect bounds = view.bounds;
    CGPoint point = CGPointMake(left ? CGRectGetMinX(bounds) : CGRectGetMaxX(bounds), top ? CGRectGetMinY(bounds) : CGRectGetMaxY(bounds));
    for (UIView *container = view.superview; container != nil; container = container.superview) {
        CGFloat outer = revenant_container_radius(container, corner);
        if (outer <= 0)
            continue;
        CGPoint at = [container convertPoint:point fromView:view];
        CGRect edges = container.bounds;
        CGFloat across = left ? at.x - CGRectGetMinX(edges) : CGRectGetMaxX(edges) - at.x;
        CGFloat down = top ? at.y - CGRectGetMinY(edges) : CGRectGetMaxY(edges) - at.y;
        return MAX(outer - MAX(MAX(across, down), 0), radius->_value);
    }
    return radius->_value;
}

static RevenantCornerRadii revenant_effective_radii(UIView *view, UICornerConfiguration *configuration)
{
    CGSize size = view.bounds.size;
    CGFloat raw[RevenantCornerCount];
    for (int corner = 0; corner < RevenantCornerCount; corner++) {
        raw[corner] = configuration->_capsule ? MIN(MIN(size.width, size.height) / 2, configuration->_maximumRadius)
                                              : revenant_radius_value(view, configuration->_radius[corner], corner);
    }
    CGFloat grouped[RevenantCornerCount];
    for (int corner = 0; corner < RevenantCornerCount; corner++) {
        grouped[corner] = raw[corner];
        for (int other = 0; other < RevenantCornerCount; other++) {
            if (configuration->_group[other] == configuration->_group[corner])
                grouped[corner] = MAX(grouped[corner], raw[other]);
        }
    }
    return RevenantCornerRadiiFitted(size, (RevenantCornerRadii){grouped[RevenantTopLeft], grouped[RevenantTopRight],
                                                                 grouped[RevenantBottomLeft], grouped[RevenantBottomRight]});
}

static void revenant_apply_corner_configuration(UIView *view)
{
    UICornerConfiguration *configuration = objc_getAssociatedObject(view, &RevenantViewCornerConfigurationKey);
    if (configuration == nil)
        return;
    RevenantCornerRadii radii = revenant_effective_radii(view, configuration);
    CALayer *layer = view.layer;
    CAShapeLayer *ours = objc_getAssociatedObject(view, &RevenantViewCornerMaskKey);
    if (radii.topLeft == radii.topRight && radii.topLeft == radii.bottomLeft && radii.topLeft == radii.bottomRight) {
        if (ours && layer.mask == ours)
            layer.mask = nil;
        layer.cornerRadius = radii.topLeft;
        return;
    }
    if (layer.mask != nil && layer.mask != ours)
        return;
    if (ours == nil) {
        ours = [CAShapeLayer layer];
        ours.fillColor = [UIColor blackColor].CGColor;
        objc_setAssociatedObject(view, &RevenantViewCornerMaskKey, ours, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    CGPathRef path = RevenantCornerPathCreate(CGRectMake(0, 0, layer.bounds.size.width, layer.bounds.size.height), radii);
    layer.cornerRadius = 0;
    ours.frame = layer.bounds;
    ours.path = path;
    CGPathRelease(path);
    if (layer.mask != ours)
        layer.mask = ours;
}

static void revenant_install_corner_configuration_hook(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Method method = class_getInstanceMethod([CALayer class], @selector(setBounds:));
        IMP original = method_getImplementation(method);
        method_setImplementation(method, imp_implementationWithBlock(^(CALayer *layer, CGRect bounds) {
            ((void (*)(CALayer *, SEL, CGRect))original)(layer, @selector(setBounds:), bounds);
            if ([layer.delegate isKindOfClass:[UIView class]])
                revenant_apply_corner_configuration((UIView *)layer.delegate);
        }));
    });
}

- (UICornerConfiguration *)cornerConfiguration
{
    UICornerConfiguration *configuration = objc_getAssociatedObject(self, &RevenantViewCornerConfigurationKey);
    return configuration ?: [UICornerConfiguration configurationWithRadius:[UICornerRadius fixedRadius:0]];
}

- (CGFloat)effectiveRadiusForCorner:(UIRectCorner)corner
{
    RevenantCornerRadii radii = revenant_effective_radii(self, self.cornerConfiguration);
    CGFloat radius = 0;
    if (corner & UIRectCornerTopLeft)
        radius = MAX(radius, radii.topLeft);
    if (corner & UIRectCornerTopRight)
        radius = MAX(radius, radii.topRight);
    if (corner & UIRectCornerBottomLeft)
        radius = MAX(radius, radii.bottomLeft);
    if (corner & UIRectCornerBottomRight)
        radius = MAX(radius, radii.bottomRight);
    return radius;
}

- (void)setCornerConfiguration:(UICornerConfiguration *)configuration
{
    revenant_install_corner_configuration_hook();
    objc_setAssociatedObject(self, &RevenantViewCornerConfigurationKey, [configuration copy],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    revenant_apply_corner_configuration(self);
}
@end
