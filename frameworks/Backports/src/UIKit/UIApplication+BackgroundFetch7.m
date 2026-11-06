#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation UIApplication (RevenantBackgroundFetch7)

- (UIBackgroundRefreshStatus)backgroundRefreshStatus
{
    return UIBackgroundRefreshStatusDenied;
}

@end
