#import <UIKit/UIKit.h>
#import <UserNotificationsUI/UserNotificationsUI.h>
#import <objc/runtime.h>

// The notification content extension arrived with iOS 10, and it runs in a separate process the
// system starts; this release has no app extensions at all, so no host ever makes an NSExtensionContext
// for one. The NSExtensionContext the port carries is already recorded as inert for exactly that
// reason (registry/Foundation/ios8extensioncontext.json).
//
// The actions an extension wants offered are the extension's own, and the port keeps them and hands
// them back as they are set: an extension that set none reads an empty array rather than nil.

// The header declares five members of this category and the port carries one of them: the four the
// release cannot act on are registry entries with status absent, and their selectors are the point at
// which the compiler's -Wincomplete-implementation would otherwise fire on every build.
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation NSExtensionContext (UNNotificationContentExtension)

@dynamic notificationActions;

// The actions the extension wants offered. The array is the extension's own, kept and handed back as
// it is set; the system that would draw them, and the response that would come back through
// -didReceiveNotificationResponse:completionHandler:, belong to the extension host this release does
// not run.
- (NSArray<UNNotificationAction *> *)notificationActions
{
    return objc_getAssociatedObject(self, @selector(notificationActions)) ?: @[];
}

- (void)setNotificationActions:(NSArray<UNNotificationAction *> *)notificationActions
{
    objc_setAssociatedObject(self, @selector(notificationActions), notificationActions, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

// What is NOT here is as deliberate as what is. The four messages to a host - perform the default
// action, dismiss the content extension, and the two halves of the media state - each need something
// this release does not have: a delivered notification to act on, a presented content extension to
// dismiss, and a system that takes playback controls in a notification. A selector the port carried
// for any of them would store a state nothing can act on, which is the silent fake COORDINATION.md §2
// forbids, so they are registry entries with status absent and the port carries none of them.
@end
