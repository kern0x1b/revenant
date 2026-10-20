#import <UIKit/UIKit.h>

BOOL revenant_feedback_motor_present(void);
void revenant_feedback_play(float intensity, const int *milliseconds, NSUInteger count);

@interface UIFeedbackGenerator (RevenantFeedback)
- (void)_revenantPlayIntensity:(float)intensity milliseconds:(const int *)milliseconds count:(NSUInteger)count;
@end
