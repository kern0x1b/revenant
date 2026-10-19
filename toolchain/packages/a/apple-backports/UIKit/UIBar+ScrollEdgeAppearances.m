#import "CharonBarAppearance.h"

static const void *CharonScrollEdgeKey = &CharonScrollEdgeKey;
static const void *CharonCompactScrollEdgeKey = &CharonCompactScrollEdgeKey;

@implementation UINavigationBar (CharonScrollEdgeAppearances)

- (UINavigationBarAppearance *)compactScrollEdgeAppearance
{
    return charon_appearance_peek(self, CharonCompactScrollEdgeKey);
}

- (void)setCompactScrollEdgeAppearance:(UINavigationBarAppearance *)compactScrollEdgeAppearance
{
    charon_appearance_store_observed(self, CharonCompactScrollEdgeKey, compactScrollEdgeAppearance, @selector(charon_otherChanged));
    [self charon_refreshForced:YES];
}

@end

@implementation UIToolbar (CharonScrollEdgeAppearances)

- (UIToolbarAppearance *)scrollEdgeAppearance
{
    return charon_appearance_peek(self, CharonScrollEdgeKey);
}

- (void)setScrollEdgeAppearance:(UIToolbarAppearance *)scrollEdgeAppearance
{
    charon_appearance_store_observed(self, CharonScrollEdgeKey, scrollEdgeAppearance, @selector(charon_otherChanged));
    [self charon_refreshForced:YES];
}

- (UIToolbarAppearance *)compactScrollEdgeAppearance
{
    return charon_appearance_peek(self, CharonCompactScrollEdgeKey);
}

- (void)setCompactScrollEdgeAppearance:(UIToolbarAppearance *)compactScrollEdgeAppearance
{
    charon_appearance_store_observed(self, CharonCompactScrollEdgeKey, compactScrollEdgeAppearance, @selector(charon_otherChanged));
    [self charon_refreshForced:YES];
}

@end

@implementation UITabBar (CharonScrollEdgeAppearances)

- (UITabBarAppearance *)scrollEdgeAppearance
{
    return charon_appearance_peek(self, CharonScrollEdgeKey);
}

- (void)setScrollEdgeAppearance:(UITabBarAppearance *)scrollEdgeAppearance
{
    charon_appearance_store_observed(self, CharonScrollEdgeKey, scrollEdgeAppearance, @selector(charon_otherChanged));
    [self charon_refreshForced:YES];
}

@end

@implementation UINavigationItem (CharonScrollEdgeAppearances)

- (UINavigationBarAppearance *)compactScrollEdgeAppearance
{
    return charon_appearance_peek(self, CharonCompactScrollEdgeKey);
}

- (void)setCompactScrollEdgeAppearance:(UINavigationBarAppearance *)compactScrollEdgeAppearance
{
    charon_appearance_store_observed(self, CharonCompactScrollEdgeKey, compactScrollEdgeAppearance, @selector(charon_appearanceChanged));
    charon_refresh_bars_showing(self);
}

@end

@implementation UITabBarItem (CharonScrollEdgeAppearances)

- (UITabBarAppearance *)scrollEdgeAppearance
{
    return charon_appearance_peek(self, CharonScrollEdgeKey);
}

- (void)setScrollEdgeAppearance:(UITabBarAppearance *)scrollEdgeAppearance
{
    charon_appearance_store_observed(self, CharonScrollEdgeKey, scrollEdgeAppearance, @selector(charon_appearanceChanged));
    charon_refresh_bars_showing(self);
}

@end
