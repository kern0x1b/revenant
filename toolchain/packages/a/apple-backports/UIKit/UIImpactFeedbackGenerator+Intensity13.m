#import "CharonFeedbackGenerator.h"

@interface UIImpactFeedbackGenerator (CharonIntensity)
- (void)charon_impactScaledBy:(float)scale;
@end

@implementation UIImpactFeedbackGenerator (CharonThirteen)

- (void)impactOccurredWithIntensity:(CGFloat)intensity
{
    [self charon_impactScaledBy:(float)intensity];
}

@end
