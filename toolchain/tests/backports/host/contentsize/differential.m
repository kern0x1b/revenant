#import <UIKit/UIKit.h>
extern BOOL RevenantHostUIContentSizeCategoryIsAccessibilityCategory(UIContentSizeCategory);
extern NSComparisonResult RevenantHostUIContentSizeCategoryCompareToCategory(UIContentSizeCategory, UIContentSizeCategory);
extern UIFontTextStyle const RevenantHostUIFontTextStyleLargeTitle;

static int failures, checks;
static void compare(NSString *name, NSString *system, NSString *ours)
{
    checks++;
    if ([system isEqual:ours]) { printf("ok   %s: %s\n", name.UTF8String, system.UTF8String); return; }
    failures++;
    printf("FAIL %s: the system answers %s, the backport answers %s\n", name.UTF8String, system.UTF8String, ours.UTF8String);
}

int main(void)
{
    @autoreleasepool {
        NSArray *all = @[UIContentSizeCategoryExtraSmall, UIContentSizeCategorySmall, UIContentSizeCategoryMedium,
                         UIContentSizeCategoryLarge, UIContentSizeCategoryExtraLarge, UIContentSizeCategoryExtraExtraLarge,
                         UIContentSizeCategoryExtraExtraExtraLarge, UIContentSizeCategoryAccessibilityMedium,
                         UIContentSizeCategoryAccessibilityLarge, UIContentSizeCategoryAccessibilityExtraLarge,
                         UIContentSizeCategoryAccessibilityExtraExtraLarge, UIContentSizeCategoryAccessibilityExtraExtraExtraLarge,
                         UIContentSizeCategoryUnspecified];
        for (NSString *name in all)
            compare([NSString stringWithFormat:@"accessibility of %@", name],
                    UIContentSizeCategoryIsAccessibilityCategory(name) ? @"yes" : @"no",
                    RevenantHostUIContentSizeCategoryIsAccessibilityCategory(name) ? @"yes" : @"no");
        compare(@"accessibility of an unknown string",
                UIContentSizeCategoryIsAccessibilityCategory(@"nonsense") ? @"yes" : @"no",
                RevenantHostUIContentSizeCategoryIsAccessibilityCategory(@"nonsense") ? @"yes" : @"no");
        compare(@"accessibility of nil",
                UIContentSizeCategoryIsAccessibilityCategory(nil) ? @"yes" : @"no",
                RevenantHostUIContentSizeCategoryIsAccessibilityCategory(nil) ? @"yes" : @"no");

        NSMutableString *system = [NSMutableString string], *ours = [NSMutableString string];
        for (NSString *left in all)
            for (NSString *right in all) {
                [system appendFormat:@"%ld", (long)UIContentSizeCategoryCompareToCategory(left, right)];
                [ours appendFormat:@"%ld", (long)RevenantHostUIContentSizeCategoryCompareToCategory(left, right)];
            }
        compare(@"every pair of categories", system, ours);

        compare(@"nil against a category",
                [NSString stringWithFormat:@"%ld", (long)UIContentSizeCategoryCompareToCategory(nil, UIContentSizeCategoryLarge)],
                [NSString stringWithFormat:@"%ld", (long)RevenantHostUIContentSizeCategoryCompareToCategory(nil, UIContentSizeCategoryLarge)]);

        NSString *systemRaise = @"none", *ourRaise = @"none";
        @try { UIContentSizeCategoryCompareToCategory(@"nonsense", UIContentSizeCategoryLarge); }
        @catch (NSException *exception) { systemRaise = [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]; }
        @try { RevenantHostUIContentSizeCategoryCompareToCategory(@"nonsense", UIContentSizeCategoryLarge); }
        @catch (NSException *exception) { ourRaise = [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]; }
        compare(@"an unknown string raises", systemRaise, ourRaise);

        compare(@"the large title style", UIFontTextStyleLargeTitle, RevenantHostUIFontTextStyleLargeTitle);
        printf("%d of %d checks failed\n", failures, checks);
        return failures > 0;
    }
}
