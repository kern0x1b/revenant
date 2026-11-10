#import <UIKit/UIKit.h>

void revenant_feedback_play(float intensity, const int *milliseconds, NSUInteger count);

@interface UIFeedbackGenerator (RevenantFeedback)
- (void)_revenantPlayIntensity:(float)intensity milliseconds:(const int *)milliseconds count:(NSUInteger)count;
@end
