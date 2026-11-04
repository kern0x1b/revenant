#include "../revenant_impl.h"
#import "RevenantAXSettings.h"
#import "RevenantAXSettingsCommon.h"

BOOL BACKPORT_IMPL(AXPrefersHorizontalTextLayout)(void)
{
    return RevenantAXSettingIsOffOnThisRelease();
}

NSNotificationName const BACKPORT_IMPL(AXPrefersHorizontalTextLayoutDidChangeNotification) =
    @"AXPrefersHorizontalTextLayoutDidChangeNotification";

BOOL BACKPORT_IMPL(AXAnimatedImagesEnabled)(void)
{
    return RevenantAXSettingIsOffOnThisRelease();
}

NSNotificationName const BACKPORT_IMPL(AXAnimatedImagesEnabledDidChangeNotification) =
    @"AXAnimatedImagesEnabledDidChangeNotification";
