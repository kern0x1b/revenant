// UIAccessibilityBlocks17.m - the 33 block-form accessibility properties of iOS 17.0, on NSObject,
// so they are reachable from every object that already inherits the release's own accessibility API.
//
// What the host answers was measured first (facts/UIKit/UIKit17Absence.md, M2), and the measurement
// decided this file's whole shape:
//
//   * The host carries the SETTER of all 33 and the GETTER of none. Read from the runtime, not from a
//     header: on NSObject, UIResponder and UIView alike, -instancesRespondToSelector: answers YES for
//     e.g. setAccessibilityLabelBlock: and NO for accessibilityLabelBlock, isAccessibilityLabelBlock
//     and _accessibilityLabelBlock. So the port implements both halves anyway - a property whose
//     setter the host has and whose getter it does not is a property a caller can set and cannot read,
//     and a port that carried only the setter would be a worse API than the host's. What the port does
//     NOT do is invent a third spelling to explain the missing getter.
//
//   * A block set through the setter does NOT reach the plain property. Measured on the host: a UIView
//     whose accessibilityLabel is "plain" still answers "plain" after
//     setAccessibilityLabelBlock: takes a block returning "from-block". So this file stores the block
//     and does not bridge it into accessibilityLabel, because the host does not either and a bridge
//     here would be the port answering something the system does not. The plain properties stay the
//     release's own; a caller that wants VoiceOver to read a label sets accessibilityLabel, which is
//     what this release's VoiceOver reads.
//
// Storage is one associated object per property, with the copy policy the header states, so a mutable
// block the caller goes on editing does not change what the object answers - the same rule the port
// already keeps for the attributed label, hint and value in NSObject+AccessibilityAttributedStrings.m.
// The key is a distinct address per property, which is what keeps -accessibilityElementsBlock from
// reading what -accessibilityHeaderElementsBlock stored.

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "UIAccessibilityBlocks17.h"

// One address per property. Declared file-static so the addresses are distinct from one another and
// cannot collide with another translation unit's, and const so a caller cannot take one.
static const char CharonAXAccessibilityActivateBlockKey;
static const char CharonAXAccessibilityActivationPointBlockKey;
static const char CharonAXAccessibilityAttributedHintBlockKey;
static const char CharonAXAccessibilityAttributedLabelBlockKey;
static const char CharonAXAccessibilityAttributedUserInputLabelsBlockKey;
static const char CharonAXAccessibilityAttributedValueBlockKey;
static const char CharonAXAccessibilityContainerTypeBlockKey;
static const char CharonAXAccessibilityCustomActionsBlockKey;
static const char CharonAXAccessibilityCustomRotorsBlockKey;
static const char CharonAXAccessibilityDecrementBlockKey;
static const char CharonAXAccessibilityElementsBlockKey;
static const char CharonAXAccessibilityElementsHiddenBlockKey;
static const char CharonAXAccessibilityFrameBlockKey;
static const char CharonAXAccessibilityHeaderElementsBlockKey;
static const char CharonAXAccessibilityHintBlockKey;
static const char CharonAXAccessibilityIdentifierBlockKey;
static const char CharonAXAccessibilityIncrementBlockKey;
static const char CharonAXAccessibilityLabelBlockKey;
static const char CharonAXAccessibilityLanguageBlockKey;
static const char CharonAXAccessibilityMagicTapBlockKey;
static const char CharonAXAccessibilityNavigationStyleBlockKey;
static const char CharonAXAccessibilityPathBlockKey;
static const char CharonAXAccessibilityPerformEscapeBlockKey;
static const char CharonAXAccessibilityRespondsToUserInteractionBlockKey;
static const char CharonAXAccessibilityShouldGroupAccessibilityChildrenBlockKey;
static const char CharonAXAccessibilityTextualContextBlockKey;
static const char CharonAXAccessibilityTraitsBlockKey;
static const char CharonAXAccessibilityUserInputLabelsBlockKey;
static const char CharonAXAccessibilityValueBlockKey;
static const char CharonAXAccessibilityViewIsModalBlockKey;
static const char CharonAXAutomationElementsKey;
static const char CharonAXAutomationElementsBlockKey;
static const char CharonAXIsAccessibilityElementBlockKey;

static const char CharonAXDirectTouchOptionsKey;

static id charon_block_get(id object, const void *key)
{
    return objc_getAssociatedObject(object, key);
}

