#include "../revenant_impl.h"
#import <UIKit/UIKit.h>

NSString *const UIAccessibilityShakeToUndoDidChangeNotification = @"UIAccessibilityShakeToUndoDidChangeNotification";
NSString *const UIAccessibilityElementFocusedNotification = @"UIAccessibilityElementFocusedNotification";
NSString *const UIAccessibilityFocusedElementKey = @"UIAccessibilityFocusedElementKey";
NSString *const UIAccessibilityUnfocusedElementKey = @"UIAccessibilityUnfocusedElementKey";
NSString *const UIAccessibilityAssistiveTechnologyKey = @"UIAccessibilityAssistiveTechnologyKey";
NSString *const UIAccessibilityNotificationVoiceOverIdentifier = @"UIAccessibilityNotificationVoiceOverIdentifier";

BOOL BACKPORT_IMPL(UIAccessibilityIsShakeToUndoEnabled)(void)
{
    return YES;
}

id BACKPORT_IMPL(UIAccessibilityFocusedElement)(NSString *assistiveTechnologyIdentifier)
{
    return nil;
}
