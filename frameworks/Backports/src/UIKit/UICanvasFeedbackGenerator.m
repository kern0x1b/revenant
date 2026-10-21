#import "RevenantFeedbackGenerator.h"

@implementation UICanvasFeedbackGenerator

- (void)alignmentOccurredAtLocation:(CGPoint)location
{
    static const int alignment[] = {20};
    [self _revenantPlayIntensity:0.45f milliseconds:alignment count:1];
}

- (void)pathCompletedAtLocation:(CGPoint)location
{
    static const int completed[] = {35};
    [self _revenantPlayIntensity:0.7f milliseconds:completed count:1];
}

@end
