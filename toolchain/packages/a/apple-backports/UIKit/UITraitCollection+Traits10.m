#import "RevenantTraitStyle.h"

static NSString *const RevenantLayoutDirection = @"UserInterfaceLayoutDirection";
static NSString *const RevenantDisplayGamut = @"DisplayGamut";
static NSString *const RevenantContentSize = @"PreferredContentSizeCategory";

static NSArray *revenant_categories(void)
{
    return @[UIContentSizeCategoryExtraSmall, UIContentSizeCategorySmall, UIContentSizeCategoryMedium, UIContentSizeCategoryLarge, UIContentSizeCategoryExtraLarge,
             UIContentSizeCategoryExtraExtraLarge, UIContentSizeCategoryExtraExtraExtraLarge, UIContentSizeCategoryAccessibilityMedium, UIContentSizeCategoryAccessibilityLarge,
             UIContentSizeCategoryAccessibilityExtraLarge, UIContentSizeCategoryAccessibilityExtraExtraLarge, UIContentSizeCategoryAccessibilityExtraExtraExtraLarge];
}

static void revenant_register_ten(void)
{
    NSString *language = [[[NSBundle mainBundle] preferredLocalizations] firstObject];
    NSInteger direction = language && [NSLocale characterDirectionForLanguage:language] == NSLocaleLanguageDirectionRightToLeft ? 1 : 0;
    revenant_register_trait_kind((RevenantTraitKind){RevenantDisplayGamut, 0, YES, @"SRGB", @"P3"});
    revenant_register_trait_kind((RevenantTraitKind){RevenantLayoutDirection, direction, YES, @"LTR", @"RTL"});
    revenant_register_trait_kind((RevenantTraitKind){RevenantContentSize, 3, 2, @"XS,S,M,L,XL,XXL,XXXL,AccessibilityM,AccessibilityL,AccessibilityXL,AccessibilityXXL,AccessibilityXXXL", nil});
}

static UITraitCollection *revenant_with(NSString *name, NSInteger value)
{
    revenant_register_ten();
    UITraitCollection *collection = [UITraitCollection traitCollectionWithTraitsFromCollections:@[]];
    revenant_set_trait_extra(collection, name, value);
    return collection;
}

@interface RevenantTraitKinds10 : NSObject
@end

@implementation RevenantTraitKinds10

+ (void)load
{
    revenant_register_ten();
}

@end

@implementation UITraitCollection (RevenantTraits10)

+ (UITraitCollection *)traitCollectionWithLayoutDirection:(UITraitEnvironmentLayoutDirection)layoutDirection
{
    return revenant_with(RevenantLayoutDirection, layoutDirection);
}

+ (UITraitCollection *)traitCollectionWithDisplayGamut:(UIDisplayGamut)displayGamut
{
    return revenant_with(RevenantDisplayGamut, displayGamut);
}

+ (UITraitCollection *)traitCollectionWithPreferredContentSizeCategory:(UIContentSizeCategory)preferredContentSizeCategory
{
    NSUInteger index = preferredContentSizeCategory ? [revenant_categories() indexOfObject:preferredContentSizeCategory] : NSNotFound;
    return revenant_with(RevenantContentSize, index == NSNotFound ? -1 : (NSInteger)index);
}

- (UITraitEnvironmentLayoutDirection)layoutDirection
{
    return (UITraitEnvironmentLayoutDirection)revenant_trait_extra(self, RevenantLayoutDirection);
}

- (UIDisplayGamut)displayGamut
{
    return (UIDisplayGamut)revenant_trait_extra(self, RevenantDisplayGamut);
}

- (UIContentSizeCategory)preferredContentSizeCategory
{
    NSInteger index = revenant_trait_extra(self, RevenantContentSize);
    NSArray *categories = revenant_categories();
    return index >= 0 && index < (NSInteger)categories.count ? categories[index] : UIContentSizeCategoryUnspecified;
}

@end
