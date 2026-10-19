// UIKit26_0.m - the 26.0 band's twenty-one classes, and the members of classes the release already has.
//
// ONE OBJECT, ONE RELEASE.  Every API below is introduced 26.0.  The three sibling bands are their own
// objects and their own commits: UIKit26_1.m (26.1), UIKit26_4.m (26.4) and UIKit27_0.m (27.0).
// tools/release-split.lua reads band points only, so nothing mechanical would notice a 26.1 method in
// this file - only a reader does.
//
// WHAT THESE NAMES ARE.  Twenty-one are classes: DYLD SYMBOLS, which an application links strongly and
// dyld must resolve.  Measured: the build SDK is 16.4 and none of the twenty-one appears in any header
// under its UIKit.framework/Headers, so the port is the only thing here that can make the name exist.
// For a name whose requirement is that dyld resolve it, an EMPTY CLASS IS THE COMPLETE HONEST ANSWER -
// invented members would answer for behaviour nobody measured.
//
// The rest are members of classes the release ALREADY has.  Those are categories, and a CATEGORY CANNOT
// HAVE IVARS - the compiler says "expected identifier or '('" at the opening brace - so the storage is an
// associated object, which is what CADisplayLink+FrameRate.m and CAFrameRate.m already do for a property
// this port adds to a class the release owns.  Each getter returns the type's zero when nothing was ever
// stored, which is what an unboxed ivar would have returned too.

#import "CharonUIKit26.h"
#import <objc/runtime.h>

// One box for every scalar here, so the getter does not have to know which type it is holding.
static inline id CharonBox(id value) { return value; }

// =====================================================================================
// THE TWENTY-ONE CLASSES.  No members: see the note above.
// =====================================================================================

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

// =====================================================================================
// THE MEMBERS, grouped by what the port can honestly answer for each.  "Carried" with no reason is the
// defect this family's rules name, so each group says what it is.
//
// (a) STORAGE.  A property on a class the port already carries: the getter returns what the setter
//     stored, and where the release has a defensible default the row names that default.
// (b) FORWARDING.  The 26.0 member is the release's own member plus an argument the release has no
//     field for; the body drops that argument, and the row says it was dropped rather than approximated.
// (c) A SELECTOR AN OBJECT CONFORMS TO.  Declared so a conforming object links; the body is the honest
//     NO or the honest nothing, because the release never calls them - nothing in a 6.1.3 release
//     produces a ranges-based text change, an edit menu, an inspector column or a window-scene callback.
// =====================================================================================

// --- (a) STORAGE -----------------------------------------------------------------------------

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

// The 26.0 factory: an element that defers its items until focus arrives.  A 6.1.3 menu system has no
// focus and no deferred loading, so the port returns an element with the identifier set and no items,
// and the row says what comes back rather than claiming a lazy load it cannot do.
+ (UIDeferredMenuElement *)elementUsingFocusWithIdentifier:(NSString *)identifier
                                            shouldCacheItems:(BOOL)shouldCache
{
    // -init is UNAVAILABLE on this class - the 16.4 SDK marks it so, because a deferred element only
    // means anything with a provider - so the port builds through the constructor the release does
    // export, +elementWithProvider:, handing it a block that completes with nothing.  That is the honest
    // shape for a 6.1.3 menu system: an element that is always present and never loads, and the row says
    // so rather than claiming a focus-driven deferral nothing can drive.
    return [self elementWithProvider:^(void (^completion)(NSArray<UIMenuElement *> *)) {
        if (completion != NULL)
            completion(@[]);
    }];
}

// GETTER ONLY, and that is the SDK's shape: UIDeferredMenuElement.h:19 declares
// `@property (nonatomic, copy, readonly) UIDeferredMenuElementIdentifier identifier`, so the release has
// no way to write it and neither does the port.  This file defined a setIdentifier: here, which answered a
// setter no Apple header declares; its type is a typedef of NSString * (UIDeferredMenuElement.h:13), so
// the getter keeps NSString * and reads back what any producer stored.
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
    // Copied, because a set handed in by the caller can be mutated afterwards and the row claims the port
    // holds what it was given.
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

