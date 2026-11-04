#include "../revenant_impl.h"
#import <UIKit/UIKit.h>

NSString *const BACKPORT_IMPL(UIAccessibilityButtonShapesEnabledStatusDidChangeNotification) = @"UIAccessibilityButtonShapesEnabledStatusDidChangeNotification";
NSString *const BACKPORT_IMPL(UIAccessibilityPrefersCrossFadeTransitionsStatusDidChangeNotification) = @"UIAccessibilityPrefersCrossFadeTransitionsStatusDidChangeNotification";

BOOL BACKPORT_IMPL(UIAccessibilityButtonShapesEnabled)(void)
{
    return NO;
}

BOOL BACKPORT_IMPL(UIAccessibilityPrefersCrossFadeTransitions)(void)
{
    return NO;
}
