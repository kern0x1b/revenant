#import "CharonUIKit26.h"
#import <objc/runtime.h>

static inline id CharonBox(id value) { return value; }

@implementation UIGlassEffect
@end

@implementation UIGlassContainerEffect
@end

@implementation UICornerRadius
@end

@implementation UICornerConfiguration
@end

@implementation UIScrollEdgeEffect
@end

@implementation UIScrollEdgeEffectStyle
@end

@implementation UIScrollEdgeElementContainerInteraction
@end

@implementation UISliderTick
@end

@implementation UISliderTrackConfiguration
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

@implementation UIScrollView (CharonUIKit26)

static char CharonTopEdgeEffectKey, CharonLeftEdgeEffectKey;
static char CharonRightEdgeEffectKey, CharonBottomEdgeEffectKey;

- (UIScrollEdgeEffect *)topEdgeEffect { return objc_getAssociatedObject(self, &CharonTopEdgeEffectKey); }
- (void)setTopEdgeEffect:(UIScrollEdgeEffect *)effect
{
    objc_setAssociatedObject(self, &CharonTopEdgeEffectKey, effect, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (UIScrollEdgeEffect *)leftEdgeEffect { return objc_getAssociatedObject(self, &CharonLeftEdgeEffectKey); }
- (void)setLeftEdgeEffect:(UIScrollEdgeEffect *)effect
{
    objc_setAssociatedObject(self, &CharonLeftEdgeEffectKey, effect, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (UIScrollEdgeEffect *)rightEdgeEffect { return objc_getAssociatedObject(self, &CharonRightEdgeEffectKey); }
- (void)setRightEdgeEffect:(UIScrollEdgeEffect *)effect
{
    objc_setAssociatedObject(self, &CharonRightEdgeEffectKey, effect, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (UIScrollEdgeEffect *)bottomEdgeEffect { return objc_getAssociatedObject(self, &CharonBottomEdgeEffectKey); }
- (void)setBottomEdgeEffect:(UIScrollEdgeEffect *)effect
{
    objc_setAssociatedObject(self, &CharonBottomEdgeEffectKey, effect, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end

@implementation UISlider (CharonUIKit26)

static char CharonSliderStyleKey, CharonSliderTrackConfigurationKey;

- (NSInteger)sliderStyle
{
    return [(NSNumber *)objc_getAssociatedObject(self, &CharonSliderStyleKey) integerValue];
}
- (void)setSliderStyle:(NSInteger)style
{
    objc_setAssociatedObject(self, &CharonSliderStyleKey, [NSNumber numberWithInteger:style],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (UISliderTrackConfiguration *)trackConfiguration
{
    return objc_getAssociatedObject(self, &CharonSliderTrackConfigurationKey);
}
- (void)setTrackConfiguration:(UISliderTrackConfiguration *)configuration
{
    objc_setAssociatedObject(self, &CharonSliderTrackConfigurationKey, configuration,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end

@implementation UIBarButtonItem (CharonUIKit26)

static char CharonBarItemBadgeKey, CharonBarItemIdentifierKey;
static char CharonBarItemSharesBackgroundKey, CharonBarItemHidesSharedBackgroundKey;

- (UIBarButtonItemBadge *)badge { return objc_getAssociatedObject(self, &CharonBarItemBadgeKey); }
- (void)setBadge:(UIBarButtonItemBadge *)badge
{
    objc_setAssociatedObject(self, &CharonBarItemBadgeKey, badge, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (NSString *)identifier { return objc_getAssociatedObject(self, &CharonBarItemIdentifierKey); }
- (void)setIdentifier:(NSString *)identifier
{
    objc_setAssociatedObject(self, &CharonBarItemIdentifierKey, [identifier copy],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (BOOL)sharesBackground
{
    return [(NSNumber *)objc_getAssociatedObject(self, &CharonBarItemSharesBackgroundKey) boolValue];
}
- (void)setSharesBackground:(BOOL)shares
{
    objc_setAssociatedObject(self, &CharonBarItemSharesBackgroundKey, [NSNumber numberWithBool:shares],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (BOOL)hidesSharedBackground
{
    return [(NSNumber *)objc_getAssociatedObject(self, &CharonBarItemHidesSharedBackgroundKey) boolValue];
}
- (void)setHidesSharedBackground:(BOOL)hides
{
    objc_setAssociatedObject(self, &CharonBarItemHidesSharedBackgroundKey, [NSNumber numberWithBool:hides],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end

@implementation UIDeferredMenuElement (CharonUIKit26)

static char CharonDeferredElementIdentifierKey;

+ (UIDeferredMenuElement *)elementUsingFocusWithIdentifier:(NSString *)identifier
                                            shouldCacheItems:(BOOL)shouldCache
{
    return [self elementWithProvider:^(void (^completion)(NSArray<UIMenuElement *> *)) {
        if (completion != NULL)
            completion(@[]);
    }];
}

- (NSString *)identifier { return objc_getAssociatedObject(self, &CharonDeferredElementIdentifierKey); }
@end

@implementation UIScene (CharonUIKit26)

static char CharonSceneDestructionConditionsKey;

- (NSSet<UISceneDestructionCondition *> *)destructionConditions
{
    return objc_getAssociatedObject(self, &CharonSceneDestructionConditionsKey);
}
- (void)setDestructionConditions:(NSSet<UISceneDestructionCondition *> *)conditions
{
    objc_setAssociatedObject(self, &CharonSceneDestructionConditionsKey, [conditions copy],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end

@implementation UISplitViewController (CharonUIKit26)

static char CharonMaxInspectorKey, CharonMinInspectorKey, CharonMinSecondaryKey;
static char CharonPrefInspectorKey, CharonPrefInspectorFractionKey;
static char CharonPrefSecondaryKey, CharonPrefSecondaryFractionKey;

- (CGFloat)maximumInspectorColumnWidth
{
    return [(NSNumber *)objc_getAssociatedObject(self, &CharonMaxInspectorKey) doubleValue];
}
- (void)setMaximumInspectorColumnWidth:(CGFloat)width
{
    objc_setAssociatedObject(self, &CharonMaxInspectorKey, [NSNumber numberWithDouble:(double)width],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (CGFloat)minimumInspectorColumnWidth
{
    return [(NSNumber *)objc_getAssociatedObject(self, &CharonMinInspectorKey) doubleValue];
}
- (void)setMinimumInspectorColumnWidth:(CGFloat)width
{
    objc_setAssociatedObject(self, &CharonMinInspectorKey, [NSNumber numberWithDouble:(double)width],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (CGFloat)minimumSecondaryColumnWidth
{
    return [(NSNumber *)objc_getAssociatedObject(self, &CharonMinSecondaryKey) doubleValue];
}
- (void)setMinimumSecondaryColumnWidth:(CGFloat)width
{
    objc_setAssociatedObject(self, &CharonMinSecondaryKey, [NSNumber numberWithDouble:(double)width],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (CGFloat)preferredInspectorColumnWidth
{
    return [(NSNumber *)objc_getAssociatedObject(self, &CharonPrefInspectorKey) doubleValue];
}
- (void)setPreferredInspectorColumnWidth:(CGFloat)width
{
    objc_setAssociatedObject(self, &CharonPrefInspectorKey, [NSNumber numberWithDouble:(double)width],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (CGFloat)preferredInspectorColumnWidthFraction
{
    return [(NSNumber *)objc_getAssociatedObject(self, &CharonPrefInspectorFractionKey) doubleValue];
}
- (void)setPreferredInspectorColumnWidthFraction:(CGFloat)fraction
{
    objc_setAssociatedObject(self, &CharonPrefInspectorFractionKey,
                             [NSNumber numberWithDouble:(double)fraction], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (CGFloat)preferredSecondaryColumnWidth
{
    return [(NSNumber *)objc_getAssociatedObject(self, &CharonPrefSecondaryKey) doubleValue];
}
- (void)setPreferredSecondaryColumnWidth:(CGFloat)width
{
    objc_setAssociatedObject(self, &CharonPrefSecondaryKey, [NSNumber numberWithDouble:(double)width],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (CGFloat)preferredSecondaryColumnWidthFraction
{
    return [(NSNumber *)objc_getAssociatedObject(self, &CharonPrefSecondaryFractionKey) doubleValue];
}
- (void)setPreferredSecondaryColumnWidthFraction:(CGFloat)fraction
{
    objc_setAssociatedObject(self, &CharonPrefSecondaryFractionKey,
                             [NSNumber numberWithDouble:(double)fraction], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isShowingColumn:(id)column { return NO; }
@end

@implementation UITabBarController (CharonUIKit26)

static char CharonTabBarBottomAccessoryKey, CharonTabBarMinimizeBehaviorKey;
static char CharonTabBarContentLayoutGuideKey;

- (UITabAccessory *)bottomAccessory
{
    return objc_getAssociatedObject(self, &CharonTabBarBottomAccessoryKey);
}
- (void)setBottomAccessory:(UITabAccessory *)accessory
{
    objc_setAssociatedObject(self, &CharonTabBarBottomAccessoryKey, accessory,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (void)setBottomAccessory:(UITabAccessory *)accessory animated:(BOOL)animated
{
    self.bottomAccessory = accessory;
}
- (NSInteger)tabBarMinimizeBehavior
{
    return [(NSNumber *)objc_getAssociatedObject(self, &CharonTabBarMinimizeBehaviorKey) integerValue];
}
- (void)setTabBarMinimizeBehavior:(NSInteger)behavior
{
    objc_setAssociatedObject(self, &CharonTabBarMinimizeBehaviorKey, [NSNumber numberWithInteger:behavior],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (id)contentLayoutGuide
{
    return objc_getAssociatedObject(self, &CharonTabBarContentLayoutGuideKey);
}
- (void)setContentLayoutGuide:(id)guide
{
    objc_setAssociatedObject(self, &CharonTabBarContentLayoutGuideKey, guide,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end

@implementation UITextView (CharonUIKit26)

static char CharonTextViewSelectedRangesKey;

- (NSArray<NSValue *> *)selectedRanges
{
    return objc_getAssociatedObject(self, &CharonTextViewSelectedRangesKey);
}
- (void)setSelectedRanges:(NSArray<NSValue *> *)ranges
{
    objc_setAssociatedObject(self, &CharonTextViewSelectedRangesKey,
                             ranges.count ? [ranges copy] : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end

@implementation NSTextList (CharonUIKit26)

+ (BOOL)includesTextListMarkers
{
    return NO;
}

@end

@implementation UIColor (CharonUIKit26)

static char CharonColorLinearExposureKey;

- (CGFloat)linearExposure
{
    return [(NSNumber *)objc_getAssociatedObject(self, &CharonColorLinearExposureKey) doubleValue];
}
- (void)setLinearExposure:(CGFloat)exposure
{
    objc_setAssociatedObject(self, &CharonColorLinearExposureKey, [NSNumber numberWithDouble:(double)exposure],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (UIColor *)standardDynamicRangeColor { return nil; }
@end

@implementation UIColorPickerViewController (CharonUIKit26)

static char CharonPickerMaxExposureKey, CharonPickerSupportsEyedropperKey;

- (CGFloat)maximumLinearExposure
{
    return [(NSNumber *)objc_getAssociatedObject(self, &CharonPickerMaxExposureKey) doubleValue];
}
- (void)setMaximumLinearExposure:(CGFloat)exposure
{
    objc_setAssociatedObject(self, &CharonPickerMaxExposureKey, [NSNumber numberWithDouble:(double)exposure],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (BOOL)supportsEyedropper
{
    return [(NSNumber *)objc_getAssociatedObject(self, &CharonPickerSupportsEyedropperKey) boolValue];
}
- (void)setSupportsEyedropper:(BOOL)supports
{
    objc_setAssociatedObject(self, &CharonPickerSupportsEyedropperKey, [NSNumber numberWithBool:supports],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end

@implementation UIColorWell (CharonUIKit26)

static char CharonColorWellMaxExposureKey, CharonColorWellSupportsEyedropperKey;

- (CGFloat)maximumLinearExposure
{
    return [(NSNumber *)objc_getAssociatedObject(self, &CharonColorWellMaxExposureKey) doubleValue];
}
- (void)setMaximumLinearExposure:(CGFloat)exposure
{
    objc_setAssociatedObject(self, &CharonColorWellMaxExposureKey, [NSNumber numberWithDouble:(double)exposure],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (BOOL)supportsEyedropper
{
    return [(NSNumber *)objc_getAssociatedObject(self, &CharonColorWellSupportsEyedropperKey) boolValue];
}
- (void)setSupportsEyedropper:(BOOL)supports
{
    objc_setAssociatedObject(self, &CharonColorWellSupportsEyedropperKey, [NSNumber numberWithBool:supports],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end

@implementation UINavigationItem (CharonUIKit26)

static char CharonNavItemAttributedTitleKey, CharonNavItemAttributedSubtitleKey;
static char CharonNavItemLargeTitleKey, CharonNavItemLargeSubtitleKey;
static char CharonNavItemLargeAttributedTitleKey, CharonNavItemLargeAttributedSubtitleKey;
static char CharonNavItemSubtitleViewKey, CharonNavItemLargeSubtitleViewKey, CharonNavItemLargeSubtitleKey;
static char CharonNavItemSearchPlacementKey, CharonNavItemSearchExternalKey, CharonNavItemSearchToolbarKey;
static char CharonNavItemSubtitleKey;

- (NSAttributedString *)attributedTitle { return objc_getAssociatedObject(self, &CharonNavItemAttributedTitleKey); }
- (void)setAttributedTitle:(NSAttributedString *)title
{
    objc_setAssociatedObject(self, &CharonNavItemAttributedTitleKey, [title copy],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (NSAttributedString *)attributedSubtitle { return objc_getAssociatedObject(self, &CharonNavItemAttributedSubtitleKey); }
- (void)setAttributedSubtitle:(NSAttributedString *)subtitle
{
    objc_setAssociatedObject(self, &CharonNavItemAttributedSubtitleKey, [subtitle copy],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (NSString *)largeTitle { return objc_getAssociatedObject(self, &CharonNavItemLargeTitleKey); }
- (void)setLargeTitle:(NSString *)title
{
    objc_setAssociatedObject(self, &CharonNavItemLargeTitleKey, [title copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (NSAttributedString *)largeAttributedTitle { return objc_getAssociatedObject(self, &CharonNavItemLargeAttributedTitleKey); }
- (void)setLargeAttributedTitle:(NSAttributedString *)title
{
    objc_setAssociatedObject(self, &CharonNavItemLargeAttributedTitleKey, [title copy],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (NSAttributedString *)largeAttributedSubtitle { return objc_getAssociatedObject(self, &CharonNavItemLargeAttributedSubtitleKey); }
- (void)setLargeAttributedSubtitle:(NSAttributedString *)subtitle
{
    objc_setAssociatedObject(self, &CharonNavItemLargeAttributedSubtitleKey, [subtitle copy],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (UIView *)subtitleView { return objc_getAssociatedObject(self, &CharonNavItemSubtitleViewKey); }
- (void)setSubtitleView:(UIView *)view
{
    objc_setAssociatedObject(self, &CharonNavItemSubtitleViewKey, view, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (UIView *)largeSubtitleView { return objc_getAssociatedObject(self, &CharonNavItemLargeSubtitleViewKey); }
- (void)setLargeSubtitleView:(UIView *)view
{
    objc_setAssociatedObject(self, &CharonNavItemLargeSubtitleViewKey, view, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (NSString *)subtitle { return objc_getAssociatedObject(self, &CharonNavItemSubtitleKey); }
- (void)setSubtitle:(NSString *)subtitle
{
    objc_setAssociatedObject(self, &CharonNavItemSubtitleKey, [subtitle copy],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (id)largeSubtitle { return objc_getAssociatedObject(self, &CharonNavItemLargeSubtitleKey); }
- (void)setLargeSubtitle:(id)subtitle
{
    objc_setAssociatedObject(self, &CharonNavItemLargeSubtitleKey, subtitle, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (NSInteger)searchBarPlacementBarButtonItem
{
    return [(NSNumber *)objc_getAssociatedObject(self, &CharonNavItemSearchPlacementKey) integerValue];
}
- (void)setSearchBarPlacementBarButtonItem:(NSInteger)placement
{
    objc_setAssociatedObject(self, &CharonNavItemSearchPlacementKey, [NSNumber numberWithInteger:placement],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (BOOL)searchBarPlacementAllowsExternalIntegration
{
    return [(NSNumber *)objc_getAssociatedObject(self, &CharonNavItemSearchExternalKey) boolValue];
}
- (void)setSearchBarPlacementAllowsExternalIntegration:(BOOL)allows
{
    objc_setAssociatedObject(self, &CharonNavItemSearchExternalKey, [NSNumber numberWithBool:allows],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (BOOL)searchBarPlacementAllowsToolbarIntegration
{
    return [(NSNumber *)objc_getAssociatedObject(self, &CharonNavItemSearchToolbarKey) boolValue];
}
- (void)setSearchBarPlacementAllowsToolbarIntegration:(BOOL)allows
{
    objc_setAssociatedObject(self, &CharonNavItemSearchToolbarKey, [NSNumber numberWithBool:allows],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end

@implementation UINavigationBarAppearance (CharonUIKit26)

static char CharonBarAppearanceSubtitleAttributesKey, CharonBarAppearanceLargeSubtitleAttributesKey;

- (NSDictionary<NSAttributedStringKey, id> *)subtitleTextAttributes
{
    return objc_getAssociatedObject(self, &CharonBarAppearanceSubtitleAttributesKey);
}
- (void)setSubtitleTextAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
{
    objc_setAssociatedObject(self, &CharonBarAppearanceSubtitleAttributesKey, [attributes copy],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (NSDictionary<NSAttributedStringKey, id> *)largeSubtitleTextAttributes
{
    return objc_getAssociatedObject(self, &CharonBarAppearanceLargeSubtitleAttributesKey);
}
- (void)setLargeSubtitleTextAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
{
    objc_setAssociatedObject(self, &CharonBarAppearanceLargeSubtitleAttributesKey, [attributes copy],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end

@implementation UINavigationController (CharonUIKit26)

static char CharonNavControllerContentPopGestureKey;

- (UIGestureRecognizer *)interactiveContentPopGestureRecognizer
{
    return objc_getAssociatedObject(self, &CharonNavControllerContentPopGestureKey);
}
- (void)setInteractiveContentPopGestureRecognizer:(UIGestureRecognizer *)recognizer
{
    objc_setAssociatedObject(self, &CharonNavControllerContentPopGestureKey, recognizer,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end

@implementation NSObject (CharonUIKit26_TextInputTraits)

static char CharonTextInputTraitsAllowsNumberPadPopoverKey;

- (BOOL)allowsNumberPadPopover
{
    return [(NSNumber *)objc_getAssociatedObject(self, &CharonTextInputTraitsAllowsNumberPadPopoverKey) boolValue];
}
- (void)setAllowsNumberPadPopover:(BOOL)allows
{
    objc_setAssociatedObject(self, &CharonTextInputTraitsAllowsNumberPadPopoverKey,
                             [NSNumber numberWithBool:allows], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end

@implementation UIViewPropertyAnimator (CharonUIKit26)

static char CharonAnimatorFlushUpdatesKey;

- (BOOL)flushUpdates
{
    return [(NSNumber *)objc_getAssociatedObject(self, &CharonAnimatorFlushUpdatesKey) boolValue];
}
- (void)setFlushUpdates:(BOOL)flushUpdates
{
    objc_setAssociatedObject(self, &CharonAnimatorFlushUpdatesKey, [NSNumber numberWithBool:flushUpdates],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end

@implementation UIView (CharonUIKit26)

static char CharonViewNeedsUpdatePropertiesKey;

- (void)setNeedsUpdateProperties
{
    objc_setAssociatedObject(self, &CharonViewNeedsUpdatePropertiesKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (void)updatePropertiesIfNeeded
{
    if ([(NSNumber *)objc_getAssociatedObject(self, &CharonViewNeedsUpdatePropertiesKey) boolValue]) {
        objc_setAssociatedObject(self, &CharonViewNeedsUpdatePropertiesKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self updateProperties];
    }
}
- (void)updateProperties { }
@end

@implementation UIViewController (CharonUIKit26)

static char CharonVCNeedsUpdatePropertiesKey;
static char CharonVCPrefersOrientationLockedKey, CharonVCChildForOrientationLockKey;

- (void)setNeedsUpdateProperties
{
    objc_setAssociatedObject(self, &CharonVCNeedsUpdatePropertiesKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (void)updatePropertiesIfNeeded
{
    if ([(NSNumber *)objc_getAssociatedObject(self, &CharonVCNeedsUpdatePropertiesKey) boolValue]) {
        objc_setAssociatedObject(self, &CharonVCNeedsUpdatePropertiesKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self updateProperties];
    }
}
- (void)updateProperties { }
- (void)setNeedsUpdateOfPrefersInterfaceOrientationLocked
{
    objc_setAssociatedObject(self, &CharonVCNeedsUpdatePropertiesKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (BOOL)prefersInterfaceOrientationLocked
{
    return [(NSNumber *)objc_getAssociatedObject(self, &CharonVCPrefersOrientationLockedKey) boolValue];
}
- (void)setPrefersInterfaceOrientationLocked:(BOOL)locked
{
    objc_setAssociatedObject(self, &CharonVCPrefersOrientationLockedKey, [NSNumber numberWithBool:locked],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (UIViewController *)childViewControllerForInterfaceOrientationLock
{
    return objc_getAssociatedObject(self, &CharonVCChildForOrientationLockKey);
}
- (void)setChildViewControllerForInterfaceOrientationLock:(UIViewController *)child
{
    objc_setAssociatedObject(self, &CharonVCChildForOrientationLockKey, child,
                             OBJC_ASSOCIATION_ASSIGN);
}
@end

@implementation NSObject (CharonUIKit26_MenuBuilder)
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

@implementation UIColor (CharonUIKit26_Constructors)
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

@implementation UIImageSymbolConfiguration (CharonUIKit26)
+ (UIImageSymbolConfiguration *)configurationWithColorRenderingMode:(id)mode
{
    return [self configurationWithPaletteColors:@[]];
}
+ (UIImageSymbolConfiguration *)configurationWithVariableValueMode:(id)mode
{
    return [self configurationWithPaletteColors:@[]];
}
@end

@implementation UITraitCollection (CharonUIKit26)
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

@implementation UIBarButtonItem (CharonUIKit26_Constructors)
+ (UIBarButtonItem *)fixedSpaceItem
{
    return [[self alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:NULL];
}
@end

@implementation UIBarButtonItemGroup (CharonUIKit26)
+ (UIBarButtonItemGroup *)groupWithFixedSpace { return [[self alloc] init]; }
@end

@implementation UIResponder (CharonUIKit26)
- (id)providerForDeferredMenuElement:(id)element { return nil; }
@end

@implementation NSObject (CharonUIKit26_EditActions)
- (void)alignLeft:(id)sender { }
- (void)alignCenter:(id)sender { }
- (void)alignRight:(id)sender { }
- (void)alignJustified:(id)sender { }
- (void)newFromPasteboard:(id)sender { }
- (void)performClose:(id)sender { }
- (void)toggleInspector:(id)sender { }
@end

@implementation NSObject (CharonUIKit26_SearchBarDelegate)
- (BOOL)searchBar:(UISearchBar *)searchBar shouldChangeTextInRanges:(NSArray<NSValue *> *)ranges
   replacementText:(NSString *)text
{
    return NO;
}
@end

@implementation NSObject (CharonUIKit26_SplitViewDelegate)
- (void)splitViewController:(UISplitViewController *)controller didShowColumn:(id)column { }
- (void)splitViewController:(UISplitViewController *)controller didHideColumn:(id)column { }
@end

@implementation NSObject (CharonUIKit26_TextFieldDelegate)
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

@implementation NSObject (CharonUIKit26_TextViewDelegate)
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

@implementation NSObject (CharonUIKit26_WindowSceneDelegate)
- (void)windowScene:(id)scene didUpdateEffectiveGeometry:(id)geometry { }
- (UISceneWindowingControlStyle *)preferredWindowingControlStyleForScene:(id)scene
{
    return nil;
}
@end
