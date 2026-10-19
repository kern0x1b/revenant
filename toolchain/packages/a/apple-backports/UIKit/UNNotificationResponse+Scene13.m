#import "CharonUserNotifications.h"
#import "CharonScenes.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation UNNotificationResponse (CharonScene13)

- (UIScene *)targetScene
{
    return charon_scene();
}

@end
