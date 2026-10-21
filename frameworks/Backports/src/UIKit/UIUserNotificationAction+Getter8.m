#import <UIKit/UIKit.h>

@implementation UIUserNotificationAction (RevenantGetter8)

- (BOOL)authenticationRequired
{
    return [self isAuthenticationRequired];
}

- (BOOL)destructive
{
    return [self isDestructive];
}

@end
