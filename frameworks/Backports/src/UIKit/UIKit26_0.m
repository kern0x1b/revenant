#import "RevenantUIKit26.h"
#import "RevenantCornerPath.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

static inline id RevenantBox(id value) { return value; }

@implementation UIGlassEffect
@end

@implementation UIGlassContainerEffect
@end

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

@implementation UIScrollEdgeEffect
@end

@implementation UIScrollEdgeEffectStyle
@end

@implementation UIScrollEdgeElementContainerInteraction
@end

@implementation UITabAccessory
@end

@implementation UIBarButtonItemBadge
@end

@implementation UIContextMenuSystem
@end

@implementation UIMainMenuSystem
@end

@implementation UIMainMenuSystemConfiguration
@end

@implementation UIMenuSystemFindElementGroupConfiguration
@end

@implementation UIDeferredMenuElementProvider
@end

@implementation UISceneDestructionCondition
@end

@implementation UISceneWindowingControlStyle
@end

@implementation UIBackgroundExtensionView
@end

@implementation UIViewLayoutRegion
@end

@implementation UISymbolContentTransition
@end

@implementation UIScrollView (RevenantUIKit26)

static char RevenantTopEdgeEffectKey, RevenantLeftEdgeEffectKey;
static char RevenantRightEdgeEffectKey, RevenantBottomEdgeEffectKey;

