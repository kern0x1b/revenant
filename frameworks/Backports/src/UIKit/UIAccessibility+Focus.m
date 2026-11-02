#include "../revenant_impl.h"
#import <UIKit/UIKit.h>

NSString *const BACKPORT_IMPL(UIAccessibilityShakeToUndoDidChangeNotification) = @"UIAccessibilityShakeToUndoDidChangeNotification";
NSString *const BACKPORT_IMPL(UIAccessibilityElementFocusedNotification) = @"UIAccessibilityElementFocusedNotification";
NSString *const BACKPORT_IMPL(UIAccessibilityFocusedElementKey) = @"UIAccessibilityFocusedElementKey";
NSString *const BACKPORT_IMPL(UIAccessibilityUnfocusedElementKey) = @"UIAccessibilityUnfocusedElementKey";
NSString *const BACKPORT_IMPL(UIAccessibilityAssistiveTechnologyKey) = @"UIAccessibilityAssistiveTechnologyKey";
NSString *const BACKPORT_IMPL(UIAccessibilityNotificationVoiceOverIdentifier) = @"UIAccessibilityNotificationVoiceOverIdentifier";

BOOL BACKPORT_IMPL(UIAccessibilityIsShakeToUndoEnabled)(void)
{
    return YES;
}

id BACKPORT_IMPL(UIAccessibilityFocusedElement)(NSString *assistiveTechnologyIdentifier)
{
    return nil;
}
