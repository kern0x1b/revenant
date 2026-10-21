#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char RevenantFetchIntervalKey;

@implementation UIApplication (RevenantBackgroundFetch7)

- (void)setMinimumBackgroundFetchInterval:(NSTimeInterval)minimumBackgroundFetchInterval
{
    objc_setAssociatedObject(self, &RevenantFetchIntervalKey, @(minimumBackgroundFetchInterval), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIBackgroundRefreshStatus)backgroundRefreshStatus
{
    return UIBackgroundRefreshStatusDenied;
}

@end
