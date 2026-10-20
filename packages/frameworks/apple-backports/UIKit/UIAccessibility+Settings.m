#import <UIKit/UIKit.h>

NSString *const UIAccessibilityBoldTextStatusDidChangeNotification = @"UIAccessibilityBoldTextStatusDidChangeNotification";
NSString *const UIAccessibilityGrayscaleStatusDidChangeNotification = @"UIAccessibilityGrayscaleStatusDidChangeNotification";
NSString *const UIAccessibilityReduceMotionStatusDidChangeNotification = @"UIAccessibilityReduceMotionStatusDidChangeNotification";
NSString *const UIAccessibilityReduceTransparencyStatusDidChangeNotification = @"UIAccessibilityReduceTransparencyStatusDidChangeNotification";
NSString *const UIAccessibilityDarkerSystemColorsStatusDidChangeNotification = @"UIAccessibilityDarkerSystemColorsStatusDidChangeNotification";
NSString *const UIAccessibilitySpeakScreenStatusDidChangeNotification = @"UIAccessibilitySpeakScreenStatusDidChangeNotification";
NSString *const UIAccessibilitySpeakSelectionStatusDidChangeNotification = @"UIAccessibilitySpeakSelectionStatusDidChangeNotification";
NSString *const UIAccessibilitySwitchControlStatusDidChangeNotification = @"UIAccessibilitySwitchControlStatusDidChangeNotification";
NSString *const UIAccessibilityNotificationSwitchControlIdentifier = @"UIAccessibilityNotificationSwitchControlIdentifier";
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 200000
const UIAccessibilityNotifications UIAccessibilityPauseAssistiveTechnologyNotification = 1033;
const UIAccessibilityNotifications UIAccessibilityResumeAssistiveTechnologyNotification = 1034;
#else
UIAccessibilityNotifications UIAccessibilityPauseAssistiveTechnologyNotification = 1033;
UIAccessibilityNotifications UIAccessibilityResumeAssistiveTechnologyNotification = 1034;
#endif

BOOL UIAccessibilityIsBoldTextEnabled(void)
{
    return NO;
}

BOOL UIAccessibilityIsGrayscaleEnabled(void)
{
    return NO;
}

BOOL UIAccessibilityIsReduceMotionEnabled(void)
{
    return NO;
}

BOOL UIAccessibilityIsReduceTransparencyEnabled(void)
{
    return NO;
}

BOOL UIAccessibilityDarkerSystemColorsEnabled(void)
{
    return NO;
}

BOOL UIAccessibilityIsSpeakScreenEnabled(void)
{
    return NO;
}

BOOL UIAccessibilityIsSpeakSelectionEnabled(void)
{
    return NO;
}

BOOL UIAccessibilityIsSwitchControlRunning(void)
{
    return NO;
}
