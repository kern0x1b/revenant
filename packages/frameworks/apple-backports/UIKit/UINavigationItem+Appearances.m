#import "RevenantBarAppearance.h"

static const void *RevenantStandardAppearanceKey = &RevenantStandardAppearanceKey;
static const void *RevenantCompactAppearanceKey = &RevenantCompactAppearanceKey;
static const void *RevenantScrollEdgeAppearanceKey = &RevenantScrollEdgeAppearanceKey;

@implementation UINavigationItem (RevenantAppearances)

- (UINavigationBarAppearance *)standardAppearance
{
    return revenant_appearance_peek(self, RevenantStandardAppearanceKey);
}

- (void)setStandardAppearance:(UINavigationBarAppearance *)standardAppearance
{
    revenant_appearance_store_observed(self, RevenantStandardAppearanceKey, standardAppearance, @selector(revenant_appearanceChanged));
    revenant_refresh_bars_showing(self);
}

- (UINavigationBarAppearance *)compactAppearance
{
    return revenant_appearance_peek(self, RevenantCompactAppearanceKey);
}

- (void)setCompactAppearance:(UINavigationBarAppearance *)compactAppearance
{
    revenant_appearance_store_observed(self, RevenantCompactAppearanceKey, compactAppearance, @selector(revenant_appearanceChanged));
    revenant_refresh_bars_showing(self);
}

- (UINavigationBarAppearance *)scrollEdgeAppearance
{
    return revenant_appearance_peek(self, RevenantScrollEdgeAppearanceKey);
}

- (void)setScrollEdgeAppearance:(UINavigationBarAppearance *)scrollEdgeAppearance
{
    revenant_appearance_store_observed(self, RevenantScrollEdgeAppearanceKey, scrollEdgeAppearance, @selector(revenant_appearanceChanged));
    revenant_refresh_bars_showing(self);
}

- (void)revenant_appearanceChanged
{
    revenant_refresh_bars_showing(self);
}

@end
