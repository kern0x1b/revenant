#import "tail1-cases.h"

static NSString *cut(NSString *description)
{
    NSRange open = [description rangeOfString:@"; "];
    NSRange close = [description rangeOfString:@">" options:NSBackwardsSearch];
    if (open.location == NSNotFound || close.location == NSNotFound)
        return description;
    return [description substringWithRange:NSMakeRange(NSMaxRange(open), close.location - NSMaxRange(open))];
}

void tail1_run(Tail1Recorder record)
{
    UITraitCollection *empty = [UITraitCollection traitCollectionWithTraitsFromCollections:@[]];
    UITraitCollection *ltr = [UITraitCollection traitCollectionWithLayoutDirection:UITraitEnvironmentLayoutDirectionLeftToRight];
    UITraitCollection *rtl = [UITraitCollection traitCollectionWithLayoutDirection:UITraitEnvironmentLayoutDirectionRightToLeft];
    record(@"layout direction of none", [NSString stringWithFormat:@"%ld", (long)empty.layoutDirection]);
    record(@"layout direction constructed", [NSString stringWithFormat:@"%ld %ld", (long)ltr.layoutDirection, (long)rtl.layoutDirection]);
    record(@"layout direction merge", [NSString stringWithFormat:@"%ld", (long)[UITraitCollection traitCollectionWithTraitsFromCollections:@[ltr, rtl]].layoutDirection]);
    record(@"layout direction contains", [NSString stringWithFormat:@"%d %d %d", [ltr containsTraitsInCollection:ltr], [ltr containsTraitsInCollection:rtl], [ltr containsTraitsInCollection:empty]]);
    record(@"layout direction equal", [NSString stringWithFormat:@"%d %d", [ltr isEqual:[UITraitCollection traitCollectionWithLayoutDirection:UITraitEnvironmentLayoutDirectionLeftToRight]], [ltr isEqual:rtl]]);
    record(@"layout direction description", cut(rtl.description));
    UITraitCollection *srgb = [UITraitCollection traitCollectionWithDisplayGamut:UIDisplayGamutSRGB];
    UITraitCollection *p3 = [UITraitCollection traitCollectionWithDisplayGamut:UIDisplayGamutP3];
    record(@"gamut of none", [NSString stringWithFormat:@"%ld", (long)empty.displayGamut]);
    record(@"gamut constructed", [NSString stringWithFormat:@"%ld %ld", (long)srgb.displayGamut, (long)p3.displayGamut]);
    record(@"gamut merge", [NSString stringWithFormat:@"%ld", (long)[UITraitCollection traitCollectionWithTraitsFromCollections:@[p3, srgb]].displayGamut]);
    record(@"gamut contains", [NSString stringWithFormat:@"%d %d", [p3 containsTraitsInCollection:p3], [p3 containsTraitsInCollection:srgb]]);
    record(@"gamut description", cut(p3.description));
    NSArray *categories = @[UIContentSizeCategoryExtraSmall, UIContentSizeCategoryLarge, UIContentSizeCategoryExtraExtraExtraLarge, UIContentSizeCategoryAccessibilityMedium, UIContentSizeCategoryAccessibilityExtraExtraExtraLarge, UIContentSizeCategoryUnspecified];
    NSMutableArray *read = [NSMutableArray array];
    for (NSString *category in categories)
        [read addObject:[UITraitCollection traitCollectionWithPreferredContentSizeCategory:category].preferredContentSizeCategory];
    record(@"category constructed", [read componentsJoinedByString:@","]);
    record(@"category of none", empty.preferredContentSizeCategory);
    UITraitCollection *large = [UITraitCollection traitCollectionWithPreferredContentSizeCategory:UIContentSizeCategoryLarge];
    UITraitCollection *xl = [UITraitCollection traitCollectionWithPreferredContentSizeCategory:UIContentSizeCategoryExtraLarge];
    record(@"category merge", [UITraitCollection traitCollectionWithTraitsFromCollections:@[large, xl]].preferredContentSizeCategory);
    record(@"category contains", [NSString stringWithFormat:@"%d %d %d", [large containsTraitsInCollection:large], [large containsTraitsInCollection:xl], [large containsTraitsInCollection:empty]]);
    record(@"category equal", [NSString stringWithFormat:@"%d %d", [large isEqual:[UITraitCollection traitCollectionWithPreferredContentSizeCategory:UIContentSizeCategoryLarge]], [large isEqual:xl]]);
    record(@"category description", cut(large.description));
    record(@"traits combined", cut([UITraitCollection traitCollectionWithTraitsFromCollections:@[ltr, p3, large, [UITraitCollection traitCollectionWithDisplayScale:2]]].description));
    NSMutableArray *coded = [NSMutableArray array];
    for (UITraitCollection *traits in @[rtl, p3, xl]) {
        UITraitCollection *back = [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:traits]];
        [coded addObject:[NSString stringWithFormat:@"%d", [back isEqual:traits]]];
    }
    record(@"coding round trip", [coded componentsJoinedByString:@" "]);

    UIFont *digits = [UIFont monospacedDigitSystemFontOfSize:17 weight:UIFontWeightRegular];
    record(@"digit font size", [NSString stringWithFormat:@"%g", digits.pointSize]);
    CGFloat first = 0;
    BOOL same = YES;
    for (int digit = 0; digit < 10; digit++) {
        CGFloat width = [[NSString stringWithFormat:@"%d", digit] sizeWithAttributes:@{NSFontAttributeName: digits}].width;
        if (digit == 0)
            first = width;
        else if (fabs(width - first) > 0.01)
            same = NO;
    }
    record(@"digits are one width", [NSString stringWithFormat:@"%d", same]);
    UIFont *heavy = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightBold];
    record(@"digit font weights", [NSString stringWithFormat:@"%g %d", heavy.pointSize, [heavy.fontName rangeOfString:@"Bold" options:NSCaseInsensitiveSearch].location != NSNotFound || [heavy.fontName rangeOfString:@"Heavy" options:NSCaseInsensitiveSearch].location != NSNotFound]);

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US"];
    NSMutableArray *formats = [NSMutableArray array];
    for (NSString *template in @[@"yMMMd", @"yMMMMd", @"Hm", @"MMMd", @"yMd"]) {
        [formatter setLocalizedDateFormatFromTemplate:template];
        [formats addObject:formatter.dateFormat ?: @"nil"];
    }
    record(@"date format templates en", [formats componentsJoinedByString:@" | "]);
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"de_DE"];
    [formatter setLocalizedDateFormatFromTemplate:@"yMMMd"];
    NSString *german = formatter.dateFormat;
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"ja_JP"];
    [formatter setLocalizedDateFormatFromTemplate:@"yMMMd"];
    record(@"date format templates other", [NSString stringWithFormat:@"%@ | %@", german, formatter.dateFormat]);
}
