#import "RevenantMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

static const char revenant_menu_key, revenant_role_key;

static UIColor *revenant_role_red(void)
{
    return [UIColor colorWithRed:1.0 green:59.0 / 255.0 blue:48.0 / 255.0 alpha:1.0];
}

static UIColor *revenant_role_blue(void)
{
    return [UIColor colorWithRed:0.0 green:122.0 / 255.0 blue:1.0 alpha:1.0];
}

static UIImage *revenant_role_fill(UIColor *color)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(9, 9), NO, 0);
    [color setFill];
    [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, 9, 9) cornerRadius:4.5] fill];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [image resizableImageWithCapInsets:UIEdgeInsetsMake(4, 4, 4, 4)];
}

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
    objc_setAssociatedObject(self, &revenant_role_key, @(role), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    CGFloat size = self.titleLabel.font.pointSize ?: 17;
    switch (role) {
        case UIButtonRolePrimary:
            [self setBackgroundImage:revenant_role_fill(revenant_role_blue()) forState:UIControlStateNormal];
            [self setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            self.titleLabel.font = [UIFont boldSystemFontOfSize:size];
            break;
        case UIButtonRoleDestructive:
            [self setBackgroundImage:nil forState:UIControlStateNormal];
            [self setTitleColor:revenant_role_red() forState:UIControlStateNormal];
            self.titleLabel.font = [UIFont systemFontOfSize:size];
            break;
        case UIButtonRoleCancel:
            [self setBackgroundImage:nil forState:UIControlStateNormal];
            [self setTitleColor:nil forState:UIControlStateNormal];
            self.titleLabel.font = [UIFont boldSystemFontOfSize:size];
            break;
        case UIButtonRoleNormal:
        default:
            [self setBackgroundImage:nil forState:UIControlStateNormal];
            [self setTitleColor:nil forState:UIControlStateNormal];
            self.titleLabel.font = [UIFont systemFontOfSize:size];
            break;
    }
}

- (UIContextMenuConfiguration *)contextMenuInteraction:(UIContextMenuInteraction *)interaction configurationForMenuAtLocation:(CGPoint)location
{
    __weak UIButton *button = self;
    return [UIContextMenuConfiguration configurationWithIdentifier:nil previewProvider:nil actionProvider:^UIMenu *(NSArray<UIMenuElement *> *suggested) {
        return button.menu;
    }];
}

@end
