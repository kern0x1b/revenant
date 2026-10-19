#import "CharonMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@interface UITraitCollection (CharonTraitDelivery)
+ (void)charon_deliverChangesInEnvironments:(NSArray *)environments change:(void (^)(void))change;
@end

static const char charon_style_key, charon_modal_key;

@implementation UIViewController (CharonThirteen)

- (UIUserInterfaceStyle)overrideUserInterfaceStyle
{
    return (UIUserInterfaceStyle)[objc_getAssociatedObject(self, &charon_style_key) integerValue];
}

// The override is part of the controller's trait collection, which its children and views inherit, so the change is
// delivered to the controller and everything under it. iOS 6 cannot draw the dark appearance: its controls keep their light drawing.
- (void)setOverrideUserInterfaceStyle:(UIUserInterfaceStyle)overrideUserInterfaceStyle
{
    if (overrideUserInterfaceStyle == UIUserInterfaceStyleDark)
        charon_menus_say_once(@"dark-override", @"overrideUserInterfaceStyle: iOS 6 has no dark appearance to draw, so the trait says dark and the system's controls keep their light drawing");
    [UITraitCollection charon_deliverChangesInEnvironments:@[self] change:^{
        objc_setAssociatedObject(self, &charon_style_key, @(overrideUserInterfaceStyle), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }];
}

- (BOOL)isModalInPresentation
{
    return [objc_getAssociatedObject(self, &charon_modal_key) boolValue];
}

/* Read by the sheet (UISheetPresentationController.m), which a drag or a tap on its dimming
   view then does not dismiss. */
- (void)setModalInPresentation:(BOOL)modalInPresentation
{
    objc_setAssociatedObject(self, &charon_modal_key, @(modalInPresentation), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)performsActionsWhilePresentingModally
{
    id configured = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UIViewControllerPerformsActionsWhilePresentingModally"];
    return [configured respondsToSelector:@selector(boolValue)] ? [configured boolValue] : YES;
}

@end
