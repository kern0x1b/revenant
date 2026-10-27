#import "RevenantMenus.h"
#import "RevenantTraitStyle.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char revenant_style_key;

UIUserInterfaceStyle revenant_view_style_override(UIView *view)
{
    return (UIUserInterfaceStyle)[objc_getAssociatedObject(view, &revenant_style_key) integerValue];
}

@implementation UIView (RevenantThirteen)

- (UIUserInterfaceStyle)overrideUserInterfaceStyle
{
    return revenant_view_style_override(self);
}

- (void)setOverrideUserInterfaceStyle:(UIUserInterfaceStyle)overrideUserInterfaceStyle
{
    revenant_deliver_view_trait_change(self, ^{
        objc_setAssociatedObject(self, &revenant_style_key, @(overrideUserInterfaceStyle), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    });
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
    revenant_menus_say_once(@"modify-animations", @"+modifyAnimationsWithRepeatCount:autoreverses:animations: on iOS 6 sets the repeat count and autoreverse of the whole enclosing animation block, since the release cannot scope them to the animations inside");
    [UIView setAnimationRepeatCount:(float)count];
    [UIView setAnimationRepeatAutoreverses:autoreverses];
    animations();
}

@end
