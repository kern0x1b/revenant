#import <UIKit/UIKit.h>
extern BOOL CharonHostUIContentSizeCategoryIsAccessibilityCategory(UIContentSizeCategory);
extern NSComparisonResult CharonHostUIContentSizeCategoryCompareToCategory(UIContentSizeCategory, UIContentSizeCategory);
extern UIFontTextStyle const CharonHostUIFontTextStyleLargeTitle;

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
                    CharonHostUIContentSizeCategoryIsAccessibilityCategory(name) ? @"yes" : @"no");
        compare(@"accessibility of an unknown string",
                UIContentSizeCategoryIsAccessibilityCategory(@"nonsense") ? @"yes" : @"no",
                CharonHostUIContentSizeCategoryIsAccessibilityCategory(@"nonsense") ? @"yes" : @"no");
        compare(@"accessibility of nil",
                UIContentSizeCategoryIsAccessibilityCategory(nil) ? @"yes" : @"no",
                CharonHostUIContentSizeCategoryIsAccessibilityCategory(nil) ? @"yes" : @"no");

        NSMutableString *system = [NSMutableString string], *ours = [NSMutableString string];
        for (NSString *left in all)
            for (NSString *right in all) {
                [system appendFormat:@"%ld", (long)UIContentSizeCategoryCompareToCategory(left, right)];
                [ours appendFormat:@"%ld", (long)CharonHostUIContentSizeCategoryCompareToCategory(left, right)];
            }
        compare(@"every pair of categories", system, ours);

        compare(@"nil against a category",
                [NSString stringWithFormat:@"%ld", (long)UIContentSizeCategoryCompareToCategory(nil, UIContentSizeCategoryLarge)],
                [NSString stringWithFormat:@"%ld", (long)CharonHostUIContentSizeCategoryCompareToCategory(nil, UIContentSizeCategoryLarge)]);

        NSString *systemRaise = @"none", *ourRaise = @"none";
        @try { UIContentSizeCategoryCompareToCategory(@"nonsense", UIContentSizeCategoryLarge); }
        @catch (NSException *exception) { systemRaise = [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]; }
        @try { CharonHostUIContentSizeCategoryCompareToCategory(@"nonsense", UIContentSizeCategoryLarge); }
        @catch (NSException *exception) { ourRaise = [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]; }
        compare(@"an unknown string raises", systemRaise, ourRaise);

        compare(@"the large title style", UIFontTextStyleLargeTitle, CharonHostUIFontTextStyleLargeTitle);
        printf("%d of %d checks failed\n", failures, checks);
        return failures > 0;
    }
}
