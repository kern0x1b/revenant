#import "RevenantUserNotifications.h"

@implementation UNPushNotificationTrigger

+ (instancetype)revenant_pushTrigger
{
    return [[self alloc] initRevenantWithRepeats:NO];
}

@end
