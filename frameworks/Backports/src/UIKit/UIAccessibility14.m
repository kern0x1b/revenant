#include "../revenant_impl.h"
#import <UIKit/UIKit.h>

NSString *const UIAccessibilityButtonShapesEnabledStatusDidChangeNotification = @"UIAccessibilityButtonShapesEnabledStatusDidChangeNotification";
NSString *const UIAccessibilityPrefersCrossFadeTransitionsStatusDidChangeNotification = @"UIAccessibilityPrefersCrossFadeTransitionsStatusDidChangeNotification";

BOOL BACKPORT_IMPL(UIAccessibilityButtonShapesEnabled)(void)
{
    return NO;
}

BOOL BACKPORT_IMPL(UIAccessibilityPrefersCrossFadeTransitions)(void)
{
    return NO;
}
