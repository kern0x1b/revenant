#import <UIKit/UIKit.h>

// The two that arrived in iOS 10.0, in their own file because an object carries the API of one
// release. The reasons each answers as it does, and the measurements behind them, are in
// facts/UIKit/AccessibilityQueries.md.

UIAccessibilityHearingDeviceEar UIAccessibilityHearingDevicePairedEar(void)
{
    // The ear a paired hearing device sits in. This device has no paired hearing device, so there is
    // no ear, which is the answer the release documents for no device.
    return UIAccessibilityHearingDeviceEarNone;
}

BOOL UIAccessibilityIsAssistiveTouchRunning(void)
{
    // Whether AssistiveTouch is on. Measured on the release's own cache: the only AssistiveTouch
    // names iOS 6.1.3 carries are AssistiveTouchCustomGestureCreation and AssistiveTouchPID,
    // neither of which is a state, and it exposes no notification the state changes through, so
    // there is nothing on this release to read and the answer is the one a device with AssistiveTouch
    // off gives. An application that needs to know can watch the running state itself.
    return NO;
}
