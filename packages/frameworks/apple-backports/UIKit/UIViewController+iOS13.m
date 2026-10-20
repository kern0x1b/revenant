#import "RevenantMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@interface UITraitCollection (RevenantTraitDelivery)
+ (void)revenant_deliverChangesInEnvironments:(NSArray *)environments change:(void (^)(void))change;
@end

static const char revenant_style_key, revenant_modal_key;

@implementation UIViewController (RevenantThirteen)

- (UIUserInterfaceStyle)overrideUserInterfaceStyle
{
    return (UIUserInterfaceStyle)[objc_getAssociatedObject(self, &revenant_style_key) integerValue];
}

- (void)setOverrideUserInterfaceStyle:(UIUserInterfaceStyle)overrideUserInterfaceStyle
{
    if (overrideUserInterfaceStyle == UIUserInterfaceStyleDark)
        revenant_menus_say_once(@"dark-override", @"overrideUserInterfaceStyle: iOS 6 has no dark appearance to draw, so the trait says dark and the system's controls keep their light drawing");
    [UITraitCollection revenant_deliverChangesInEnvironments:@[self] change:^{
        objc_setAssociatedObject(self, &revenant_style_key, @(overrideUserInterfaceStyle), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }];
}

- (BOOL)isModalInPresentation
{
    return [objc_getAssociatedObject(self, &revenant_modal_key) boolValue];
}

- (void)setModalInPresentation:(BOOL)modalInPresentation
{
    objc_setAssociatedObject(self, &revenant_modal_key, @(modalInPresentation), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)performsActionsWhilePresentingModally
{
    id configured = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UIViewControllerPerformsActionsWhilePresentingModally"];
    return [configured respondsToSelector:@selector(boolValue)] ? [configured boolValue] : YES;
}

@end
