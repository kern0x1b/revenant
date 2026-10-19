#import <UIKit/UIKit.h>

/* Prints what the host's own sheet metrics (+[_UISheetPresentationMetrics _defaultMetrics], Mac Catalyst) answer, one
   "name value" line each. A probe of the oracle, not the product: it asks the host's private class by name. */
static double number(id object, NSString *name)
{
    SEL selector = NSSelectorFromString(name);
    return ((double (*)(id, SEL))[object methodForSelector:selector])(object, selector);
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        Class metricsClass = NSClassFromString(@"_UISheetPresentationMetrics");
        if (!metricsClass) {
            printf("FAIL the host has no _UISheetPresentationMetrics\n");
            return 1;
        }
        id metrics = [metricsClass performSelector:@selector(_defaultMetrics)];
        for (NSString *name in @[@"topOffset", @"topOffsetInCompactHeight", @"cornerRadius", @"maximumSheetDepthLevel", @"transitionDuration", @"shadowRadius", @"preferredShadowOpacity"])
            printf("%s %g\n", name.UTF8String, number(metrics, name));
        for (NSNumber *fast in @[@NO, @YES]) {
            id spring = ((id (*)(id, SEL, BOOL))[metrics methodForSelector:@selector(transitionSpringParametersHighSpeed:)])(metrics, @selector(transitionSpringParametersHighSpeed:), fast.boolValue);
            printf("spring%s.response %.10g\nspring%s.damping %g\n", fast.boolValue ? "Fast" : "", number(spring, @"_response"), fast.boolValue ? "Fast" : "", number(spring, @"_dampingRatio"));
        }
    }
    return 0;
}
