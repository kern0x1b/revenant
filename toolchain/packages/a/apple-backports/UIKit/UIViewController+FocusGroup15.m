#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static char revenant_vc_focus_group_key;

@implementation UIViewController (RevenantFocusGroup15)

- (NSString *)focusGroupIdentifier
{
    return objc_getAssociatedObject(self, &revenant_vc_focus_group_key);
}

- (void)setFocusGroupIdentifier:(NSString *)focusGroupIdentifier
{
    objc_setAssociatedObject(self, &revenant_vc_focus_group_key, [focusGroupIdentifier copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
