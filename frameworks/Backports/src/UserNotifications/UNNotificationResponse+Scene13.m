#import "RevenantUserNotifications.h"
#import "../UIKit/RevenantScenes.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation UNNotificationResponse (RevenantScene13)

- (UIScene *)targetScene
{
    return revenant_scene();
}

@end
