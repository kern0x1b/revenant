#import "CharonTraitStyle.h"

static NSString *const CharonLayoutDirection = @"UserInterfaceLayoutDirection";
static NSString *const CharonDisplayGamut = @"DisplayGamut";
static NSString *const CharonContentSize = @"PreferredContentSizeCategory";

static NSArray *charon_categories(void)
{
    return @[UIContentSizeCategoryExtraSmall, UIContentSizeCategorySmall, UIContentSizeCategoryMedium, UIContentSizeCategoryLarge, UIContentSizeCategoryExtraLarge,
             UIContentSizeCategoryExtraExtraLarge, UIContentSizeCategoryExtraExtraExtraLarge, UIContentSizeCategoryAccessibilityMedium, UIContentSizeCategoryAccessibilityLarge,
             UIContentSizeCategoryAccessibilityExtraLarge, UIContentSizeCategoryAccessibilityExtraExtraLarge, UIContentSizeCategoryAccessibilityExtraExtraExtraLarge];
}

static void charon_register_ten(void)
{
    NSString *language = [[[NSBundle mainBundle] preferredLocalizations] firstObject];
    NSInteger direction = language && [NSLocale characterDirectionForLanguage:language] == NSLocaleLanguageDirectionRightToLeft ? 1 : 0;
    charon_register_trait_kind((CharonTraitKind){CharonDisplayGamut, 0, YES, @"SRGB", @"P3"});
    charon_register_trait_kind((CharonTraitKind){CharonLayoutDirection, direction, YES, @"LTR", @"RTL"});
    charon_register_trait_kind((CharonTraitKind){CharonContentSize, 3, 2, @"XS,S,M,L,XL,XXL,XXXL,AccessibilityM,AccessibilityL,AccessibilityXL,AccessibilityXXL,AccessibilityXXXL", nil});
}

static UITraitCollection *charon_with(NSString *name, NSInteger value)
{
    charon_register_ten();
    UITraitCollection *collection = [UITraitCollection traitCollectionWithTraitsFromCollections:@[]];
    charon_set_trait_extra(collection, name, value);
    return collection;
}

@interface CharonTraitKinds10 : NSObject
@end

@implementation CharonTraitKinds10

+ (void)load
{
    charon_register_ten();
}

@end

@implementation UITraitCollection (CharonTraits10)

+ (UITraitCollection *)traitCollectionWithLayoutDirection:(UITraitEnvironmentLayoutDirection)layoutDirection
{
    return charon_with(CharonLayoutDirection, layoutDirection);
}

+ (UITraitCollection *)traitCollectionWithDisplayGamut:(UIDisplayGamut)displayGamut
{
    return charon_with(CharonDisplayGamut, displayGamut);
}

+ (UITraitCollection *)traitCollectionWithPreferredContentSizeCategory:(UIContentSizeCategory)preferredContentSizeCategory
{
    NSUInteger index = preferredContentSizeCategory ? [charon_categories() indexOfObject:preferredContentSizeCategory] : NSNotFound;
    return charon_with(CharonContentSize, index == NSNotFound ? -1 : (NSInteger)index);
}

- (UITraitEnvironmentLayoutDirection)layoutDirection
{
    return (UITraitEnvironmentLayoutDirection)charon_trait_extra(self, CharonLayoutDirection);
}

- (UIDisplayGamut)displayGamut
{
    return (UIDisplayGamut)charon_trait_extra(self, CharonDisplayGamut);
}

- (UIContentSizeCategory)preferredContentSizeCategory
{
    NSInteger index = charon_trait_extra(self, CharonContentSize);
    NSArray *categories = charon_categories();
    return index >= 0 && index < (NSInteger)categories.count ? categories[index] : UIContentSizeCategoryUnspecified;
}

@end
