#include "../revenant_impl.h"
#import <UIKit/UIKit.h>

NSString *const BACKPORT_IMPL(UIAccessibilityBoldTextStatusDidChangeNotification) = @"UIAccessibilityBoldTextStatusDidChangeNotification";
NSString *const BACKPORT_IMPL(UIAccessibilityGrayscaleStatusDidChangeNotification) = @"UIAccessibilityGrayscaleStatusDidChangeNotification";
NSString *const BACKPORT_IMPL(UIAccessibilityReduceMotionStatusDidChangeNotification) = @"UIAccessibilityReduceMotionStatusDidChangeNotification";
NSString *const BACKPORT_IMPL(UIAccessibilityReduceTransparencyStatusDidChangeNotification) = @"UIAccessibilityReduceTransparencyStatusDidChangeNotification";
NSString *const BACKPORT_IMPL(UIAccessibilityDarkerSystemColorsStatusDidChangeNotification) = @"UIAccessibilityDarkerSystemColorsStatusDidChangeNotification";
NSString *const BACKPORT_IMPL(UIAccessibilitySpeakScreenStatusDidChangeNotification) = @"UIAccessibilitySpeakScreenStatusDidChangeNotification";
NSString *const BACKPORT_IMPL(UIAccessibilitySpeakSelectionStatusDidChangeNotification) = @"UIAccessibilitySpeakSelectionStatusDidChangeNotification";
NSString *const BACKPORT_IMPL(UIAccessibilitySwitchControlStatusDidChangeNotification) = @"UIAccessibilitySwitchControlStatusDidChangeNotification";
NSString *const BACKPORT_IMPL(UIAccessibilityNotificationSwitchControlIdentifier) = @"UIAccessibilityNotificationSwitchControlIdentifier";
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 200000
const UIAccessibilityNotifications BACKPORT_IMPL(UIAccessibilityPauseAssistiveTechnologyNotification) = 1033;
const UIAccessibilityNotifications BACKPORT_IMPL(UIAccessibilityResumeAssistiveTechnologyNotification) = 1034;
#else
UIAccessibilityNotifications BACKPORT_IMPL(UIAccessibilityPauseAssistiveTechnologyNotification) = 1033;
UIAccessibilityNotifications BACKPORT_IMPL(UIAccessibilityResumeAssistiveTechnologyNotification) = 1034;
#endif

BOOL BACKPORT_IMPL(UIAccessibilityIsBoldTextEnabled)(void)
{
    return NO;
}

BOOL BACKPORT_IMPL(UIAccessibilityIsGrayscaleEnabled)(void)
{
    return NO;
}

BOOL BACKPORT_IMPL(UIAccessibilityIsReduceMotionEnabled)(void)
{
    return NO;
}

BOOL BACKPORT_IMPL(UIAccessibilityIsReduceTransparencyEnabled)(void)
{
    return NO;
}

BOOL BACKPORT_IMPL(UIAccessibilityDarkerSystemColorsEnabled)(void)
{
    return NO;
}

BOOL BACKPORT_IMPL(UIAccessibilityIsSpeakScreenEnabled)(void)
{
    return NO;
}

BOOL BACKPORT_IMPL(UIAccessibilityIsSpeakSelectionEnabled)(void)
{
    return NO;
}

BOOL BACKPORT_IMPL(UIAccessibilityIsSwitchControlRunning)(void)
{
    return NO;
}
