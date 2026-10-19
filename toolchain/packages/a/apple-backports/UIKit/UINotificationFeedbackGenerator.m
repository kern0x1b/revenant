#import "RevenantFeedbackGenerator.h"

@implementation UINotificationFeedbackGenerator

- (void)notificationOccurred:(UINotificationFeedbackType)type
{
    static const int success[] = {55, 90, 55};
    static const int warning[] = {55, 90, 110};
    static const int error[] = {70, 70, 70, 70, 70};
    switch (type) {
        case UINotificationFeedbackTypeSuccess:
            [self _revenantPlayIntensity:0.55f milliseconds:success count:3];
            break;
        case UINotificationFeedbackTypeWarning:
            [self _revenantPlayIntensity:0.75f milliseconds:warning count:3];
            break;
        case UINotificationFeedbackTypeError:
            [self _revenantPlayIntensity:1.00f milliseconds:error count:5];
            break;
    }
}

@end
