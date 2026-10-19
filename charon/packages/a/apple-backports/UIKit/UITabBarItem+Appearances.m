#import "CharonBarAppearance.h"

static const void *CharonStandardAppearanceKey = &CharonStandardAppearanceKey;

@implementation UITabBarItem (CharonAppearances)

- (UITabBarAppearance *)standardAppearance
{
    return charon_appearance_peek(self, CharonStandardAppearanceKey);
}

- (void)setStandardAppearance:(UITabBarAppearance *)standardAppearance
{
    charon_appearance_store_observed(self, CharonStandardAppearanceKey, standardAppearance, @selector(charon_appearanceChanged));
    charon_refresh_bars_showing(self);
}

- (void)charon_appearanceChanged
{
    charon_refresh_bars_showing(self);
}

@end
