#import "RevenantMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char RevenantTabPositioningKey;
static const char RevenantTabWidthKey;
static const char RevenantTabSpacingKey;
static const char RevenantTabBarStyleKey;
static const char RevenantTabTranslucentKey;

static void revenant_report_tab_layout(NSString *name)
{
    revenant_menus_say_once(@"tabbar-layout", [NSString stringWithFormat:@"UITabBar.%@: the iOS 6 tab bar lays out and draws its own items, so the value is kept and read back and the bar is drawn as before", name]);
}

@implementation UITabBar (RevenantLayout7)

- (UITabBarItemPositioning)itemPositioning
{
    return (UITabBarItemPositioning)[objc_getAssociatedObject(self, &RevenantTabPositioningKey) integerValue];
}

- (void)setItemPositioning:(UITabBarItemPositioning)itemPositioning
{
    revenant_report_tab_layout(@"itemPositioning");
    objc_setAssociatedObject(self, &RevenantTabPositioningKey, @(itemPositioning), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CGFloat)itemWidth
{
    return [objc_getAssociatedObject(self, &RevenantTabWidthKey) doubleValue];
}

- (void)setItemWidth:(CGFloat)itemWidth
{
    revenant_report_tab_layout(@"itemWidth");
    objc_setAssociatedObject(self, &RevenantTabWidthKey, @(itemWidth), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CGFloat)itemSpacing
{
    return [objc_getAssociatedObject(self, &RevenantTabSpacingKey) doubleValue];
}

- (void)setItemSpacing:(CGFloat)itemSpacing
{
    revenant_report_tab_layout(@"itemSpacing");
    objc_setAssociatedObject(self, &RevenantTabSpacingKey, @(itemSpacing), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIBarStyle)barStyle
{
    return (UIBarStyle)[objc_getAssociatedObject(self, &RevenantTabBarStyleKey) integerValue];
}

- (void)setBarStyle:(UIBarStyle)barStyle
{
    revenant_report_tab_layout(@"barStyle");
    objc_setAssociatedObject(self, &RevenantTabBarStyleKey, @(barStyle), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isTranslucent
{
    return [objc_getAssociatedObject(self, &RevenantTabTranslucentKey) boolValue];
}

- (void)setTranslucent:(BOOL)translucent
{
    revenant_report_tab_layout(@"translucent");
    objc_setAssociatedObject(self, &RevenantTabTranslucentKey, @(translucent), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)translucent
{
    return self.isTranslucent;
}

@end
