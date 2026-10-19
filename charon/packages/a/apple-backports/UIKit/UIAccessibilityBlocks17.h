// UIAccessibilityBlocks17.h - the block-form accessibility properties iOS 17.0 added, declared here
// because the 16.4 SDK the package compiles against does not carry them: measured against
// ~/.xmake/packages/i/iphoneos-sdk/16.4/*/…/UIKit.framework/Headers/UIAccessibility.h, that header
// contains no AX*ReturnBlock typedef and no accessibility…Block property at all (0 of each, grep).
// The 26.2 header declares them with the typedefs below, and the guard is __has_include so the file
// compiles against either - the build SDK, where these names do not exist, and the newer SDK the
// host differential compiles against, where they are the system's own and redeclaring them would be
// a duplicate. This is the same shape CharonTraits17.h and UIContentUnavailableProperties.h use.
//
// What the host answers was measured first (facts/UIKit/UIKit17Absence.md, M2), and the answer
// shaped this file: the host carries the SETTER of every one of these and the GETTER of none, and a
// block set through the setter does not reach the plain property the release already has. So the
// declarations are exactly what the host exports - one setter and one getter per property, the getter
// returning the block that was set - and the implementations in UIAccessibilityBlocks17.m store the
// block per object. There is deliberately no bridge from the block to accessibilityLabel: the
// measurement says the host has none either.

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#if !__has_include(<UIKit/UIAccessibilityBlocks.h>)

// The return-block types UIAccessibility.h of 26.2 gives these properties, spelled here because the
// build SDK declares none of them. Each takes no argument and answers one value.
typedef NSString *_Nullable (^AXStringReturnBlock)(void);
typedef NSAttributedString *_Nullable (^AXAttributedStringReturnBlock)(void);
typedef NSArray<NSString *> *_Nullable (^AXStringArrayReturnBlock)(void);
typedef NSArray<NSAttributedString *> *_Nullable (^AXAttributedStringArrayReturnBlock)(void);
typedef NSArray *_Nullable (^AXArrayReturnBlock)(void);
typedef void (^AXVoidReturnBlock)(void);
typedef BOOL (^AXBoolReturnBlock)(void);
typedef UIAccessibilityTraits (^AXTraitsReturnBlock)(void);
typedef UIAccessibilityNavigationStyle (^AXNavigationStyleReturnBlock)(void);
typedef UIAccessibilityContainerType (^AXContainerTypeReturnBlock)(void) API_AVAILABLE(ios(11.0));
typedef UIAccessibilityTextualContext _Nullable (^AXTextualContextReturnBlock)(void) API_AVAILABLE(ios(13.0));
typedef NSArray<UIAccessibilityCustomAction *> *_Nullable (^AXCustomActionsReturnBlock)(void);
typedef NSArray<UIAccessibilityCustomRotor *> *_Nullable (^AXCustomRotorsReturnBlock)(void);
typedef CGPoint (^AXPointReturnBlock)(void);
typedef CGRect (^AXRectReturnBlock)(void);
typedef UIBezierPath *_Nullable (^AXPathReturnBlock)(void);

// UIAccessibilityConstants.h of 26.2 gives accessibilityDirectTouchOptions this NS_OPTIONS; the 16.4
// build SDK declares neither the type nor the property, so both are spelled here. The three cases are
// Apple's, read from that header: none is 0 and the other two are bits 0 and 1.
typedef NS_OPTIONS(NSUInteger, UIAccessibilityDirectTouchOptions) {
    UIAccessibilityDirectTouchOptionNone = 0,
    UIAccessibilityDirectTouchOptionSilentOnTouch = 1 << 0,
    UIAccessibilityDirectTouchOptionRequiresActivation = 1 << 1,
} API_AVAILABLE(ios(17.0));

API_AVAILABLE(ios(17.0), tvos(17.0)) API_UNAVAILABLE(watchos)
@interface NSObject (CharonAccessibilityBlocks17)

