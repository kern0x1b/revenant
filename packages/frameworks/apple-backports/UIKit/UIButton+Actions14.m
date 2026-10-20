#import "RevenantMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

static const char revenant_menu_key, revenant_role_key;

@interface UIButton (RevenantActions14) <UIContextMenuInteractionDelegate>
@end

@implementation UIButton (RevenantActions14)

+ (instancetype)buttonWithType:(UIButtonType)buttonType primaryAction:(UIAction *)primaryAction
{
    UIButton *button = [self buttonWithType:buttonType];
    if (primaryAction) {
        [button setTitle:primaryAction.title forState:UIControlStateNormal];
        [button setImage:primaryAction.image forState:UIControlStateNormal];
        [button addAction:primaryAction forControlEvents:UIControlEventPrimaryActionTriggered];
    }
    return button;
}

+ (instancetype)systemButtonWithPrimaryAction:(UIAction *)primaryAction
{
    return [self buttonWithType:UIButtonTypeSystem primaryAction:primaryAction];
}

- (instancetype)initWithFrame:(CGRect)frame primaryAction:(UIAction *)primaryAction
{
    if ((self = [super initWithFrame:frame primaryAction:primaryAction]) && primaryAction) {
        [self setTitle:primaryAction.title forState:UIControlStateNormal];
        [self setImage:primaryAction.image forState:UIControlStateNormal];
    }
    return self;
}

- (UIMenu *)menu
{
    return objc_getAssociatedObject(self, &revenant_menu_key);
}

- (void)setMenu:(UIMenu *)menu
{
    objc_setAssociatedObject(self, &revenant_menu_key, [menu copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self setContextMenuInteractionEnabled:menu != nil];
}

- (UIButtonRole)role
{
    return (UIButtonRole)[objc_getAssociatedObject(self, &revenant_role_key) integerValue];
}

- (void)setRole:(UIButtonRole)role
{
    if (role != UIButtonRoleNormal)
        revenant_menus_say_once(@"button-role", @"UIButton.role: iOS 6 draws every button the same whatever its role, so the role is kept and read back");
    objc_setAssociatedObject(self, &revenant_role_key, @(role), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIContextMenuConfiguration *)contextMenuInteraction:(UIContextMenuInteraction *)interaction configurationForMenuAtLocation:(CGPoint)location
{
    __weak UIButton *button = self;
    return [UIContextMenuConfiguration configurationWithIdentifier:nil previewProvider:nil actionProvider:^UIMenu *(NSArray<UIMenuElement *> *suggested) {
        return button.menu;
    }];
}

@end
