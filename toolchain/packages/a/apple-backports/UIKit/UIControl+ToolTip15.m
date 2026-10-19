#import <UIKit/UIKit.h>
#import <objc/runtime.h>

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
