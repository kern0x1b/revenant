#import "CharonBarAppearance.h"

static const void *CharonStandardAppearanceKey = &CharonStandardAppearanceKey;
static const void *CharonCompactAppearanceKey = &CharonCompactAppearanceKey;
static const void *CharonScrollEdgeAppearanceKey = &CharonScrollEdgeAppearanceKey;

@implementation UINavigationItem (CharonAppearances)

- (UINavigationBarAppearance *)standardAppearance
{
    return charon_appearance_peek(self, CharonStandardAppearanceKey);
}

- (void)setStandardAppearance:(UINavigationBarAppearance *)standardAppearance
{
    charon_appearance_store_observed(self, CharonStandardAppearanceKey, standardAppearance, @selector(charon_appearanceChanged));
    charon_refresh_bars_showing(self);
}

- (UINavigationBarAppearance *)compactAppearance
{
    return charon_appearance_peek(self, CharonCompactAppearanceKey);
}

- (void)setCompactAppearance:(UINavigationBarAppearance *)compactAppearance
{
    charon_appearance_store_observed(self, CharonCompactAppearanceKey, compactAppearance, @selector(charon_appearanceChanged));
    charon_refresh_bars_showing(self);
}

- (UINavigationBarAppearance *)scrollEdgeAppearance
{
    return charon_appearance_peek(self, CharonScrollEdgeAppearanceKey);
}

- (void)setScrollEdgeAppearance:(UINavigationBarAppearance *)scrollEdgeAppearance
{
    charon_appearance_store_observed(self, CharonScrollEdgeAppearanceKey, scrollEdgeAppearance, @selector(charon_appearanceChanged));
    charon_refresh_bars_showing(self);
}

- (void)charon_appearanceChanged
{
    charon_refresh_bars_showing(self);
}

@end
