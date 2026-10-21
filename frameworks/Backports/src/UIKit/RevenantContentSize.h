#import <UIKit/UIKit.h>

static inline NSArray<UIContentSizeCategory> *revenant_ordered_content_size_categories(void)
{
    return @[UIContentSizeCategoryExtraSmall, UIContentSizeCategorySmall, UIContentSizeCategoryMedium, UIContentSizeCategoryLarge,
             UIContentSizeCategoryExtraLarge, UIContentSizeCategoryExtraExtraLarge, UIContentSizeCategoryExtraExtraExtraLarge,
             UIContentSizeCategoryAccessibilityMedium, UIContentSizeCategoryAccessibilityLarge, UIContentSizeCategoryAccessibilityExtraLarge,
             UIContentSizeCategoryAccessibilityExtraExtraLarge, UIContentSizeCategoryAccessibilityExtraExtraExtraLarge];
}