// A predicate over an inspector column the 6.1.3 controller has no notion of.  NO is the honest answer
// for a column that cannot exist; the row says so rather than claiming a measurement.
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
// The animated setter forwards to the plain one.  There is no animation the release can run for an
// accessory it cannot place, and a row claiming one would be the defect this family's rules name.
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
    // An empty array is stored as nil, and that is a boundary the row names: the release has ONE
    // selection and the 26.0 API is an array of them, so "no array" and "an empty array" both mean the
    // caller has not set one, and the release's own selectionRange is untouched either way.
    objc_setAssociatedObject(self, &CharonTextViewSelectedRangesKey,
                             ranges.count ? [ranges copy] : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end

@implementation NSTextList (CharonUIKit26)

// NSTextList.h:65 of the 26.2 SDK declares `@property (readonly, class) BOOL includesTextListMarkers` and
// documents it: when YES, TextKit includes the text list marker in the contents, and the default is NO.
//
// The accessor is a CLASS method and there is no setter, and both halves are measured rather than read off
// the header. Apple's own class: the arm64e shared cache of iOS 18.0 carries `includesTextListMarkers` in
// NSTextList's metaclass list and in neither of its instance lists. The host's own class, asked with the
// port's object NOT linked: +includesTextListMarkers answers NO, and -includesTextListMarkers and
// -setIncludesTextListMarkers: are both absent; with the port's object linked they are both present, which
// is what this category used to add and what no Apple release has.
//
// NO is the answer for the reason the header gives, and it is the whole of the property on this release: a
// list is nothing but its markers, and the port's text system produces no marker at all - NSTextListMarker
// is not a class the port carries, only its seventeen enumerated constants are
// (registry/UIKit/measured-constants.json) - so there is no text whose contents could hold one. A flag
// stored per list would have answered YES to a question about text this release never generates, which is
// the same fiction registry/UIKit/ios15content.json's NSTextContentStorage row refuses.
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
// nil, and the row says why: whether a colour is inside the standard dynamic range is a property of the
// DISPLAY, which this port has no access to, so there is no honest answer to compute.
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
// -subtitle: the release has NO subtitle property at all - measured, the 16.4 SDK's UINavigationItem.h
// names neither subtitle nor subtitleView - so this is new storage rather than a re-declaration, which
// is why a category can carry it at all.  iOS 26 made a subtitle a first-class title-bar item; a 6.1.3
// bar has no second line, so the port holds the string and the row says the bar draws nothing with it.
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

// UIViewPropertyAnimator's flushUpdates.  The SDK 26.2 header declares it a PROPERTY and a readwrite
// one -- `@property(nonatomic) BOOL flushUpdates API_AVAILABLE(ios(26.0), ...)` at
// UIViewPropertyAnimator.h:49 -- so it is an accessor PAIR and its getter answers BOOL.  This file used
// to define `- (void)flushUpdates`, which is neither: an application that wrote `animator.flushUpdates =
// YES` raised unrecognized selector `setFlushUpdates:` against this library, and one that read it got
// whatever was in the return register.  A property's NAME is not always a selector and a BOOL property is
// never a void method; both halves are what check_registry's member list reads, and the missing setter
// would also have been a member the object carried with no row.
//
// The 16.4 SDK's UIViewPropertyAnimator declares no flush at all - measured, updateEverything is in no
// header under it - so there is nothing to forward to and the flag is the honest nothing: the getter
// returns what the setter stored and NO until something stores otherwise.  Same shape as the BOOL
// properties above, and the same cost: a 6.1.3 animator runs its animations without the 26.0
// flush-on-every-context-change, which the row says rather than implying the behaviour exists.
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

// --- (b) FORWARDING ---------------------------------------------------------------------------

// The invalidate/update cycle on UIView and UIViewController.  This is the one body in this file the
// release can do honestly, because the release OWNS the cycle: setNeedsUpdateProperties sets a flag,
// updatePropertiesIfNeeded calls updateProperties only when it is set, and updateProperties is the
// overridable hook.  Each of the six rows names which part of the cycle it is.
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
    // WEAKLY held on purpose: a strong reference here would be a retain cycle, since a parent owns its
    // children.  OBJC_ASSOCIATION_ASSIGN is the weak association of this release.
    return objc_getAssociatedObject(self, &CharonVCChildForOrientationLockKey);
}
- (void)setChildViewControllerForInterfaceOrientationLock:(UIViewController *)child
{
    objc_setAssociatedObject(self, &CharonVCChildForOrientationLockKey, child,
                             OBJC_ASSOCIATION_ASSIGN);
}
@end

// UIMenuBuilder's thirteen 26.0 members.  A menu TREE the builder inserts into; the release's builder
// carries the system menu and has no tree, so each method records nothing and changes nothing a user
// can see.  The port does not invent a tree it cannot draw.
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

