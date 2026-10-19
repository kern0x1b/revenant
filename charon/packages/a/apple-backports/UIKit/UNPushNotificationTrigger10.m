#import "CharonUserNotifications.h"

@implementation UNPushNotificationTrigger

+ (instancetype)charon_pushTrigger
{
    return [[self alloc] initCharonWithRepeats:NO];
}

@end
