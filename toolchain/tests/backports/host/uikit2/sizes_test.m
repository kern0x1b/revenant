#import <UIKit/UIKit.h>
#import "check.h"

#define NAMED(...) ([NSString stringWithFormat:__VA_ARGS__].UTF8String)

extern UIContentSizeCategory const CharonHostUIContentSizeCategoryExtraSmall;
extern UIContentSizeCategory const CharonHostUIContentSizeCategorySmall;
extern UIContentSizeCategory const CharonHostUIContentSizeCategoryMedium;
extern UIContentSizeCategory const CharonHostUIContentSizeCategoryLarge;
extern UIContentSizeCategory const CharonHostUIContentSizeCategoryExtraLarge;
extern UIContentSizeCategory const CharonHostUIContentSizeCategoryExtraExtraLarge;
extern UIContentSizeCategory const CharonHostUIContentSizeCategoryExtraExtraExtraLarge;
extern UIContentSizeCategory const CharonHostUIContentSizeCategoryAccessibilityMedium;
extern UIContentSizeCategory const CharonHostUIContentSizeCategoryAccessibilityLarge;
extern UIContentSizeCategory const CharonHostUIContentSizeCategoryAccessibilityExtraLarge;
extern UIContentSizeCategory const CharonHostUIContentSizeCategoryAccessibilityExtraExtraLarge;
extern UIContentSizeCategory const CharonHostUIContentSizeCategoryAccessibilityExtraExtraExtraLarge;
extern UIContentSizeCategory const CharonHostUIContentSizeCategoryUnspecified;

int main(void)
{
    @autoreleasepool {
        NSArray *ours = @[CharonHostUIContentSizeCategoryExtraSmall, CharonHostUIContentSizeCategorySmall, CharonHostUIContentSizeCategoryMedium,
                          CharonHostUIContentSizeCategoryLarge, CharonHostUIContentSizeCategoryExtraLarge, CharonHostUIContentSizeCategoryExtraExtraLarge,
                          CharonHostUIContentSizeCategoryExtraExtraExtraLarge, CharonHostUIContentSizeCategoryAccessibilityMedium,
                          CharonHostUIContentSizeCategoryAccessibilityLarge, CharonHostUIContentSizeCategoryAccessibilityExtraLarge,
                          CharonHostUIContentSizeCategoryAccessibilityExtraExtraLarge, CharonHostUIContentSizeCategoryAccessibilityExtraExtraExtraLarge,
                          CharonHostUIContentSizeCategoryUnspecified];
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
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures;
}
