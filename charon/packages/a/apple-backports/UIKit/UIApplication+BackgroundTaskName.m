#import <UIKit/UIKit.h>

@implementation UIApplication (CharonBackgroundTaskName)

- (UIBackgroundTaskIdentifier)beginBackgroundTaskWithName:(NSString *)taskName expirationHandler:(void (^)(void))handler
{
    return [self beginBackgroundTaskWithExpirationHandler:handler];
}

@end
