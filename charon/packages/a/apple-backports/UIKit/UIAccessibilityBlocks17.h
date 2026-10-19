#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#if !__has_include(<UIKit/UIAccessibilityBlocks.h>)

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

typedef NS_OPTIONS(NSUInteger, UIAccessibilityDirectTouchOptions) {
    UIAccessibilityDirectTouchOptionNone = 0,
    UIAccessibilityDirectTouchOptionSilentOnTouch = 1 << 0,
    UIAccessibilityDirectTouchOptionRequiresActivation = 1 << 1,
} API_AVAILABLE(ios(17.0));

API_AVAILABLE(ios(17.0), tvos(17.0)) API_UNAVAILABLE(watchos)
@interface NSObject (CharonAccessibilityBlocks17)

@property (nullable, nonatomic, copy) AXBoolReturnBlock isAccessibilityElementBlock;
@property (nullable, nonatomic, copy) AXStringReturnBlock accessibilityLabelBlock;
@property (nullable, nonatomic, copy) AXStringReturnBlock accessibilityValueBlock;
@property (nullable, nonatomic, copy) AXStringReturnBlock accessibilityHintBlock;
@property (nullable, nonatomic, copy) AXTraitsReturnBlock accessibilityTraitsBlock;
@property (nullable, nonatomic, copy) AXStringReturnBlock accessibilityIdentifierBlock;

@property (nullable, nonatomic, copy) AXArrayReturnBlock accessibilityHeaderElementsBlock;
@property (nullable, nonatomic, copy) AXAttributedStringReturnBlock accessibilityAttributedLabelBlock;
@property (nullable, nonatomic, copy) AXAttributedStringReturnBlock accessibilityAttributedHintBlock;
@property (nullable, nonatomic, copy) AXStringReturnBlock accessibilityLanguageBlock;
@property (nullable, nonatomic, copy) AXTextualContextReturnBlock accessibilityTextualContextBlock;
@property (nullable, nonatomic, copy) AXStringArrayReturnBlock accessibilityUserInputLabelsBlock;
@property (nullable, nonatomic, copy) AXAttributedStringArrayReturnBlock accessibilityAttributedUserInputLabelsBlock;
@property (nullable, nonatomic, copy) AXAttributedStringReturnBlock accessibilityAttributedValueBlock;

@property (nullable, nonatomic, copy) AXBoolReturnBlock accessibilityElementsHiddenBlock;
@property (nullable, nonatomic, copy) AXBoolReturnBlock accessibilityRespondsToUserInteractionBlock;
@property (nullable, nonatomic, copy) AXBoolReturnBlock accessibilityViewIsModalBlock;
@property (nullable, nonatomic, copy) AXBoolReturnBlock accessibilityShouldGroupAccessibilityChildrenBlock;

@property (nullable, nonatomic, copy) AXArrayReturnBlock accessibilityElementsBlock;
@property (nullable, nonatomic, copy) AXArrayReturnBlock automationElementsBlock;
@property (nullable, nonatomic, copy) AXArrayReturnBlock automationElements;
@property (nullable, nonatomic, copy) AXContainerTypeReturnBlock accessibilityContainerTypeBlock;
@property (nullable, nonatomic, copy) AXPointReturnBlock accessibilityActivationPointBlock;
@property (nullable, nonatomic, copy) AXRectReturnBlock accessibilityFrameBlock;
@property (nullable, nonatomic, copy) AXNavigationStyleReturnBlock accessibilityNavigationStyleBlock;
@property (nullable, nonatomic, copy) AXPathReturnBlock accessibilityPathBlock;

@property (nullable, nonatomic, copy) AXBoolReturnBlock accessibilityActivateBlock;
@property (nullable, nonatomic, copy) AXVoidReturnBlock accessibilityIncrementBlock;
@property (nullable, nonatomic, copy) AXVoidReturnBlock accessibilityDecrementBlock;
@property (nullable, nonatomic, copy) AXBoolReturnBlock accessibilityPerformEscapeBlock;
@property (nullable, nonatomic, copy) AXBoolReturnBlock accessibilityMagicTapBlock;
@property (nullable, nonatomic, copy) AXCustomActionsReturnBlock accessibilityCustomActionsBlock;
@property (nullable, nonatomic, copy) AXCustomRotorsReturnBlock accessibilityCustomRotorsBlock;

@property (nonatomic) UIAccessibilityDirectTouchOptions accessibilityDirectTouchOptions;

@end

#endif

NS_ASSUME_NONNULL_END
