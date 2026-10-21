#import "RevenantMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char RevenantUnselectedTintKey;
static const char RevenantBadgeColorKey;
static const char RevenantBadgeAttributesKey;

@implementation UITabBar (RevenantTint10)

- (UIColor *)unselectedItemTintColor
{
    return objc_getAssociatedObject(self, &RevenantUnselectedTintKey);
}

- (void)setUnselectedItemTintColor:(UIColor *)unselectedItemTintColor
{
    if (unselectedItemTintColor)
        revenant_menus_say_once(@"tabbar-unselected", @"UITabBar.unselectedItemTintColor: the iOS 6 tab bar draws unselected items from the image's alpha in its own grey, so the colour is kept and read back and the bar is drawn as before");
    objc_setAssociatedObject(self, &RevenantUnselectedTintKey, unselectedItemTintColor, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end

@implementation UITabBarItem (RevenantBadge10)

- (UIColor *)badgeColor
{
    return objc_getAssociatedObject(self, &RevenantBadgeColorKey);
}

- (void)setBadgeColor:(UIColor *)badgeColor
{
    if (badgeColor)
        revenant_menus_say_once(@"tabbaritem-badge", @"UITabBarItem badge colour and text attributes: the iOS 6 tab bar draws its own red badge, so the values are kept and read back and the badge is drawn as before");
    objc_setAssociatedObject(self, &RevenantBadgeColorKey, badgeColor, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSDictionary<NSAttributedStringKey, id> *)badgeTextAttributesForState:(UIControlState)state
{
    return [objc_getAssociatedObject(self, &RevenantBadgeAttributesKey) objectForKey:@(state)];
}

- (void)setBadgeTextAttributes:(NSDictionary<NSAttributedStringKey, id> *)textAttributes forState:(UIControlState)state
{
    if (textAttributes)
        revenant_menus_say_once(@"tabbaritem-badge", @"UITabBarItem badge colour and text attributes: the iOS 6 tab bar draws its own red badge, so the values are kept and read back and the badge is drawn as before");
    NSMutableDictionary *stored = objc_getAssociatedObject(self, &RevenantBadgeAttributesKey);
    if (!stored && textAttributes) {
        stored = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, &RevenantBadgeAttributesKey, stored, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (textAttributes)
        stored[@(state)] = [textAttributes copy];
    else
        [stored removeObjectForKey:@(state)];
}

@end
