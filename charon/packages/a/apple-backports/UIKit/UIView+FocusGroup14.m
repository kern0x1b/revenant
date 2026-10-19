#import "CharonMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char charon_group_key;

@implementation UIView (CharonFocusGroup14)

- (NSString *)focusGroupIdentifier
{
    return objc_getAssociatedObject(self, &charon_group_key);
}

- (void)setFocusGroupIdentifier:(NSString *)focusGroupIdentifier
{
    if (focusGroupIdentifier)
        charon_menus_say_once(@"focus-group", @"focusGroupIdentifier: iOS 6 has no focus engine to group views by, so the identifier is kept and read back");
    objc_setAssociatedObject(self, &charon_group_key, [focusGroupIdentifier copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
