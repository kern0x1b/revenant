#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// A control's tool tip, from iOS 15. Setting a tool tip gives the control a tool-tip interaction, made the first time and kept after, with
// the tool tip as its default; setting nil takes the interaction off the control and drops it, so the next tool tip is a new interaction.
// The tool tip is kept by reference, as the host keeps it (tests/backports/host/control-tooltip), not copied as the header's copy says.
// The interaction is the port's UIToolTipInteraction, which the release's interaction class answers for.
static const char CharonToolTipKey;
static const char CharonToolTipInteractionKey;

@implementation UIControl (CharonToolTip15)

- (NSString *)toolTip
{
    return objc_getAssociatedObject(self, &CharonToolTipKey);
}

- (void)setToolTip:(NSString *)toolTip
{
    objc_setAssociatedObject(self, &CharonToolTipKey, toolTip, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    UIToolTipInteraction *held = objc_getAssociatedObject(self, &CharonToolTipInteractionKey);
    if (!toolTip) {
        if (held) {
            [self removeInteraction:held];
            objc_setAssociatedObject(self, &CharonToolTipInteractionKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        return;
    }
    if (held) {
        held.defaultToolTip = toolTip;
        return;
    }
    UIToolTipInteraction *interaction = [[UIToolTipInteraction alloc] initWithDefaultToolTip:toolTip];
    objc_setAssociatedObject(self, &CharonToolTipInteractionKey, interaction, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self addInteraction:interaction];
}

- (UIToolTipInteraction *)toolTipInteraction
{
    return objc_getAssociatedObject(self, &CharonToolTipInteractionKey);
}

@end