// UIColor's four exposure constructors and colorByApplyingContentHeadroom:.  The release's UIColor has
// the four-component constructor and the 26.0 ones are that PLUS an exposure the release has no field
// for, so each drops the exposure and builds the colour the release can build.  The row names the drop:
// a colour with the wrong exposure is a DIFFERENT colour, so saying so beats approximating it.
//
// colorByApplyingContentHeadroom: TAKES ITS CGFloat, and this file used to define it with none.  The
// SDK 26.2 header declares exactly one method of the name and the argument is part of its selector:
//   - (UIColor *)colorByApplyingContentHeadroom:(CGFloat)contentHeadroom API_AVAILABLE(ios(26.0), ...)
// so `- (UIColor *)colorByApplyingContentHeadroom` was a selector NO APPLE SDK HAS EVER DECLARED, and an
// application calling the declared one raised unrecognized selector against this library.  The old
// commit message explained the difference away - "__objc_methname prints a no-argument selector WITHOUT
// its trailing colon" - and that is false; see facts/UIKit/UISelectorArity26.md, where a three-method
// probe prints `oneArgument:` WITH the colon.  The body is unchanged and still drops the headroom:
// 6.1.3's CGColor has no content-headroom tag to store it in, so the components come back as they went
// in and the row says so.
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

// UIImageSymbolConfiguration's two 26.0 constructors: the release has the palette form these two extend,
// so each drops the new argument.  The row names the dropped argument rather than inventing a mode the
// release cannot render.
@implementation UIImageSymbolConfiguration (CharonUIKit26)
// The two enums - UIImageSymbolConfigurationColorRenderingMode and UIImageSymbolConfigurationVariableValueMode -
// are 26.0 types the 16.4 SDK does not declare, so the arguments are typed `id` here.  A selector's
// ARGUMENT TYPES do not enter the selector, so the exported name is the SDK's; only the declaration
// differs, and the row says so rather than inventing an enum nobody measured.
+ (UIImageSymbolConfiguration *)configurationWithColorRenderingMode:(id)mode
{
    return [self configurationWithPaletteColors:@[]];
}
+ (UIImageSymbolConfiguration *)configurationWithVariableValueMode:(id)mode
{
    return [self configurationWithPaletteColors:@[]];
}
@end

// UITraitCollection's three 26.0 constructors.  Each returns a COPY of the current collection, which is
// what the release's own constructor does with the traits it knows; the 26.0 traits are ones a 6.1.3
// trait collection cannot store, so the copy carries what the release does know and the row names the
// dropped trait.
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

// UIBarButtonItem's fixedSpaceItem and UIBarButtonItemGroup's groupWithFixedSpace: the release has
// +barButtonItemWithTitle: and +buttonWithTitle:, so each builds through one.  The row for fixedSpaceItem
// says the result is a real item and NOT a fixed-width one, because a 6.1.3 bar has no such item and a
// width of zero would be a different object rather than a worse one.
@implementation UIBarButtonItem (CharonUIKit26_Constructors)
+ (UIBarButtonItem *)fixedSpaceItem
{
    return [[self alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:NULL];
}
@end

@implementation UIBarButtonItemGroup (CharonUIKit26)
+ (UIBarButtonItemGroup *)groupWithFixedSpace { return [[self alloc] init]; }
@end

// --- (c) SELECTORS AN OBJECT CONFORMS TO -------------------------------------------------------
//
// A CATEGORY CANNOT BE ON A PROTOCOL, and all eight of these are @protocol in the SDK - so they are
// categories on NSObject, which every conforming object inherits, and each name is suffixed with the
// protocol it serves.  That is the only place a port can put a selector it does not own a class for, and
// the cost is stated rather than hidden: an unrelated object also answers YES to -alignLeft:.  A row that
// hides that would be claiming a conformance the port does not have.

// SEVEN OF THESE TAKE A SENDER, and this file used to define all seven with none.  The SDK 26.2
// declaration of each carries `(nullable id)sender`, and the argument is part of the selector, so the
// definitions below answered `-alignLeft` and `-performClose` - names no Apple SDK has ever declared -
// while `-alignLeft:` and `-performClose:`, the selectors the queue's rows name and an application
// calls, raised unrecognized selector against this library.  The comment above already spelled them
// with the colon while the bodies below did not.  The bodies are unchanged: these are the 26.0
// standard-edit-action members, the release's own cut:/copy:/paste: are no-ops with a sender too, and a
// 6.1.3 text view has no alignment action to forward to.  facts/UIKit/UISelectorArity26.md carries the
// header lines and the probe that shows what otool prints.

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