#import <UIKit/UIKit.h>

@implementation UIApplication (RevenantBackgroundTaskName)

- (UIBackgroundTaskIdentifier)beginBackgroundTaskWithName:(NSString *)taskName expirationHandler:(void (^)(void))handler
{
    return [self beginBackgroundTaskWithExpirationHandler:handler];
}

@end
