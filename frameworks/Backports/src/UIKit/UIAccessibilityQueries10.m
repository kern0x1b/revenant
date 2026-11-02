#include "../revenant_impl.h"
#import <UIKit/UIKit.h>

UIAccessibilityHearingDeviceEar BACKPORT_IMPL(UIAccessibilityHearingDevicePairedEar)(void)
{
    return UIAccessibilityHearingDeviceEarNone;
}

BOOL BACKPORT_IMPL(UIAccessibilityIsAssistiveTouchRunning)(void)
{
    return NO;
}
