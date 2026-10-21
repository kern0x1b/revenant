#import "RevenantContentSize.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const NSUInteger RevenantCategoryCount = 12;
static const NSUInteger RevenantLargeCategory = 3;

static const CGFloat *revenant_style_sizes(UIFontTextStyle style)
{
    static const CGFloat largeTitle[] = {31, 32, 33, 34, 36, 38, 40, 44, 48, 52, 56, 60};
    static const CGFloat title1[] = {25, 26, 27, 28, 30, 32, 34, 38, 43, 48, 53, 58};
    static const CGFloat title2[] = {19, 20, 21, 22, 24, 26, 28, 34, 39, 44, 50, 56};
    static const CGFloat title3[] = {17, 18, 19, 20, 22, 24, 26, 31, 37, 43, 49, 55};
    static const CGFloat headline[] = {14, 15, 16, 17, 19, 21, 23, 28, 33, 38, 44, 50};
    static const CGFloat body[] = {14, 15, 16, 17, 19, 21, 23, 28, 33, 40, 47, 53};
    static const CGFloat callout[] = {13, 14, 15, 16, 18, 20, 22, 26, 32, 38, 44, 51};
    static const CGFloat subheadline[] = {12, 13, 14, 15, 17, 19, 21, 25, 30, 36, 42, 49};
    static const CGFloat footnote[] = {12, 12, 12, 13, 15, 17, 19, 23, 27, 33, 38, 44};
    static const CGFloat caption1[] = {11, 11, 11, 12, 14, 16, 18, 22, 26, 32, 37, 43};
    static const CGFloat caption2[] = {11, 11, 11, 11, 13, 15, 17, 20, 24, 29, 34, 40};
    if ([style isEqualToString:@"UICTFontTextStyleTitle0"])
        return largeTitle;
    if ([style isEqualToString:UIFontTextStyleTitle1])
        return title1;
    if ([style isEqualToString:UIFontTextStyleTitle2])
        return title2;
    if ([style isEqualToString:UIFontTextStyleTitle3])
        return title3;
    if ([style isEqualToString:UIFontTextStyleHeadline])
        return headline;
    if ([style isEqualToString:UIFontTextStyleBody])
        return body;
    if ([style isEqualToString:UIFontTextStyleCallout])
        return callout;
    if ([style isEqualToString:UIFontTextStyleSubheadline])
        return subheadline;
    if ([style isEqualToString:UIFontTextStyleFootnote])
        return footnote;
    if ([style isEqualToString:UIFontTextStyleCaption1])
        return caption1;
    if ([style isEqualToString:UIFontTextStyleCaption2])
        return caption2;
    return NULL;
}

@implementation UIFont (RevenantTextStyles10)

+ (UIFont *)preferredFontForTextStyle:(UIFontTextStyle)style compatibleWithTraitCollection:(UITraitCollection *)traitCollection
{
    const CGFloat *sizes = style ? revenant_style_sizes(style) : NULL;
    if (!sizes)
        return nil;
    NSArray *categories = revenant_ordered_content_size_categories();
    NSUInteger index = [categories indexOfObject:traitCollection.preferredContentSizeCategory ?: @""];
    if (index == NSNotFound)
        index = [categories indexOfObject:[UIApplication sharedApplication].preferredContentSizeCategory];
    if (index == NSNotFound || index >= RevenantCategoryCount)
        index = RevenantLargeCategory;
    CGFloat size = sizes[index];
    return [style isEqualToString:UIFontTextStyleHeadline] ? [UIFont boldSystemFontOfSize:size] : [UIFont systemFontOfSize:size];
}

@end
