#import "RevenantBarAppearance.h"

static const void *RevenantStandardAppearanceKey = &RevenantStandardAppearanceKey;

@implementation UITabBarItem (RevenantAppearances)

- (UITabBarAppearance *)standardAppearance
{
    return revenant_appearance_peek(self, RevenantStandardAppearanceKey);
}

- (void)setStandardAppearance:(UITabBarAppearance *)standardAppearance
{
    revenant_appearance_store_observed(self, RevenantStandardAppearanceKey, standardAppearance, @selector(revenant_appearanceChanged));
    revenant_refresh_bars_showing(self);
}

- (void)revenant_appearanceChanged
{
    revenant_refresh_bars_showing(self);
}

@end
