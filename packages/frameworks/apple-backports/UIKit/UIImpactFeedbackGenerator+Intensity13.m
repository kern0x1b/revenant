#import "RevenantFeedbackGenerator.h"

@interface UIImpactFeedbackGenerator (RevenantIntensity)
- (void)revenant_impactScaledBy:(float)scale;
@end

@implementation UIImpactFeedbackGenerator (RevenantThirteen)

- (void)impactOccurredWithIntensity:(CGFloat)intensity
{
    [self revenant_impactScaledBy:(float)intensity];
}

@end
