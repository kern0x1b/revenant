#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

// UIView's focusEffect and focusGroupPriority, iOS 15. No focus engine runs on the port, so nothing reads them; they are kept as set. The effect
// reads back a plain UIFocusEffect when none is set, and a fresh one on each read, and a nil set reads back nil, as the host does (measured by tests/backports/host/focus-effects).
// The priority starts at 0, the UIFocusGroupPriorityIgnored the header names, and keeps the value set, the three named values included.
static char charon_focus_effect_key;
static char charon_focus_priority_key;

@implementation UIView (CharonFocus15)

- (UIFocusEffect *)focusEffect
{
    id effect = objc_getAssociatedObject(self, &charon_focus_effect_key);
    if (!effect)
        return [UIFocusEffect effect];
    return effect == [NSNull null] ? nil : effect;
}

- (void)setFocusEffect:(UIFocusEffect *)focusEffect
{
    // A nil set is kept as nil, which the host reads back, and differs from a view that was never set.
    objc_setAssociatedObject(self, &charon_focus_effect_key, focusEffect ? [focusEffect copy] : [NSNull null], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIFocusGroupPriority)focusGroupPriority
{
    NSNumber *priority = objc_getAssociatedObject(self, &charon_focus_priority_key);
    return priority ? priority.integerValue : UIFocusGroupPriorityIgnored;
}

- (void)setFocusGroupPriority:(UIFocusGroupPriority)focusGroupPriority
{
    objc_setAssociatedObject(self, &charon_focus_priority_key, @(focusGroupPriority), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
