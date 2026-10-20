#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char RevenantToolTipKey;
static const char RevenantToolTipInteractionKey;

@implementation UIControl (RevenantToolTip15)

- (NSString *)toolTip
{
    return objc_getAssociatedObject(self, &RevenantToolTipKey);
}

- (void)setToolTip:(NSString *)toolTip
{
    objc_setAssociatedObject(self, &RevenantToolTipKey, toolTip, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    UIToolTipInteraction *held = objc_getAssociatedObject(self, &RevenantToolTipInteractionKey);
    if (!toolTip) {
        if (held) {
            [self removeInteraction:held];
            objc_setAssociatedObject(self, &RevenantToolTipInteractionKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        return;
    }
    if (held) {
        held.defaultToolTip = toolTip;
        return;
    }
    UIToolTipInteraction *interaction = [[UIToolTipInteraction alloc] initWithDefaultToolTip:toolTip];
    objc_setAssociatedObject(self, &RevenantToolTipInteractionKey, interaction, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self addInteraction:interaction];
}

- (UIToolTipInteraction *)toolTipInteraction
{
    return objc_getAssociatedObject(self, &RevenantToolTipInteractionKey);
}

@end
