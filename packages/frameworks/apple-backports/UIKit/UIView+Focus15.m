#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static char revenant_focus_effect_key;
static char revenant_focus_priority_key;

@implementation UIView (RevenantFocus15)

- (UIFocusEffect *)focusEffect
{
    id effect = objc_getAssociatedObject(self, &revenant_focus_effect_key);
    if (!effect)
        return [UIFocusEffect effect];
    return effect == [NSNull null] ? nil : effect;
}

- (void)setFocusEffect:(UIFocusEffect *)focusEffect
{
    objc_setAssociatedObject(self, &revenant_focus_effect_key, focusEffect ? [focusEffect copy] : [NSNull null], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIFocusGroupPriority)focusGroupPriority
{
    NSNumber *priority = objc_getAssociatedObject(self, &revenant_focus_priority_key);
    return priority ? priority.integerValue : UIFocusGroupPriorityIgnored;
}

- (void)setFocusGroupPriority:(UIFocusGroupPriority)focusGroupPriority
{
    objc_setAssociatedObject(self, &revenant_focus_priority_key, @(focusGroupPriority), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
