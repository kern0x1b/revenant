#import <UIKit/UIKit.h>
#import "check.h"

#define NAMED(...) ([NSString stringWithFormat:__VA_ARGS__].UTF8String)

extern UIContentSizeCategory const RevenantHostUIContentSizeCategoryExtraSmall;
extern UIContentSizeCategory const RevenantHostUIContentSizeCategorySmall;
extern UIContentSizeCategory const RevenantHostUIContentSizeCategoryMedium;
extern UIContentSizeCategory const RevenantHostUIContentSizeCategoryLarge;
extern UIContentSizeCategory const RevenantHostUIContentSizeCategoryExtraLarge;
extern UIContentSizeCategory const RevenantHostUIContentSizeCategoryExtraExtraLarge;
extern UIContentSizeCategory const RevenantHostUIContentSizeCategoryExtraExtraExtraLarge;
extern UIContentSizeCategory const RevenantHostUIContentSizeCategoryAccessibilityMedium;
extern UIContentSizeCategory const RevenantHostUIContentSizeCategoryAccessibilityLarge;
extern UIContentSizeCategory const RevenantHostUIContentSizeCategoryAccessibilityExtraLarge;
extern UIContentSizeCategory const RevenantHostUIContentSizeCategoryAccessibilityExtraExtraLarge;
extern UIContentSizeCategory const RevenantHostUIContentSizeCategoryAccessibilityExtraExtraExtraLarge;
extern UIContentSizeCategory const RevenantHostUIContentSizeCategoryUnspecified;

int main(void)
{
    @autoreleasepool {
        NSArray *ours = @[RevenantHostUIContentSizeCategoryExtraSmall, RevenantHostUIContentSizeCategorySmall, RevenantHostUIContentSizeCategoryMedium,
                          RevenantHostUIContentSizeCategoryLarge, RevenantHostUIContentSizeCategoryExtraLarge, RevenantHostUIContentSizeCategoryExtraExtraLarge,
                          RevenantHostUIContentSizeCategoryExtraExtraExtraLarge, RevenantHostUIContentSizeCategoryAccessibilityMedium,
                          RevenantHostUIContentSizeCategoryAccessibilityLarge, RevenantHostUIContentSizeCategoryAccessibilityExtraLarge,
                          RevenantHostUIContentSizeCategoryAccessibilityExtraExtraLarge, RevenantHostUIContentSizeCategoryAccessibilityExtraExtraExtraLarge,
                          RevenantHostUIContentSizeCategoryUnspecified];
        NSArray *system = @[UIContentSizeCategoryExtraSmall, UIContentSizeCategorySmall, UIContentSizeCategoryMedium,
                            UIContentSizeCategoryLarge, UIContentSizeCategoryExtraLarge, UIContentSizeCategoryExtraExtraLarge,
                            UIContentSizeCategoryExtraExtraExtraLarge, UIContentSizeCategoryAccessibilityMedium,
                            UIContentSizeCategoryAccessibilityLarge, UIContentSizeCategoryAccessibilityExtraLarge,
                            UIContentSizeCategoryAccessibilityExtraExtraLarge, UIContentSizeCategoryAccessibilityExtraExtraExtraLarge,
                            UIContentSizeCategoryUnspecified];
        for (NSUInteger index = 0; index < system.count; index++)
            CHECK_EQUAL(ours[index], system[index], NAMED(@"the content size category %@ is the string the system holds", system[index]));
        NSMutableSet *distinct = [NSMutableSet setWithArray:ours];
        CHECK(distinct.count == ours.count, "no two categories share a string");
        printf("checks=%d failures=%d\n", revenant_checks, revenant_failures);
    }
    return revenant_failures;
}
