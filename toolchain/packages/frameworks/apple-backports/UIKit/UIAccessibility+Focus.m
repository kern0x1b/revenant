#import <UIKit/UIKit.h>

NSString *const UIAccessibilityShakeToUndoDidChangeNotification = @"UIAccessibilityShakeToUndoDidChangeNotification";
NSString *const UIAccessibilityElementFocusedNotification = @"UIAccessibilityElementFocusedNotification";
NSString *const UIAccessibilityFocusedElementKey = @"UIAccessibilityFocusedElementKey";
NSString *const UIAccessibilityUnfocusedElementKey = @"UIAccessibilityUnfocusedElementKey";
NSString *const UIAccessibilityAssistiveTechnologyKey = @"UIAccessibilityAssistiveTechnologyKey";
NSString *const UIAccessibilityNotificationVoiceOverIdentifier = @"UIAccessibilityNotificationVoiceOverIdentifier";

BOOL UIAccessibilityIsShakeToUndoEnabled(void)
{
    return YES;
}

id UIAccessibilityFocusedElement(NSString *assistiveTechnologyIdentifier)
{
    return nil;
}
