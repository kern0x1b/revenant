#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation UIApplication (RevenantGetter8)

- (BOOL)registeredForRemoteNotifications
{
    return [self isRegisteredForRemoteNotifications];
}

@end
