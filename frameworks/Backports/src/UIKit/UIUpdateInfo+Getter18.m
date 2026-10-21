#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation UIUpdateInfo (RevenantGetter18)

- (BOOL)immediatePresentationExpected
{
    return [self isImmediatePresentationExpected];
}

- (BOOL)lowLatencyEventDispatchConfirmed
{
    return [self isLowLatencyEventDispatchConfirmed];
}

- (BOOL)performingLowLatencyPhases
{
    return [self isPerformingLowLatencyPhases];
}

@end
