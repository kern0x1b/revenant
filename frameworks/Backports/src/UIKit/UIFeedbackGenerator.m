#import "RevenantFeedbackGenerator.h"
#import "../RevenantVibration.h"

void revenant_feedback_play(float intensity, const int *milliseconds, NSUInteger count)
{
    RevenantVibratorPlay(intensity, milliseconds, count);
}

@implementation UIFeedbackGenerator

- (instancetype)init
{
    return [super init];
}

- (void)prepare
{
}

- (void)_revenantPlayIntensity:(float)intensity milliseconds:(const int *)milliseconds count:(NSUInteger)count
{
    revenant_feedback_play(intensity, milliseconds, count);
}

@end
