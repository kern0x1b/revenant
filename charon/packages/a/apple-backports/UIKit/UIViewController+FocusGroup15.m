#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

// UIViewController's focusGroupIdentifier, iOS 15. Kept as set, copied, and nil to start, as the view's own identifier is. No focus engine
// reads it on the port.
static char charon_vc_focus_group_key;

@implementation UIViewController (CharonFocusGroup15)

- (NSString *)focusGroupIdentifier
{
    return objc_getAssociatedObject(self, &charon_vc_focus_group_key);
}

- (void)setFocusGroupIdentifier:(NSString *)focusGroupIdentifier
{
    objc_setAssociatedObject(self, &charon_vc_focus_group_key, [focusGroupIdentifier copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