// Whether an element is one, and its label, value, hint, traits and identifier
@property (nullable, nonatomic, copy) AXBoolReturnBlock isAccessibilityElementBlock;
@property (nullable, nonatomic, copy) AXStringReturnBlock accessibilityLabelBlock;
@property (nullable, nonatomic, copy) AXStringReturnBlock accessibilityValueBlock;
@property (nullable, nonatomic, copy) AXStringReturnBlock accessibilityHintBlock;
@property (nullable, nonatomic, copy) AXTraitsReturnBlock accessibilityTraitsBlock;
@property (nullable, nonatomic, copy) AXStringReturnBlock accessibilityIdentifierBlock;

// The text and language properties
@property (nullable, nonatomic, copy) AXArrayReturnBlock accessibilityHeaderElementsBlock;
@property (nullable, nonatomic, copy) AXAttributedStringReturnBlock accessibilityAttributedLabelBlock;
@property (nullable, nonatomic, copy) AXAttributedStringReturnBlock accessibilityAttributedHintBlock;
@property (nullable, nonatomic, copy) AXStringReturnBlock accessibilityLanguageBlock;
@property (nullable, nonatomic, copy) AXTextualContextReturnBlock accessibilityTextualContextBlock;
@property (nullable, nonatomic, copy) AXStringArrayReturnBlock accessibilityUserInputLabelsBlock;
@property (nullable, nonatomic, copy) AXAttributedStringArrayReturnBlock accessibilityAttributedUserInputLabelsBlock;
@property (nullable, nonatomic, copy) AXAttributedStringReturnBlock accessibilityAttributedValueBlock;

// The behavior switches
@property (nullable, nonatomic, copy) AXBoolReturnBlock accessibilityElementsHiddenBlock;
@property (nullable, nonatomic, copy) AXBoolReturnBlock accessibilityRespondsToUserInteractionBlock;
@property (nullable, nonatomic, copy) AXBoolReturnBlock accessibilityViewIsModalBlock;
@property (nullable, nonatomic, copy) AXBoolReturnBlock accessibilityShouldGroupAccessibilityChildrenBlock;

// The elements a container exposes to accessibility, and the automation elements
@property (nullable, nonatomic, copy) AXArrayReturnBlock accessibilityElementsBlock;
@property (nullable, nonatomic, copy) AXArrayReturnBlock automationElementsBlock;
@property (nullable, nonatomic, copy) AXArrayReturnBlock automationElements;
@property (nullable, nonatomic, copy) AXContainerTypeReturnBlock accessibilityContainerTypeBlock;
@property (nullable, nonatomic, copy) AXPointReturnBlock accessibilityActivationPointBlock;
@property (nullable, nonatomic, copy) AXRectReturnBlock accessibilityFrameBlock;
@property (nullable, nonatomic, copy) AXNavigationStyleReturnBlock accessibilityNavigationStyleBlock;
@property (nullable, nonatomic, copy) AXPathReturnBlock accessibilityPathBlock;

// Actions
@property (nullable, nonatomic, copy) AXBoolReturnBlock accessibilityActivateBlock;
@property (nullable, nonatomic, copy) AXVoidReturnBlock accessibilityIncrementBlock;
@property (nullable, nonatomic, copy) AXVoidReturnBlock accessibilityDecrementBlock;
@property (nullable, nonatomic, copy) AXBoolReturnBlock accessibilityPerformEscapeBlock;
@property (nullable, nonatomic, copy) AXBoolReturnBlock accessibilityMagicTapBlock;
@property (nullable, nonatomic, copy) AXCustomActionsReturnBlock accessibilityCustomActionsBlock;
@property (nullable, nonatomic, copy) AXCustomRotorsReturnBlock accessibilityCustomRotorsBlock;

// Direct touch
@property (nonatomic) UIAccessibilityDirectTouchOptions accessibilityDirectTouchOptions;

@end

#endif   // !__has_include(<UIKit/UIAccessibilityBlocks.h>)

NS_ASSUME_NONNULL_END