- (UIScrollEdgeEffect *)topEdgeEffect { return objc_getAssociatedObject(self, &RevenantTopEdgeEffectKey); }
- (void)setTopEdgeEffect:(UIScrollEdgeEffect *)effect
{
    objc_setAssociatedObject(self, &RevenantTopEdgeEffectKey, effect, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (UIScrollEdgeEffect *)leftEdgeEffect { return objc_getAssociatedObject(self, &RevenantLeftEdgeEffectKey); }
- (void)setLeftEdgeEffect:(UIScrollEdgeEffect *)effect
{
    objc_setAssociatedObject(self, &RevenantLeftEdgeEffectKey, effect, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (UIScrollEdgeEffect *)rightEdgeEffect { return objc_getAssociatedObject(self, &RevenantRightEdgeEffectKey); }
- (void)setRightEdgeEffect:(UIScrollEdgeEffect *)effect
{
    objc_setAssociatedObject(self, &RevenantRightEdgeEffectKey, effect, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (UIScrollEdgeEffect *)bottomEdgeEffect { return objc_getAssociatedObject(self, &RevenantBottomEdgeEffectKey); }
- (void)setBottomEdgeEffect:(UIScrollEdgeEffect *)effect
{
    objc_setAssociatedObject(self, &RevenantBottomEdgeEffectKey, effect, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end

@implementation UISlider (RevenantUIKit26)

static char RevenantSliderStyleKey;

- (NSInteger)sliderStyle
{
    return [(NSNumber *)objc_getAssociatedObject(self, &RevenantSliderStyleKey) integerValue];
}
- (void)setSliderStyle:(NSInteger)style
{
    objc_setAssociatedObject(self, &RevenantSliderStyleKey, [NSNumber numberWithInteger:style],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end

@implementation UIBarButtonItem (RevenantUIKit26)

static char RevenantBarItemBadgeKey, RevenantBarItemIdentifierKey;
static char RevenantBarItemSharesBackgroundKey, RevenantBarItemHidesSharedBackgroundKey;

- (UIBarButtonItemBadge *)badge { return objc_getAssociatedObject(self, &RevenantBarItemBadgeKey); }
- (void)setBadge:(UIBarButtonItemBadge *)badge
{
    objc_setAssociatedObject(self, &RevenantBarItemBadgeKey, badge, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (NSString *)identifier { return objc_getAssociatedObject(self, &RevenantBarItemIdentifierKey); }
- (void)setIdentifier:(NSString *)identifier
{
    objc_setAssociatedObject(self, &RevenantBarItemIdentifierKey, [identifier copy],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (BOOL)sharesBackground
{
    return [(NSNumber *)objc_getAssociatedObject(self, &RevenantBarItemSharesBackgroundKey) boolValue];
}
- (void)setSharesBackground:(BOOL)shares
{
    objc_setAssociatedObject(self, &RevenantBarItemSharesBackgroundKey, [NSNumber numberWithBool:shares],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (BOOL)hidesSharedBackground
{
    return [(NSNumber *)objc_getAssociatedObject(self, &RevenantBarItemHidesSharedBackgroundKey) boolValue];
}
- (void)setHidesSharedBackground:(BOOL)hides
{
    objc_setAssociatedObject(self, &RevenantBarItemHidesSharedBackgroundKey, [NSNumber numberWithBool:hides],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end

@implementation UIDeferredMenuElement (RevenantUIKit26)

static char RevenantDeferredElementIdentifierKey;

+ (UIDeferredMenuElement *)elementUsingFocusWithIdentifier:(NSString *)identifier
                                            shouldCacheItems:(BOOL)shouldCache
{
    return [self elementWithProvider:^(void (^completion)(NSArray<UIMenuElement *> *)) {
        if (completion != NULL)
            completion(@[]);
    }];
}

- (NSString *)identifier { return objc_getAssociatedObject(self, &RevenantDeferredElementIdentifierKey); }
@end

@implementation UIScene (RevenantUIKit26)

static char RevenantSceneDestructionConditionsKey;

- (NSSet<UISceneDestructionCondition *> *)destructionConditions
{
    return objc_getAssociatedObject(self, &RevenantSceneDestructionConditionsKey);
}
- (void)setDestructionConditions:(NSSet<UISceneDestructionCondition *> *)conditions
{
    objc_setAssociatedObject(self, &RevenantSceneDestructionConditionsKey, [conditions copy],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end

@implementation UISplitViewController (RevenantUIKit26)

static char RevenantMaxInspectorKey, RevenantMinInspectorKey, RevenantMinSecondaryKey;
static char RevenantPrefInspectorKey, RevenantPrefInspectorFractionKey;
static char RevenantPrefSecondaryKey, RevenantPrefSecondaryFractionKey;

- (CGFloat)maximumInspectorColumnWidth
{
    return [(NSNumber *)objc_getAssociatedObject(self, &RevenantMaxInspectorKey) doubleValue];
}
- (void)setMaximumInspectorColumnWidth:(CGFloat)width
{
    objc_setAssociatedObject(self, &RevenantMaxInspectorKey, [NSNumber numberWithDouble:(double)width],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (CGFloat)minimumInspectorColumnWidth
{
    return [(NSNumber *)objc_getAssociatedObject(self, &RevenantMinInspectorKey) doubleValue];
}
- (void)setMinimumInspectorColumnWidth:(CGFloat)width
{
    objc_setAssociatedObject(self, &RevenantMinInspectorKey, [NSNumber numberWithDouble:(double)width],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (CGFloat)minimumSecondaryColumnWidth
{
    return [(NSNumber *)objc_getAssociatedObject(self, &RevenantMinSecondaryKey) doubleValue];
}
- (void)setMinimumSecondaryColumnWidth:(CGFloat)width
{
    objc_setAssociatedObject(self, &RevenantMinSecondaryKey, [NSNumber numberWithDouble:(double)width],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (CGFloat)preferredInspectorColumnWidth
{
    return [(NSNumber *)objc_getAssociatedObject(self, &RevenantPrefInspectorKey) doubleValue];
}
- (void)setPreferredInspectorColumnWidth:(CGFloat)width
{
    objc_setAssociatedObject(self, &RevenantPrefInspectorKey, [NSNumber numberWithDouble:(double)width],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (CGFloat)preferredInspectorColumnWidthFraction
{
    return [(NSNumber *)objc_getAssociatedObject(self, &RevenantPrefInspectorFractionKey) doubleValue];
}
- (void)setPreferredInspectorColumnWidthFraction:(CGFloat)fraction
{
    objc_setAssociatedObject(self, &RevenantPrefInspectorFractionKey,
                             [NSNumber numberWithDouble:(double)fraction], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (CGFloat)preferredSecondaryColumnWidth
{
    return [(NSNumber *)objc_getAssociatedObject(self, &RevenantPrefSecondaryKey) doubleValue];
}
- (void)setPreferredSecondaryColumnWidth:(CGFloat)width
{
    objc_setAssociatedObject(self, &RevenantPrefSecondaryKey, [NSNumber numberWithDouble:(double)width],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (CGFloat)preferredSecondaryColumnWidthFraction
{
    return [(NSNumber *)objc_getAssociatedObject(self, &RevenantPrefSecondaryFractionKey) doubleValue];
}
- (void)setPreferredSecondaryColumnWidthFraction:(CGFloat)fraction
{
    objc_setAssociatedObject(self, &RevenantPrefSecondaryFractionKey,
                             [NSNumber numberWithDouble:(double)fraction], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isShowingColumn:(id)column { return NO; }
@end

@implementation UITabBarController (RevenantUIKit26)

static char RevenantTabBarBottomAccessoryKey, RevenantTabBarMinimizeBehaviorKey;
static char RevenantTabBarContentLayoutGuideKey;

- (UITabAccessory *)bottomAccessory
{
    return objc_getAssociatedObject(self, &RevenantTabBarBottomAccessoryKey);
}
- (void)setBottomAccessory:(UITabAccessory *)accessory
{
    objc_setAssociatedObject(self, &RevenantTabBarBottomAccessoryKey, accessory,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (void)setBottomAccessory:(UITabAccessory *)accessory animated:(BOOL)animated
{
    self.bottomAccessory = accessory;
}
- (NSInteger)tabBarMinimizeBehavior
{
    return [(NSNumber *)objc_getAssociatedObject(self, &RevenantTabBarMinimizeBehaviorKey) integerValue];
}
- (void)setTabBarMinimizeBehavior:(NSInteger)behavior
{
    objc_setAssociatedObject(self, &RevenantTabBarMinimizeBehaviorKey, [NSNumber numberWithInteger:behavior],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (id)contentLayoutGuide
{
    return objc_getAssociatedObject(self, &RevenantTabBarContentLayoutGuideKey);
}
- (void)setContentLayoutGuide:(id)guide
{
    objc_setAssociatedObject(self, &RevenantTabBarContentLayoutGuideKey, guide,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end

@implementation UITextView (RevenantUIKit26)

static char RevenantTextViewSelectedRangesKey;

- (NSArray<NSValue *> *)selectedRanges
{
    return objc_getAssociatedObject(self, &RevenantTextViewSelectedRangesKey);
}
- (void)setSelectedRanges:(NSArray<NSValue *> *)ranges
{
    objc_setAssociatedObject(self, &RevenantTextViewSelectedRangesKey,
                             ranges.count ? [ranges copy] : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end

@implementation NSTextList (RevenantUIKit26)

+ (BOOL)includesTextListMarkers
{
    return NO;
}

@end

@implementation UIColor (RevenantUIKit26)

static char RevenantColorLinearExposureKey;

- (CGFloat)linearExposure
{
    return [(NSNumber *)objc_getAssociatedObject(self, &RevenantColorLinearExposureKey) doubleValue];
}
- (void)setLinearExposure:(CGFloat)exposure
{
    objc_setAssociatedObject(self, &RevenantColorLinearExposureKey, [NSNumber numberWithDouble:(double)exposure],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (UIColor *)standardDynamicRangeColor { return nil; }
@end

@implementation UIColorPickerViewController (RevenantUIKit26)

static char RevenantPickerMaxExposureKey, RevenantPickerSupportsEyedropperKey;

- (CGFloat)maximumLinearExposure
{
    return [(NSNumber *)objc_getAssociatedObject(self, &RevenantPickerMaxExposureKey) doubleValue];
}
- (void)setMaximumLinearExposure:(CGFloat)exposure
{
    objc_setAssociatedObject(self, &RevenantPickerMaxExposureKey, [NSNumber numberWithDouble:(double)exposure],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (BOOL)supportsEyedropper
{
    return [(NSNumber *)objc_getAssociatedObject(self, &RevenantPickerSupportsEyedropperKey) boolValue];
}
- (void)setSupportsEyedropper:(BOOL)supports
{
    objc_setAssociatedObject(self, &RevenantPickerSupportsEyedropperKey, [NSNumber numberWithBool:supports],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end

@implementation UIColorWell (RevenantUIKit26)

static char RevenantColorWellMaxExposureKey, RevenantColorWellSupportsEyedropperKey;

- (CGFloat)maximumLinearExposure
{
    return [(NSNumber *)objc_getAssociatedObject(self, &RevenantColorWellMaxExposureKey) doubleValue];
}
- (void)setMaximumLinearExposure:(CGFloat)exposure
{
    objc_setAssociatedObject(self, &RevenantColorWellMaxExposureKey, [NSNumber numberWithDouble:(double)exposure],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (BOOL)supportsEyedropper
{
    return [(NSNumber *)objc_getAssociatedObject(self, &RevenantColorWellSupportsEyedropperKey) boolValue];
}
- (void)setSupportsEyedropper:(BOOL)supports
{
    objc_setAssociatedObject(self, &RevenantColorWellSupportsEyedropperKey, [NSNumber numberWithBool:supports],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end

@implementation UINavigationItem (RevenantUIKit26)

static char RevenantNavItemAttributedTitleKey, RevenantNavItemAttributedSubtitleKey;
static char RevenantNavItemLargeTitleKey, RevenantNavItemLargeSubtitleKey;
static char RevenantNavItemLargeAttributedTitleKey, RevenantNavItemLargeAttributedSubtitleKey;
static char RevenantNavItemSubtitleViewKey, RevenantNavItemLargeSubtitleViewKey, RevenantNavItemLargeSubtitleKey;
static char RevenantNavItemSearchPlacementKey, RevenantNavItemSearchExternalKey, RevenantNavItemSearchToolbarKey;
static char RevenantNavItemSubtitleKey;

- (NSAttributedString *)attributedTitle { return objc_getAssociatedObject(self, &RevenantNavItemAttributedTitleKey); }
- (void)setAttributedTitle:(NSAttributedString *)title
{
    objc_setAssociatedObject(self, &RevenantNavItemAttributedTitleKey, [title copy],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (NSAttributedString *)attributedSubtitle { return objc_getAssociatedObject(self, &RevenantNavItemAttributedSubtitleKey); }
- (void)setAttributedSubtitle:(NSAttributedString *)subtitle
{
    objc_setAssociatedObject(self, &RevenantNavItemAttributedSubtitleKey, [subtitle copy],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (NSString *)largeTitle { return objc_getAssociatedObject(self, &RevenantNavItemLargeTitleKey); }
- (void)setLargeTitle:(NSString *)title
{
    objc_setAssociatedObject(self, &RevenantNavItemLargeTitleKey, [title copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (NSAttributedString *)largeAttributedTitle { return objc_getAssociatedObject(self, &RevenantNavItemLargeAttributedTitleKey); }
- (void)setLargeAttributedTitle:(NSAttributedString *)title
{
    objc_setAssociatedObject(self, &RevenantNavItemLargeAttributedTitleKey, [title copy],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (NSAttributedString *)largeAttributedSubtitle { return objc_getAssociatedObject(self, &RevenantNavItemLargeAttributedSubtitleKey); }
- (void)setLargeAttributedSubtitle:(NSAttributedString *)subtitle
{
    objc_setAssociatedObject(self, &RevenantNavItemLargeAttributedSubtitleKey, [subtitle copy],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (UIView *)subtitleView { return objc_getAssociatedObject(self, &RevenantNavItemSubtitleViewKey); }
- (void)setSubtitleView:(UIView *)view
{
    objc_setAssociatedObject(self, &RevenantNavItemSubtitleViewKey, view, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (UIView *)largeSubtitleView { return objc_getAssociatedObject(self, &RevenantNavItemLargeSubtitleViewKey); }
- (void)setLargeSubtitleView:(UIView *)view
{
    objc_setAssociatedObject(self, &RevenantNavItemLargeSubtitleViewKey, view, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (NSString *)subtitle { return objc_getAssociatedObject(self, &RevenantNavItemSubtitleKey); }
- (void)setSubtitle:(NSString *)subtitle
{
    objc_setAssociatedObject(self, &RevenantNavItemSubtitleKey, [subtitle copy],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (id)largeSubtitle { return objc_getAssociatedObject(self, &RevenantNavItemLargeSubtitleKey); }
- (void)setLargeSubtitle:(id)subtitle
{
    objc_setAssociatedObject(self, &RevenantNavItemLargeSubtitleKey, subtitle, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (NSInteger)searchBarPlacementBarButtonItem
{
    return [(NSNumber *)objc_getAssociatedObject(self, &RevenantNavItemSearchPlacementKey) integerValue];
}
- (void)setSearchBarPlacementBarButtonItem:(NSInteger)placement
{
    objc_setAssociatedObject(self, &RevenantNavItemSearchPlacementKey, [NSNumber numberWithInteger:placement],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (BOOL)searchBarPlacementAllowsExternalIntegration
{
    return [(NSNumber *)objc_getAssociatedObject(self, &RevenantNavItemSearchExternalKey) boolValue];
}
- (void)setSearchBarPlacementAllowsExternalIntegration:(BOOL)allows
{
    objc_setAssociatedObject(self, &RevenantNavItemSearchExternalKey, [NSNumber numberWithBool:allows],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (BOOL)searchBarPlacementAllowsToolbarIntegration
{
    return [(NSNumber *)objc_getAssociatedObject(self, &RevenantNavItemSearchToolbarKey) boolValue];
}
- (void)setSearchBarPlacementAllowsToolbarIntegration:(BOOL)allows
{
    objc_setAssociatedObject(self, &RevenantNavItemSearchToolbarKey, [NSNumber numberWithBool:allows],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end

@implementation UINavigationBarAppearance (RevenantUIKit26)

static char RevenantBarAppearanceSubtitleAttributesKey, RevenantBarAppearanceLargeSubtitleAttributesKey;

- (NSDictionary<NSAttributedStringKey, id> *)subtitleTextAttributes
{
    return objc_getAssociatedObject(self, &RevenantBarAppearanceSubtitleAttributesKey);
}
- (void)setSubtitleTextAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
{
    objc_setAssociatedObject(self, &RevenantBarAppearanceSubtitleAttributesKey, [attributes copy],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (NSDictionary<NSAttributedStringKey, id> *)largeSubtitleTextAttributes
{
    return objc_getAssociatedObject(self, &RevenantBarAppearanceLargeSubtitleAttributesKey);
}
- (void)setLargeSubtitleTextAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
{
    objc_setAssociatedObject(self, &RevenantBarAppearanceLargeSubtitleAttributesKey, [attributes copy],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end

@implementation UINavigationController (RevenantUIKit26)

static char RevenantNavControllerContentPopGestureKey;

- (UIGestureRecognizer *)interactiveContentPopGestureRecognizer
{
    return objc_getAssociatedObject(self, &RevenantNavControllerContentPopGestureKey);
}
- (void)setInteractiveContentPopGestureRecognizer:(UIGestureRecognizer *)recognizer
{
    objc_setAssociatedObject(self, &RevenantNavControllerContentPopGestureKey, recognizer,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end

@implementation NSObject (RevenantUIKit26_TextInputTraits)

static char RevenantTextInputTraitsAllowsNumberPadPopoverKey;

- (BOOL)allowsNumberPadPopover
{
    return [(NSNumber *)objc_getAssociatedObject(self, &RevenantTextInputTraitsAllowsNumberPadPopoverKey) boolValue];
}
- (void)setAllowsNumberPadPopover:(BOOL)allows
{
    objc_setAssociatedObject(self, &RevenantTextInputTraitsAllowsNumberPadPopoverKey,
                             [NSNumber numberWithBool:allows], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end

@implementation UIViewPropertyAnimator (RevenantUIKit26)

static char RevenantAnimatorFlushUpdatesKey;

- (BOOL)flushUpdates
{
    return [(NSNumber *)objc_getAssociatedObject(self, &RevenantAnimatorFlushUpdatesKey) boolValue];
}
- (void)setFlushUpdates:(BOOL)flushUpdates
{
    objc_setAssociatedObject(self, &RevenantAnimatorFlushUpdatesKey, [NSNumber numberWithBool:flushUpdates],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end

@implementation UIView (RevenantUIKit26)

static char RevenantViewNeedsUpdatePropertiesKey;

- (void)setNeedsUpdateProperties
{
    objc_setAssociatedObject(self, &RevenantViewNeedsUpdatePropertiesKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (void)updatePropertiesIfNeeded
{
    if ([(NSNumber *)objc_getAssociatedObject(self, &RevenantViewNeedsUpdatePropertiesKey) boolValue]) {
        objc_setAssociatedObject(self, &RevenantViewNeedsUpdatePropertiesKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self updateProperties];
    }
}
- (void)updateProperties { }
@end

@implementation UIView (RevenantUIKit26_CornerConfiguration)

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

@implementation UIViewController (RevenantUIKit26)

static char RevenantVCNeedsUpdatePropertiesKey;
static char RevenantVCPrefersOrientationLockedKey, RevenantVCChildForOrientationLockKey;

- (void)setNeedsUpdateProperties
{
    objc_setAssociatedObject(self, &RevenantVCNeedsUpdatePropertiesKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (void)updatePropertiesIfNeeded
{
    if ([(NSNumber *)objc_getAssociatedObject(self, &RevenantVCNeedsUpdatePropertiesKey) boolValue]) {
        objc_setAssociatedObject(self, &RevenantVCNeedsUpdatePropertiesKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self updateProperties];
    }
}
- (void)updateProperties { }
- (void)setNeedsUpdateOfPrefersInterfaceOrientationLocked
{
    objc_setAssociatedObject(self, &RevenantVCNeedsUpdatePropertiesKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (BOOL)prefersInterfaceOrientationLocked
{
    return [(NSNumber *)objc_getAssociatedObject(self, &RevenantVCPrefersOrientationLockedKey) boolValue];
}
- (void)setPrefersInterfaceOrientationLocked:(BOOL)locked
{
    objc_setAssociatedObject(self, &RevenantVCPrefersOrientationLockedKey, [NSNumber numberWithBool:locked],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (UIViewController *)childViewControllerForInterfaceOrientationLock
{
    return objc_getAssociatedObject(self, &RevenantVCChildForOrientationLockKey);
}
- (void)setChildViewControllerForInterfaceOrientationLock:(UIViewController *)child
{
    objc_setAssociatedObject(self, &RevenantVCChildForOrientationLockKey, child,
                             OBJC_ASSOCIATION_ASSIGN);
}
@end

@implementation NSObject (RevenantUIKit26_MenuBuilder)
- (void)insertElements:(NSArray *)elements afterMenuForIdentifier:(NSString *)identifier { }
- (void)insertElements:(NSArray *)elements afterActionForIdentifier:(NSString *)identifier { }
- (void)insertElements:(NSArray *)elements beforeMenuForIdentifier:(NSString *)identifier { }
- (void)insertElements:(NSArray *)elements beforeActionForIdentifier:(NSString *)identifier { }
- (void)insertElements:(NSArray *)elements atStartOfMenuForIdentifier:(NSString *)identifier { }
- (void)insertElements:(NSArray *)elements atEndOfMenuForIdentifier:(NSString *)identifier { }
- (void)insertElements:(NSArray *)elements beforeCommandForAction:(NSString *)action
           propertyList:(id)propertyList { }
- (void)insertElements:(NSArray *)elements afterCommandForAction:(NSString *)action
           propertyList:(id)propertyList { }
- (void)replaceMenuForIdentifier:(NSString *)identifier withElements:(NSArray *)elements { }
- (void)replaceActionForIdentifier:(NSString *)identifier withElements:(NSArray *)elements { }
- (void)replaceCommandForAction:(NSString *)action propertyList:(id)propertyList
                 withElements:(NSArray *)elements { }
- (void)removeActionForIdentifier:(NSString *)identifier { }
- (void)removeCommandForAction:(NSString *)action propertyList:(id)propertyList { }
@end

@implementation UIColor (RevenantUIKit26_Constructors)
+ (UIColor *)colorWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue
                   alpha:(CGFloat)alpha exposure:(CGFloat)exposure
{
    return [self colorWithRed:red green:green blue:blue alpha:alpha];
}
+ (UIColor *)colorWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue
                   alpha:(CGFloat)alpha linearExposure:(CGFloat)exposure
{
    return [self colorWithRed:red green:green blue:blue alpha:alpha];
}
- (UIColor *)initWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue
                   alpha:(CGFloat)alpha exposure:(CGFloat)exposure
{
    return [self initWithRed:red green:green blue:blue alpha:alpha];
}
- (UIColor *)initWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue
                   alpha:(CGFloat)alpha linearExposure:(CGFloat)exposure
{
    return [self initWithRed:red green:green blue:blue alpha:alpha];
}
- (UIColor *)colorByApplyingContentHeadroom:(CGFloat)contentHeadroom { return self; }
@end

@implementation UIImageSymbolConfiguration (RevenantUIKit26)
+ (UIImageSymbolConfiguration *)configurationWithColorRenderingMode:(id)mode
{
    return [self configurationWithPaletteColors:@[]];
}
+ (UIImageSymbolConfiguration *)configurationWithVariableValueMode:(id)mode
{
    return [self configurationWithPaletteColors:@[]];
}
@end

@implementation UITraitCollection (RevenantUIKit26)
+ (UITraitCollection *)traitCollectionWithHDRHeadroomUsageLimit:(id)limit
{
    return [[self currentTraitCollection] copy];
}
+ (UITraitCollection *)traitCollectionWithResolvesNaturalAlignmentWithBaseWritingDirection:(BOOL)resolves
{
    return [[self currentTraitCollection] copy];
}
+ (UITraitCollection *)traitCollectionWithTabAccessoryEnvironment:(id)environment
{
    return [[self currentTraitCollection] copy];
}
@end

@implementation UIBarButtonItem (RevenantUIKit26_Constructors)
+ (UIBarButtonItem *)fixedSpaceItem
{
    return [[self alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:NULL];
}
@end

@implementation UIBarButtonItemGroup (RevenantUIKit26)
+ (UIBarButtonItemGroup *)groupWithFixedSpace { return [[self alloc] init]; }
@end

@implementation UIResponder (RevenantUIKit26)
- (id)providerForDeferredMenuElement:(id)element { return nil; }
@end

@implementation NSObject (RevenantUIKit26_EditActions)
- (void)alignLeft:(id)sender { }
- (void)alignCenter:(id)sender { }
- (void)alignRight:(id)sender { }
- (void)alignJustified:(id)sender { }
- (void)newFromPasteboard:(id)sender { }
- (void)performClose:(id)sender { }
- (void)toggleInspector:(id)sender { }
@end

@implementation NSObject (RevenantUIKit26_SearchBarDelegate)
- (BOOL)searchBar:(UISearchBar *)searchBar shouldChangeTextInRanges:(NSArray<NSValue *> *)ranges
   replacementText:(NSString *)text
{
    return NO;
}
@end

@implementation NSObject (RevenantUIKit26_SplitViewDelegate)
- (void)splitViewController:(UISplitViewController *)controller didShowColumn:(id)column { }
- (void)splitViewController:(UISplitViewController *)controller didHideColumn:(id)column { }
@end

@implementation NSObject (RevenantUIKit26_TextFieldDelegate)
- (BOOL)textField:(UITextField *)field shouldChangeCharactersInRanges:(NSArray<NSValue *> *)ranges
    replacementString:(NSString *)string
{
    return NO;
}
- (id)textField:(UITextField *)field
    editMenuForCharactersInRanges:(NSArray<NSValue *> *)ranges suggestedActions:(id)actions
{
    return nil;
}
@end

@implementation NSObject (RevenantUIKit26_TextViewDelegate)
- (BOOL)textView:(UITextView *)view shouldChangeTextInRanges:(NSArray<NSValue *> *)ranges
    replacementText:(NSString *)text
{
    return NO;
}
- (id)textView:(UITextView *)view
    editMenuForTextInRanges:(NSArray<NSValue *> *)ranges suggestedActions:(id)actions
{
    return nil;
}
@end

@implementation NSObject (RevenantUIKit26_WindowSceneDelegate)
- (void)windowScene:(id)scene didUpdateEffectiveGeometry:(id)geometry { }
- (UISceneWindowingControlStyle *)preferredWindowingControlStyleForScene:(id)scene
{
    return nil;
}
@end
