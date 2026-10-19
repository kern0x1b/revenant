#import "CharonMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

static const char charon_menu_key, charon_role_key;

// As UIControl's: the three messages of UIContextMenuInteractionDelegate are carried here, so the
// conformance is declared and the interaction has a conformer to send them to.
@interface UIButton (CharonActions14) <UIContextMenuInteractionDelegate>
@end

@implementation UIButton (CharonActions14)

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
    return objc_getAssociatedObject(self, &charon_menu_key);
}

- (void)setMenu:(UIMenu *)menu
{
    objc_setAssociatedObject(self, &charon_menu_key, [menu copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    // Spelled as the send it is. A property write names ONE identifier and needs two accessors, so
    // tests/backports/host/prefix_selectors.py cannot prefix it and refuses the rewrite instead
    // ("a carried selector the rewrite cannot rename: a write to contextMenuInteractionEnabled through dot
    // syntax"), which took controlactions and controlmenus off the prefixed path altogether. The compiler
    // turns this line into exactly the message send below, so nothing about the port's behaviour moves.
    [self setContextMenuInteractionEnabled:menu != nil];
}

- (UIButtonRole)role
{
    return (UIButtonRole)[objc_getAssociatedObject(self, &charon_role_key) integerValue];
}

- (void)setRole:(UIButtonRole)role
{
    if (role != UIButtonRoleNormal)
        charon_menus_say_once(@"button-role", @"UIButton.role: iOS 6 draws every button the same whatever its role, so the role is kept and read back");
    objc_setAssociatedObject(self, &charon_role_key, @(role), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIContextMenuConfiguration *)contextMenuInteraction:(UIContextMenuInteraction *)interaction configurationForMenuAtLocation:(CGPoint)location
{
    __weak UIButton *button = self;
    return [UIContextMenuConfiguration configurationWithIdentifier:nil previewProvider:nil actionProvider:^UIMenu *(NSArray<UIMenuElement *> *suggested) {
        return button.menu;
    }];
}

@end
