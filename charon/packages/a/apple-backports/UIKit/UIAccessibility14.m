#import <UIKit/UIKit.h>

NSString *const UIAccessibilityButtonShapesEnabledStatusDidChangeNotification = @"UIAccessibilityButtonShapesEnabledStatusDidChangeNotification";
NSString *const UIAccessibilityPrefersCrossFadeTransitionsStatusDidChangeNotification = @"UIAccessibilityPrefersCrossFadeTransitionsStatusDidChangeNotification";

BOOL UIAccessibilityButtonShapesEnabled(void)
{
    return NO;
}

BOOL UIAccessibilityPrefersCrossFadeTransitions(void)
{
    return NO;
}
