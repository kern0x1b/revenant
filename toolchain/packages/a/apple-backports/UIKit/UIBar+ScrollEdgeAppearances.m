#import "RevenantBarAppearance.h"

static const void *RevenantScrollEdgeKey = &RevenantScrollEdgeKey;
static const void *RevenantCompactScrollEdgeKey = &RevenantCompactScrollEdgeKey;

@implementation UINavigationBar (RevenantScrollEdgeAppearances)

- (UINavigationBarAppearance *)compactScrollEdgeAppearance
{
    return revenant_appearance_peek(self, RevenantCompactScrollEdgeKey);
}

- (void)setCompactScrollEdgeAppearance:(UINavigationBarAppearance *)compactScrollEdgeAppearance
{
    revenant_appearance_store_observed(self, RevenantCompactScrollEdgeKey, compactScrollEdgeAppearance, @selector(revenant_otherChanged));
    [self revenant_refreshForced:YES];
}

@end

@implementation UIToolbar (RevenantScrollEdgeAppearances)

- (UIToolbarAppearance *)scrollEdgeAppearance
{
    return revenant_appearance_peek(self, RevenantScrollEdgeKey);
}

- (void)setScrollEdgeAppearance:(UIToolbarAppearance *)scrollEdgeAppearance
{
    revenant_appearance_store_observed(self, RevenantScrollEdgeKey, scrollEdgeAppearance, @selector(revenant_otherChanged));
    [self revenant_refreshForced:YES];
}

- (UIToolbarAppearance *)compactScrollEdgeAppearance
{
    return revenant_appearance_peek(self, RevenantCompactScrollEdgeKey);
}

- (void)setCompactScrollEdgeAppearance:(UIToolbarAppearance *)compactScrollEdgeAppearance
{
    revenant_appearance_store_observed(self, RevenantCompactScrollEdgeKey, compactScrollEdgeAppearance, @selector(revenant_otherChanged));
    [self revenant_refreshForced:YES];
}

@end

@implementation UITabBar (RevenantScrollEdgeAppearances)

- (UITabBarAppearance *)scrollEdgeAppearance
{
    return revenant_appearance_peek(self, RevenantScrollEdgeKey);
}

- (void)setScrollEdgeAppearance:(UITabBarAppearance *)scrollEdgeAppearance
{
    revenant_appearance_store_observed(self, RevenantScrollEdgeKey, scrollEdgeAppearance, @selector(revenant_otherChanged));
    [self revenant_refreshForced:YES];
}

@end

@implementation UINavigationItem (RevenantScrollEdgeAppearances)

- (UINavigationBarAppearance *)compactScrollEdgeAppearance
{
    return revenant_appearance_peek(self, RevenantCompactScrollEdgeKey);
}

- (void)setCompactScrollEdgeAppearance:(UINavigationBarAppearance *)compactScrollEdgeAppearance
{
    revenant_appearance_store_observed(self, RevenantCompactScrollEdgeKey, compactScrollEdgeAppearance, @selector(revenant_appearanceChanged));
    revenant_refresh_bars_showing(self);
}

@end

@implementation UITabBarItem (RevenantScrollEdgeAppearances)

- (UITabBarAppearance *)scrollEdgeAppearance
{
    return revenant_appearance_peek(self, RevenantScrollEdgeKey);
}

- (void)setScrollEdgeAppearance:(UITabBarAppearance *)scrollEdgeAppearance
{
    revenant_appearance_store_observed(self, RevenantScrollEdgeKey, scrollEdgeAppearance, @selector(revenant_appearanceChanged));
    revenant_refresh_bars_showing(self);
}

@end
