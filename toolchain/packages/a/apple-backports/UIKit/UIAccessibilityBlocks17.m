#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "UIAccessibilityBlocks17.h"

static const char RevenantAXAccessibilityActivateBlockKey;
static const char RevenantAXAccessibilityActivationPointBlockKey;
static const char RevenantAXAccessibilityAttributedHintBlockKey;
static const char RevenantAXAccessibilityAttributedLabelBlockKey;
static const char RevenantAXAccessibilityAttributedUserInputLabelsBlockKey;
static const char RevenantAXAccessibilityAttributedValueBlockKey;
static const char RevenantAXAccessibilityContainerTypeBlockKey;
static const char RevenantAXAccessibilityCustomActionsBlockKey;
static const char RevenantAXAccessibilityCustomRotorsBlockKey;
static const char RevenantAXAccessibilityDecrementBlockKey;
static const char RevenantAXAccessibilityElementsBlockKey;
static const char RevenantAXAccessibilityElementsHiddenBlockKey;
static const char RevenantAXAccessibilityFrameBlockKey;
static const char RevenantAXAccessibilityHeaderElementsBlockKey;
static const char RevenantAXAccessibilityHintBlockKey;
static const char RevenantAXAccessibilityIdentifierBlockKey;
static const char RevenantAXAccessibilityIncrementBlockKey;
static const char RevenantAXAccessibilityLabelBlockKey;
static const char RevenantAXAccessibilityLanguageBlockKey;
static const char RevenantAXAccessibilityMagicTapBlockKey;
static const char RevenantAXAccessibilityNavigationStyleBlockKey;
static const char RevenantAXAccessibilityPathBlockKey;
static const char RevenantAXAccessibilityPerformEscapeBlockKey;
static const char RevenantAXAccessibilityRespondsToUserInteractionBlockKey;
static const char RevenantAXAccessibilityShouldGroupAccessibilityChildrenBlockKey;
static const char RevenantAXAccessibilityTextualContextBlockKey;
static const char RevenantAXAccessibilityTraitsBlockKey;
static const char RevenantAXAccessibilityUserInputLabelsBlockKey;
static const char RevenantAXAccessibilityValueBlockKey;
static const char RevenantAXAccessibilityViewIsModalBlockKey;
static const char RevenantAXAutomationElementsKey;
static const char RevenantAXAutomationElementsBlockKey;
static const char RevenantAXIsAccessibilityElementBlockKey;

static const char RevenantAXDirectTouchOptionsKey;

static id revenant_block_get(id object, const void *key)
{
    return objc_getAssociatedObject(object, key);
}

