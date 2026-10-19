#import "CharonUserNotifications.h"

// The trigger of a notification that came from a server, which is a marker and nothing more: the
// SDK's own header declares no property and no method on UNPushNotificationTrigger, so a caller
// learns a notification was pushed by asking whether its request's trigger is of this class, and
// reads the identifier, the body, the badge, the sound and the payload out of the request's content.
// Everything else - repeats, secure coding, equality, hash, copying - is UNNotificationTrigger's, and
// is carried there.
//
// iOS 6 has no UserNotifications framework to ask and no daemon to route a push through: it arrives
// in -application:didReceiveRemoteNotification: of the application delegate, which UNUserNotificationCenter
// hooks. That hook is what makes a request carrying this trigger exist at all; the class here is
// what such a request's trigger is.

@implementation UNPushNotificationTrigger

+ (instancetype)charon_pushTrigger
{
    // A pushed notification is not a schedule the application asked for, so it never repeats.
    return [[self alloc] initCharonWithRepeats:NO];
}

@end