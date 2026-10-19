#import <UIKit/UIKit.h>

BOOL charon_feedback_motor_present(void);
void charon_feedback_play(float intensity, const int *milliseconds, NSUInteger count);

@interface UIFeedbackGenerator (CharonFeedback)
- (void)_charonPlayIntensity:(float)intensity milliseconds:(const int *)milliseconds count:(NSUInteger)count;
@end