static void revenant_block_set(id object, const void *key, id block)
{
    objc_setAssociatedObject(object, key, block, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@implementation NSObject (RevenantAccessibilityBlocks17)


- (AXBoolReturnBlock)accessibilityActivateBlock
{
    return revenant_block_get(self, &RevenantAXAccessibilityActivateBlockKey);
}

- (void)setAccessibilityActivateBlock:(AXBoolReturnBlock)block
{
    revenant_block_set(self, &RevenantAXAccessibilityActivateBlockKey, block);
}


- (AXPointReturnBlock)accessibilityActivationPointBlock
{
    return revenant_block_get(self, &RevenantAXAccessibilityActivationPointBlockKey);
}

- (void)setAccessibilityActivationPointBlock:(AXPointReturnBlock)block
{
    revenant_block_set(self, &RevenantAXAccessibilityActivationPointBlockKey, block);
}


- (AXAttributedStringReturnBlock)accessibilityAttributedHintBlock
{
    return revenant_block_get(self, &RevenantAXAccessibilityAttributedHintBlockKey);
}

- (void)setAccessibilityAttributedHintBlock:(AXAttributedStringReturnBlock)block
{
    revenant_block_set(self, &RevenantAXAccessibilityAttributedHintBlockKey, block);
}


- (AXAttributedStringReturnBlock)accessibilityAttributedLabelBlock
{
    return revenant_block_get(self, &RevenantAXAccessibilityAttributedLabelBlockKey);
}

- (void)setAccessibilityAttributedLabelBlock:(AXAttributedStringReturnBlock)block
{
    revenant_block_set(self, &RevenantAXAccessibilityAttributedLabelBlockKey, block);
}


- (AXAttributedStringArrayReturnBlock)accessibilityAttributedUserInputLabelsBlock
{
    return revenant_block_get(self, &RevenantAXAccessibilityAttributedUserInputLabelsBlockKey);
}

- (void)setAccessibilityAttributedUserInputLabelsBlock:(AXAttributedStringArrayReturnBlock)block
{
    revenant_block_set(self, &RevenantAXAccessibilityAttributedUserInputLabelsBlockKey, block);
}


- (AXAttributedStringReturnBlock)accessibilityAttributedValueBlock
{
    return revenant_block_get(self, &RevenantAXAccessibilityAttributedValueBlockKey);
}

- (void)setAccessibilityAttributedValueBlock:(AXAttributedStringReturnBlock)block
{
    revenant_block_set(self, &RevenantAXAccessibilityAttributedValueBlockKey, block);
}


- (AXContainerTypeReturnBlock)accessibilityContainerTypeBlock API_AVAILABLE(ios(11.0))
{
    return revenant_block_get(self, &RevenantAXAccessibilityContainerTypeBlockKey);
}

- (void)setAccessibilityContainerTypeBlock:(AXContainerTypeReturnBlock)block API_AVAILABLE(ios(11.0))
{
    revenant_block_set(self, &RevenantAXAccessibilityContainerTypeBlockKey, block);
}


- (AXCustomActionsReturnBlock)accessibilityCustomActionsBlock
{
    return revenant_block_get(self, &RevenantAXAccessibilityCustomActionsBlockKey);
}

- (void)setAccessibilityCustomActionsBlock:(AXCustomActionsReturnBlock)block
{
    revenant_block_set(self, &RevenantAXAccessibilityCustomActionsBlockKey, block);
}


- (AXCustomRotorsReturnBlock)accessibilityCustomRotorsBlock
{
    return revenant_block_get(self, &RevenantAXAccessibilityCustomRotorsBlockKey);
}

- (void)setAccessibilityCustomRotorsBlock:(AXCustomRotorsReturnBlock)block
{
    revenant_block_set(self, &RevenantAXAccessibilityCustomRotorsBlockKey, block);
}


- (AXVoidReturnBlock)accessibilityDecrementBlock
{
    return revenant_block_get(self, &RevenantAXAccessibilityDecrementBlockKey);
}

- (void)setAccessibilityDecrementBlock:(AXVoidReturnBlock)block
{
    revenant_block_set(self, &RevenantAXAccessibilityDecrementBlockKey, block);
}


- (AXArrayReturnBlock)accessibilityElementsBlock
{
    return revenant_block_get(self, &RevenantAXAccessibilityElementsBlockKey);
}

- (void)setAccessibilityElementsBlock:(AXArrayReturnBlock)block
{
    revenant_block_set(self, &RevenantAXAccessibilityElementsBlockKey, block);
}


- (AXBoolReturnBlock)accessibilityElementsHiddenBlock
{
    return revenant_block_get(self, &RevenantAXAccessibilityElementsHiddenBlockKey);
}

- (void)setAccessibilityElementsHiddenBlock:(AXBoolReturnBlock)block
{
    revenant_block_set(self, &RevenantAXAccessibilityElementsHiddenBlockKey, block);
}


- (AXRectReturnBlock)accessibilityFrameBlock
{
    return revenant_block_get(self, &RevenantAXAccessibilityFrameBlockKey);
}

- (void)setAccessibilityFrameBlock:(AXRectReturnBlock)block
{
    revenant_block_set(self, &RevenantAXAccessibilityFrameBlockKey, block);
}


- (AXArrayReturnBlock)accessibilityHeaderElementsBlock
{
    return revenant_block_get(self, &RevenantAXAccessibilityHeaderElementsBlockKey);
}

- (void)setAccessibilityHeaderElementsBlock:(AXArrayReturnBlock)block
{
    revenant_block_set(self, &RevenantAXAccessibilityHeaderElementsBlockKey, block);
}


- (AXStringReturnBlock)accessibilityHintBlock
{
    return revenant_block_get(self, &RevenantAXAccessibilityHintBlockKey);
}

- (void)setAccessibilityHintBlock:(AXStringReturnBlock)block
{
    revenant_block_set(self, &RevenantAXAccessibilityHintBlockKey, block);
}


- (AXStringReturnBlock)accessibilityIdentifierBlock
{
    return revenant_block_get(self, &RevenantAXAccessibilityIdentifierBlockKey);
}

- (void)setAccessibilityIdentifierBlock:(AXStringReturnBlock)block
{
    revenant_block_set(self, &RevenantAXAccessibilityIdentifierBlockKey, block);
}


- (AXVoidReturnBlock)accessibilityIncrementBlock
{
    return revenant_block_get(self, &RevenantAXAccessibilityIncrementBlockKey);
}

- (void)setAccessibilityIncrementBlock:(AXVoidReturnBlock)block
{
    revenant_block_set(self, &RevenantAXAccessibilityIncrementBlockKey, block);
}


- (AXStringReturnBlock)accessibilityLabelBlock
{
    return revenant_block_get(self, &RevenantAXAccessibilityLabelBlockKey);
}

- (void)setAccessibilityLabelBlock:(AXStringReturnBlock)block
{
    revenant_block_set(self, &RevenantAXAccessibilityLabelBlockKey, block);
}


- (AXStringReturnBlock)accessibilityLanguageBlock
{
    return revenant_block_get(self, &RevenantAXAccessibilityLanguageBlockKey);
}

- (void)setAccessibilityLanguageBlock:(AXStringReturnBlock)block
{
    revenant_block_set(self, &RevenantAXAccessibilityLanguageBlockKey, block);
}


- (AXBoolReturnBlock)accessibilityMagicTapBlock
{
    return revenant_block_get(self, &RevenantAXAccessibilityMagicTapBlockKey);
}

- (void)setAccessibilityMagicTapBlock:(AXBoolReturnBlock)block
{
    revenant_block_set(self, &RevenantAXAccessibilityMagicTapBlockKey, block);
}


- (AXNavigationStyleReturnBlock)accessibilityNavigationStyleBlock
{
    return revenant_block_get(self, &RevenantAXAccessibilityNavigationStyleBlockKey);
}

- (void)setAccessibilityNavigationStyleBlock:(AXNavigationStyleReturnBlock)block
{
    revenant_block_set(self, &RevenantAXAccessibilityNavigationStyleBlockKey, block);
}


- (AXPathReturnBlock)accessibilityPathBlock
{
    return revenant_block_get(self, &RevenantAXAccessibilityPathBlockKey);
}

- (void)setAccessibilityPathBlock:(AXPathReturnBlock)block
{
    revenant_block_set(self, &RevenantAXAccessibilityPathBlockKey, block);
}


- (AXBoolReturnBlock)accessibilityPerformEscapeBlock
{
    return revenant_block_get(self, &RevenantAXAccessibilityPerformEscapeBlockKey);
}

- (void)setAccessibilityPerformEscapeBlock:(AXBoolReturnBlock)block
{
    revenant_block_set(self, &RevenantAXAccessibilityPerformEscapeBlockKey, block);
}


- (AXBoolReturnBlock)accessibilityRespondsToUserInteractionBlock
{
    return revenant_block_get(self, &RevenantAXAccessibilityRespondsToUserInteractionBlockKey);
}

- (void)setAccessibilityRespondsToUserInteractionBlock:(AXBoolReturnBlock)block
{
    revenant_block_set(self, &RevenantAXAccessibilityRespondsToUserInteractionBlockKey, block);
}


- (AXBoolReturnBlock)accessibilityShouldGroupAccessibilityChildrenBlock
{
    return revenant_block_get(self, &RevenantAXAccessibilityShouldGroupAccessibilityChildrenBlockKey);
}

- (void)setAccessibilityShouldGroupAccessibilityChildrenBlock:(AXBoolReturnBlock)block
{
    revenant_block_set(self, &RevenantAXAccessibilityShouldGroupAccessibilityChildrenBlockKey, block);
}


- (AXTextualContextReturnBlock)accessibilityTextualContextBlock API_AVAILABLE(ios(13.0))
{
    return revenant_block_get(self, &RevenantAXAccessibilityTextualContextBlockKey);
}

- (void)setAccessibilityTextualContextBlock:(AXTextualContextReturnBlock)block API_AVAILABLE(ios(13.0))
{
    revenant_block_set(self, &RevenantAXAccessibilityTextualContextBlockKey, block);
}


- (AXTraitsReturnBlock)accessibilityTraitsBlock
{
    return revenant_block_get(self, &RevenantAXAccessibilityTraitsBlockKey);
}

- (void)setAccessibilityTraitsBlock:(AXTraitsReturnBlock)block
{
    revenant_block_set(self, &RevenantAXAccessibilityTraitsBlockKey, block);
}


- (AXStringArrayReturnBlock)accessibilityUserInputLabelsBlock
{
    return revenant_block_get(self, &RevenantAXAccessibilityUserInputLabelsBlockKey);
}

- (void)setAccessibilityUserInputLabelsBlock:(AXStringArrayReturnBlock)block
{
    revenant_block_set(self, &RevenantAXAccessibilityUserInputLabelsBlockKey, block);
}


- (AXStringReturnBlock)accessibilityValueBlock
{
    return revenant_block_get(self, &RevenantAXAccessibilityValueBlockKey);
}

- (void)setAccessibilityValueBlock:(AXStringReturnBlock)block
{
    revenant_block_set(self, &RevenantAXAccessibilityValueBlockKey, block);
}


- (AXBoolReturnBlock)accessibilityViewIsModalBlock
{
    return revenant_block_get(self, &RevenantAXAccessibilityViewIsModalBlockKey);
}

- (void)setAccessibilityViewIsModalBlock:(AXBoolReturnBlock)block
{
    revenant_block_set(self, &RevenantAXAccessibilityViewIsModalBlockKey, block);
}


- (AXArrayReturnBlock)automationElements
{
    return revenant_block_get(self, &RevenantAXAutomationElementsKey);
}

- (void)setAutomationElements:(AXArrayReturnBlock)block
{
    revenant_block_set(self, &RevenantAXAutomationElementsKey, block);
}


- (AXArrayReturnBlock)automationElementsBlock
{
    return revenant_block_get(self, &RevenantAXAutomationElementsBlockKey);
}

- (void)setAutomationElementsBlock:(AXArrayReturnBlock)block
{
    revenant_block_set(self, &RevenantAXAutomationElementsBlockKey, block);
}


- (AXBoolReturnBlock)isAccessibilityElementBlock
{
    return revenant_block_get(self, &RevenantAXIsAccessibilityElementBlockKey);
}

- (void)setIsAccessibilityElementBlock:(AXBoolReturnBlock)block
{
    revenant_block_set(self, &RevenantAXIsAccessibilityElementBlockKey, block);
}


- (UIAccessibilityDirectTouchOptions)accessibilityDirectTouchOptions API_AVAILABLE(ios(17.0))
{
    return (UIAccessibilityDirectTouchOptions)[revenant_block_get(self, &RevenantAXDirectTouchOptionsKey) unsignedIntegerValue];
}

- (void)setAccessibilityDirectTouchOptions:(UIAccessibilityDirectTouchOptions)options API_AVAILABLE(ios(17.0))
{
    revenant_block_set(self, &RevenantAXDirectTouchOptionsKey, @(options));
}


@end