static void charon_block_set(id object, const void *key, id block)
{
    // copy, not retain: the header says `copy`, and a stack block that has returned must not be left
    // reachable through the object.
    objc_setAssociatedObject(object, key, block, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@implementation NSObject (CharonAccessibilityBlocks17)


- (AXBoolReturnBlock)accessibilityActivateBlock
{
    return charon_block_get(self, &CharonAXAccessibilityActivateBlockKey);
}

- (void)setAccessibilityActivateBlock:(AXBoolReturnBlock)block
{
    charon_block_set(self, &CharonAXAccessibilityActivateBlockKey, block);
}


- (AXPointReturnBlock)accessibilityActivationPointBlock
{
    return charon_block_get(self, &CharonAXAccessibilityActivationPointBlockKey);
}

- (void)setAccessibilityActivationPointBlock:(AXPointReturnBlock)block
{
    charon_block_set(self, &CharonAXAccessibilityActivationPointBlockKey, block);
}


- (AXAttributedStringReturnBlock)accessibilityAttributedHintBlock
{
    return charon_block_get(self, &CharonAXAccessibilityAttributedHintBlockKey);
}

- (void)setAccessibilityAttributedHintBlock:(AXAttributedStringReturnBlock)block
{
    charon_block_set(self, &CharonAXAccessibilityAttributedHintBlockKey, block);
}


- (AXAttributedStringReturnBlock)accessibilityAttributedLabelBlock
{
    return charon_block_get(self, &CharonAXAccessibilityAttributedLabelBlockKey);
}

- (void)setAccessibilityAttributedLabelBlock:(AXAttributedStringReturnBlock)block
{
    charon_block_set(self, &CharonAXAccessibilityAttributedLabelBlockKey, block);
}


- (AXAttributedStringArrayReturnBlock)accessibilityAttributedUserInputLabelsBlock
{
    return charon_block_get(self, &CharonAXAccessibilityAttributedUserInputLabelsBlockKey);
}

- (void)setAccessibilityAttributedUserInputLabelsBlock:(AXAttributedStringArrayReturnBlock)block
{
    charon_block_set(self, &CharonAXAccessibilityAttributedUserInputLabelsBlockKey, block);
}


- (AXAttributedStringReturnBlock)accessibilityAttributedValueBlock
{
    return charon_block_get(self, &CharonAXAccessibilityAttributedValueBlockKey);
}

- (void)setAccessibilityAttributedValueBlock:(AXAttributedStringReturnBlock)block
{
    charon_block_set(self, &CharonAXAccessibilityAttributedValueBlockKey, block);
}


- (AXContainerTypeReturnBlock)accessibilityContainerTypeBlock API_AVAILABLE(ios(11.0))
{
    return charon_block_get(self, &CharonAXAccessibilityContainerTypeBlockKey);
}

- (void)setAccessibilityContainerTypeBlock:(AXContainerTypeReturnBlock)block API_AVAILABLE(ios(11.0))
{
    charon_block_set(self, &CharonAXAccessibilityContainerTypeBlockKey, block);
}


- (AXCustomActionsReturnBlock)accessibilityCustomActionsBlock
{
    return charon_block_get(self, &CharonAXAccessibilityCustomActionsBlockKey);
}

- (void)setAccessibilityCustomActionsBlock:(AXCustomActionsReturnBlock)block
{
    charon_block_set(self, &CharonAXAccessibilityCustomActionsBlockKey, block);
}


- (AXCustomRotorsReturnBlock)accessibilityCustomRotorsBlock
{
    return charon_block_get(self, &CharonAXAccessibilityCustomRotorsBlockKey);
}

- (void)setAccessibilityCustomRotorsBlock:(AXCustomRotorsReturnBlock)block
{
    charon_block_set(self, &CharonAXAccessibilityCustomRotorsBlockKey, block);
}


- (AXVoidReturnBlock)accessibilityDecrementBlock
{
    return charon_block_get(self, &CharonAXAccessibilityDecrementBlockKey);
}

- (void)setAccessibilityDecrementBlock:(AXVoidReturnBlock)block
{
    charon_block_set(self, &CharonAXAccessibilityDecrementBlockKey, block);
}


- (AXArrayReturnBlock)accessibilityElementsBlock
{
    return charon_block_get(self, &CharonAXAccessibilityElementsBlockKey);
}

- (void)setAccessibilityElementsBlock:(AXArrayReturnBlock)block
{
    charon_block_set(self, &CharonAXAccessibilityElementsBlockKey, block);
}


- (AXBoolReturnBlock)accessibilityElementsHiddenBlock
{
    return charon_block_get(self, &CharonAXAccessibilityElementsHiddenBlockKey);
}

- (void)setAccessibilityElementsHiddenBlock:(AXBoolReturnBlock)block
{
    charon_block_set(self, &CharonAXAccessibilityElementsHiddenBlockKey, block);
}


- (AXRectReturnBlock)accessibilityFrameBlock
{
    return charon_block_get(self, &CharonAXAccessibilityFrameBlockKey);
}

- (void)setAccessibilityFrameBlock:(AXRectReturnBlock)block
{
    charon_block_set(self, &CharonAXAccessibilityFrameBlockKey, block);
}


- (AXArrayReturnBlock)accessibilityHeaderElementsBlock
{
    return charon_block_get(self, &CharonAXAccessibilityHeaderElementsBlockKey);
}

- (void)setAccessibilityHeaderElementsBlock:(AXArrayReturnBlock)block
{
    charon_block_set(self, &CharonAXAccessibilityHeaderElementsBlockKey, block);
}


- (AXStringReturnBlock)accessibilityHintBlock
{
    return charon_block_get(self, &CharonAXAccessibilityHintBlockKey);
}

- (void)setAccessibilityHintBlock:(AXStringReturnBlock)block
{
    charon_block_set(self, &CharonAXAccessibilityHintBlockKey, block);
}


- (AXStringReturnBlock)accessibilityIdentifierBlock
{
    return charon_block_get(self, &CharonAXAccessibilityIdentifierBlockKey);
}

- (void)setAccessibilityIdentifierBlock:(AXStringReturnBlock)block
{
    charon_block_set(self, &CharonAXAccessibilityIdentifierBlockKey, block);
}


- (AXVoidReturnBlock)accessibilityIncrementBlock
{
    return charon_block_get(self, &CharonAXAccessibilityIncrementBlockKey);
}

- (void)setAccessibilityIncrementBlock:(AXVoidReturnBlock)block
{
    charon_block_set(self, &CharonAXAccessibilityIncrementBlockKey, block);
}


- (AXStringReturnBlock)accessibilityLabelBlock
{
    return charon_block_get(self, &CharonAXAccessibilityLabelBlockKey);
}

- (void)setAccessibilityLabelBlock:(AXStringReturnBlock)block
{
    charon_block_set(self, &CharonAXAccessibilityLabelBlockKey, block);
}


- (AXStringReturnBlock)accessibilityLanguageBlock
{
    return charon_block_get(self, &CharonAXAccessibilityLanguageBlockKey);
}

- (void)setAccessibilityLanguageBlock:(AXStringReturnBlock)block
{
    charon_block_set(self, &CharonAXAccessibilityLanguageBlockKey, block);
}


- (AXBoolReturnBlock)accessibilityMagicTapBlock
{
    return charon_block_get(self, &CharonAXAccessibilityMagicTapBlockKey);
}

- (void)setAccessibilityMagicTapBlock:(AXBoolReturnBlock)block
{
    charon_block_set(self, &CharonAXAccessibilityMagicTapBlockKey, block);
}


- (AXNavigationStyleReturnBlock)accessibilityNavigationStyleBlock
{
    return charon_block_get(self, &CharonAXAccessibilityNavigationStyleBlockKey);
}

- (void)setAccessibilityNavigationStyleBlock:(AXNavigationStyleReturnBlock)block
{
    charon_block_set(self, &CharonAXAccessibilityNavigationStyleBlockKey, block);
}


- (AXPathReturnBlock)accessibilityPathBlock
{
    return charon_block_get(self, &CharonAXAccessibilityPathBlockKey);
}

- (void)setAccessibilityPathBlock:(AXPathReturnBlock)block
{
    charon_block_set(self, &CharonAXAccessibilityPathBlockKey, block);
}


- (AXBoolReturnBlock)accessibilityPerformEscapeBlock
{
    return charon_block_get(self, &CharonAXAccessibilityPerformEscapeBlockKey);
}

- (void)setAccessibilityPerformEscapeBlock:(AXBoolReturnBlock)block
{
    charon_block_set(self, &CharonAXAccessibilityPerformEscapeBlockKey, block);
}


- (AXBoolReturnBlock)accessibilityRespondsToUserInteractionBlock
{
    return charon_block_get(self, &CharonAXAccessibilityRespondsToUserInteractionBlockKey);
}

- (void)setAccessibilityRespondsToUserInteractionBlock:(AXBoolReturnBlock)block
{
    charon_block_set(self, &CharonAXAccessibilityRespondsToUserInteractionBlockKey, block);
}


- (AXBoolReturnBlock)accessibilityShouldGroupAccessibilityChildrenBlock
{
    return charon_block_get(self, &CharonAXAccessibilityShouldGroupAccessibilityChildrenBlockKey);
}

- (void)setAccessibilityShouldGroupAccessibilityChildrenBlock:(AXBoolReturnBlock)block
{
    charon_block_set(self, &CharonAXAccessibilityShouldGroupAccessibilityChildrenBlockKey, block);
}


- (AXTextualContextReturnBlock)accessibilityTextualContextBlock API_AVAILABLE(ios(13.0))
{
    return charon_block_get(self, &CharonAXAccessibilityTextualContextBlockKey);
}

- (void)setAccessibilityTextualContextBlock:(AXTextualContextReturnBlock)block API_AVAILABLE(ios(13.0))
{
    charon_block_set(self, &CharonAXAccessibilityTextualContextBlockKey, block);
}


- (AXTraitsReturnBlock)accessibilityTraitsBlock
{
    return charon_block_get(self, &CharonAXAccessibilityTraitsBlockKey);
}

- (void)setAccessibilityTraitsBlock:(AXTraitsReturnBlock)block
{
    charon_block_set(self, &CharonAXAccessibilityTraitsBlockKey, block);
}


- (AXStringArrayReturnBlock)accessibilityUserInputLabelsBlock
{
    return charon_block_get(self, &CharonAXAccessibilityUserInputLabelsBlockKey);
}

- (void)setAccessibilityUserInputLabelsBlock:(AXStringArrayReturnBlock)block
{
    charon_block_set(self, &CharonAXAccessibilityUserInputLabelsBlockKey, block);
}


- (AXStringReturnBlock)accessibilityValueBlock
{
    return charon_block_get(self, &CharonAXAccessibilityValueBlockKey);
}

- (void)setAccessibilityValueBlock:(AXStringReturnBlock)block
{
    charon_block_set(self, &CharonAXAccessibilityValueBlockKey, block);
}


- (AXBoolReturnBlock)accessibilityViewIsModalBlock
{
    return charon_block_get(self, &CharonAXAccessibilityViewIsModalBlockKey);
}

- (void)setAccessibilityViewIsModalBlock:(AXBoolReturnBlock)block
{
    charon_block_set(self, &CharonAXAccessibilityViewIsModalBlockKey, block);
}


- (AXArrayReturnBlock)automationElements
{
    return charon_block_get(self, &CharonAXAutomationElementsKey);
}

- (void)setAutomationElements:(AXArrayReturnBlock)block
{
    charon_block_set(self, &CharonAXAutomationElementsKey, block);
}


- (AXArrayReturnBlock)automationElementsBlock
{
    return charon_block_get(self, &CharonAXAutomationElementsBlockKey);
}

- (void)setAutomationElementsBlock:(AXArrayReturnBlock)block
{
    charon_block_set(self, &CharonAXAutomationElementsBlockKey, block);
}


- (AXBoolReturnBlock)isAccessibilityElementBlock
{
    return charon_block_get(self, &CharonAXIsAccessibilityElementBlockKey);
}

- (void)setIsAccessibilityElementBlock:(AXBoolReturnBlock)block
{
    charon_block_set(self, &CharonAXIsAccessibilityElementBlockKey, block);
}


- (UIAccessibilityDirectTouchOptions)accessibilityDirectTouchOptions API_AVAILABLE(ios(17.0))
{
    // Not a block and not a plain stored value: the host answers the getter with a real value, so the
    // port keeps one. A fresh object has no direct-touch area, which is the header's own None = 0, and
    // the setter stores what it is given under a key of its own.
    return (UIAccessibilityDirectTouchOptions)[charon_block_get(self, &CharonAXDirectTouchOptionsKey) unsignedIntegerValue];
}

- (void)setAccessibilityDirectTouchOptions:(UIAccessibilityDirectTouchOptions)options API_AVAILABLE(ios(17.0))
{
    charon_block_set(self, &CharonAXDirectTouchOptionsKey, @(options));
}


@end
