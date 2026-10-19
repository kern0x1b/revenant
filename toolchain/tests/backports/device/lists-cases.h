#import <UIKit/UIKit.h>

typedef struct {
    const char *factory;
    int text, secondary, image;
    int accessories[3];
    int editing, indentation;
    double width, height;
} ListCase;

static const ListCase list_cases[] = {
    {"cellConfiguration", 1, 0, 0, {-1, -1, -1}, 0, 0, 320, 60},
    {"cellConfiguration", 1, 1, 1, {1, -1, -1}, 0, 0, 320, 80},
    {"cellConfiguration", 1, 0, 1, {0, 1, -1}, 0, 0, 320, 60},
    {"valueCellConfiguration", 1, 1, 0, {-1, -1, -1}, 0, 0, 320, 60},
    {"subtitleCellConfiguration", 1, 1, 1, {-1, -1, -1}, 0, 0, 320, 70},
    {"sidebarCellConfiguration", 1, 0, 1, {6, -1, -1}, 0, 0, 320, 56},
    {"cellConfiguration", 1, 0, 0, {2, 3, -1}, 1, 0, 320, 60},
    {"cellConfiguration", 1, 0, 0, {4, 0, -1}, 1, 0, 320, 60},
    {"cellConfiguration", 1, 1, 0, {8, 9, -1}, 0, 2, 260, 70},
    {"valueCellConfiguration", 1, 1, 1, {5, -1, -1}, 1, 1, 375, 64},
    {"cellConfiguration", 0, 0, 1, {1, -1, -1}, 0, 0, 200, 50},
    {"subtitleCellConfiguration", 1, 1, 0, {9, 1, -1}, 0, 0, 240, 60},
    {"sidebarCellConfiguration", 1, 1, 1, {0, -1, -1}, 0, 3, 300, 90},
    {"cellConfiguration", 1, 0, 0, {2, 4, 1}, 1, 0, 320, 44},
};

static const char *const list_accessory_names[] = {"UICellAccessoryCheckmark", "UICellAccessoryDisclosureIndicator", "UICellAccessoryDelete", "UICellAccessoryInsert", "UICellAccessoryReorder",
                                                    "UICellAccessoryMultiselect", "UICellAccessoryOutlineDisclosure", "UICellAccessoryLabel", "custom-trailing", "custom-leading"};

static inline size_t list_case_count(void)
{
    return sizeof list_cases / sizeof list_cases[0];
}

static inline NSString *list_value_line(NSString *name, UIListContentConfiguration *c)
{
    return [NSString stringWithFormat:@"%@ margins=%@ axes=%ld side=%d i2t=%g h=%g v=%g text=%g/%ld/%d/%g/%d sec=%g/%ld/%d/%g/%d", name, NSStringFromDirectionalEdgeInsets(c.directionalLayoutMargins), (long)c.axesPreservingSuperviewLayoutMargins,
            c.prefersSideBySideTextAndSecondaryText, c.imageToTextPadding, c.textToSecondaryTextHorizontalPadding, c.textToSecondaryTextVerticalPadding, c.textProperties.font.pointSize, (long)c.textProperties.numberOfLines,
            c.textProperties.adjustsFontSizeToFitWidth, c.textProperties.minimumScaleFactor, c.textProperties.allowsDefaultTighteningForTruncation, c.secondaryTextProperties.font.pointSize, (long)c.secondaryTextProperties.numberOfLines,
            c.secondaryTextProperties.adjustsFontSizeToFitWidth, c.secondaryTextProperties.minimumScaleFactor, c.secondaryTextProperties.allowsDefaultTighteningForTruncation];
}

static inline NSString *list_background_line(NSString *name, UIBackgroundConfiguration *b)
{
    return [NSString stringWithFormat:@"%@ corner=%g insets=%@ edges=%lu stroke=%g/%g", name, b.cornerRadius, NSStringFromDirectionalEdgeInsets(b.backgroundInsets), (unsigned long)b.edgesAddingLayoutMarginsToBackgroundInsets, b.strokeWidth, b.strokeOutset];
}

static inline NSString *list_dimension_text(NSCollectionLayoutDimension *dimension)
{
    return [NSString stringWithFormat:@"%@%g", dimension.isFractionalWidth ? @"fw" : dimension.isFractionalHeight ? @"fh" : dimension.isAbsolute ? @"abs" : @"est", dimension.dimension];
}

static inline NSString *list_section_text(NSCollectionLayoutSection *section)
{
    NSMutableString *text = [NSMutableString stringWithFormat:@"insets=%@ ref=%ld", NSStringFromDirectionalEdgeInsets(section.contentInsets), (long)section.contentInsetsReference];
    for (NSCollectionLayoutBoundarySupplementaryItem *item in section.boundarySupplementaryItems)
        [text appendFormat:@" [%@ %@ %@ align=%ld ext=%d pin=%d z=%ld]", item.elementKind, list_dimension_text(item.layoutSize.widthDimension), list_dimension_text(item.layoutSize.heightDimension), (long)item.alignment, item.extendsBoundary, item.pinToVisibleBounds,
                (long)item.zIndex];
    return text;
}

static inline NSArray *list_numbers(NSString *text)
{
    NSMutableArray *numbers = [NSMutableArray array];
    NSRegularExpression *pattern = [NSRegularExpression regularExpressionWithPattern:@"-?[0-9]+(\\.[0-9]+)?" options:0 error:NULL];
    for (NSTextCheckingResult *match in [pattern matchesInString:text options:0 range:NSMakeRange(0, text.length)])
        [numbers addObject:@([[text substringWithRange:match.range] doubleValue])];
    return numbers;
}

static inline BOOL list_text_agrees(NSString *actual, NSString *expected, double tolerance)
{
    NSRegularExpression *pattern = [NSRegularExpression regularExpressionWithPattern:@"-?[0-9]+(\\.[0-9]+)?" options:0 error:NULL];
    NSString *a = [pattern stringByReplacingMatchesInString:actual options:0 range:NSMakeRange(0, actual.length) withTemplate:@"#"];
    NSString *b = [pattern stringByReplacingMatchesInString:expected options:0 range:NSMakeRange(0, expected.length) withTemplate:@"#"];
    NSArray *x = list_numbers(actual), *y = list_numbers(expected);
    if (![a isEqualToString:b] || x.count != y.count)
        return NO;
    for (NSUInteger index = 0; index < x.count; index++)
        if (fabs([x[index] doubleValue] - [y[index] doubleValue]) > tolerance)
            return NO;
    return YES;
}
