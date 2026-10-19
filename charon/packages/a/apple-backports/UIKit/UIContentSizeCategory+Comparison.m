#import <UIKit/UIKit.h>

static NSArray *charon_content_size_categories(void)
{
    static NSArray *ordered;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        ordered = @[UIContentSizeCategoryExtraSmall, UIContentSizeCategorySmall, UIContentSizeCategoryMedium,
                    UIContentSizeCategoryLarge, UIContentSizeCategoryExtraLarge, UIContentSizeCategoryExtraExtraLarge,
                    UIContentSizeCategoryExtraExtraExtraLarge, UIContentSizeCategoryAccessibilityMedium,
                    UIContentSizeCategoryAccessibilityLarge, UIContentSizeCategoryAccessibilityExtraLarge,
                    UIContentSizeCategoryAccessibilityExtraExtraLarge, UIContentSizeCategoryAccessibilityExtraExtraExtraLarge];
    });
    return ordered;
}

BOOL UIContentSizeCategoryIsAccessibilityCategory(UIContentSizeCategory category)
{
    return [category hasPrefix:@"UICTContentSizeCategoryAccessibility"];
}

NSComparisonResult UIContentSizeCategoryCompareToCategory(UIContentSizeCategory lhs, UIContentSizeCategory rhs)
{
    NSArray *ordered = charon_content_size_categories();
    NSUInteger left = lhs ? [ordered indexOfObject:lhs] : NSNotFound;
    NSUInteger right = rhs ? [ordered indexOfObject:rhs] : NSNotFound;
    BOOL leftUnspecified = !lhs || [lhs isEqualToString:UIContentSizeCategoryUnspecified];
    BOOL rightUnspecified = !rhs || [rhs isEqualToString:UIContentSizeCategoryUnspecified];
    if ((left == NSNotFound && !leftUnspecified) || (right == NSNotFound && !rightUnspecified))
        [NSException raise:NSInternalInconsistencyException
                    format:@"UIContentSizeCategoryCompareToCategory cannot be used to order arbitrary strings, only UIContentSizeCategory objects (comparing %@ to %@).",
                           lhs, rhs];
    if (leftUnspecified && rightUnspecified)
        return NSOrderedSame;
    if (leftUnspecified)
        return NSOrderedAscending;
    if (rightUnspecified)
        return NSOrderedDescending;
    if (left == right)
        return NSOrderedSame;
    return left < right ? NSOrderedAscending : NSOrderedDescending;
}
