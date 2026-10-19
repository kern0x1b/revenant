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
// 16.4/16.5's header already declares both, plainly (no const, measured: UIAccessibilityConstants.h:157-158);
// 26.2's declares them const (measured: UIAccessibilityConstants.h:165-166). A single unqualified spelling
// redefines one of the two "with a different type" - matched by the SDK's own __IPHONE_OS_VERSION_MAX_ALLOWED
// (160400 for 16.4, 260200 for 26.2, measured directly). 200000 is not one of those two values, but every
// SDK this package can be built against lands well clear of it either way: iOS's own numbering has nothing
// between 18.x (mid-180000s) and 26.x (260000+) - Apple renumbered straight from 18 to 26 (WWDC 2025's
// "align with the calendar year" change), skipping 19-25 outright - and the two SDKs cached in this
// workspace (`~/.xmake/packages/i/iphoneos-sdk/`) are exactly 16.4 and 26.2, nothing in between. A third
// SDK this package is ever built against, whenever one is added, should have this comment (and the
// threshold, if that SDK's own header disagrees with which side of 200000 it should fall on) re-measured
// against its own header rather than assumed to keep working.
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
