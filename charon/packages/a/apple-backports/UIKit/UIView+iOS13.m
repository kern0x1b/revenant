#import "CharonMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char charon_style_key;

@implementation UIView (CharonThirteen)

- (UIUserInterfaceStyle)overrideUserInterfaceStyle
{
    return (UIUserInterfaceStyle)[objc_getAssociatedObject(self, &charon_style_key) integerValue];
}

// The host does not apply a view's override to the view's trait collection or to the views under it (the darkstyle group),
// so the port keeps it and reads it back and changes nothing else; a view's override is what its controller's is not.
- (void)setOverrideUserInterfaceStyle:(UIUserInterfaceStyle)overrideUserInterfaceStyle
{
    if (overrideUserInterfaceStyle == UIUserInterfaceStyleDark)
        charon_menus_say_once(@"dark-override", @"overrideUserInterfaceStyle of a view is kept and read back; the trait collection of the view and of the views under it does not take it, as the host's does not");
    objc_setAssociatedObject(self, &charon_style_key, @(overrideUserInterfaceStyle), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CATransform3D)transform3D
{
    return self.layer.transform;
}

- (void)setTransform3D:(CATransform3D)transform3D
{
    self.layer.transform = transform3D;
}

+ (void)modifyAnimationsWithRepeatCount:(CGFloat)count autoreverses:(BOOL)autoreverses animations:(void (NS_NOESCAPE ^)(void))animations
{
    charon_menus_say_once(@"modify-animations", @"+modifyAnimationsWithRepeatCount:autoreverses:animations: on iOS 6 sets the repeat count and autoreverse of the whole enclosing animation block, since the release cannot scope them to the animations inside");
    [UIView setAnimationRepeatCount:(float)count];
    [UIView setAnimationRepeatAutoreverses:autoreverses];
    animations();
}

@end
