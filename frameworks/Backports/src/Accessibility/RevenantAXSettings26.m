#include "../revenant_impl.h"
#import "RevenantAXSettings.h"
#import "RevenantAXSettingsCommon.h"

BOOL BACKPORT_IMPL(AXPrefersActionSliderAlternative)(void)
{
    return RevenantAXSettingIsOffOnThisRelease();
}

NSNotificationName const BACKPORT_IMPL(AXPrefersActionSliderAlternativeDidChangeNotification) =
    @"AXPrefersActionSliderAlternativeDidChangeNotification";

BOOL BACKPORT_IMPL(AXShowBordersEnabled)(void)
{
    return RevenantAXSettingIsOffOnThisRelease();
}

NSNotificationName const BACKPORT_IMPL(AXShowBordersEnabledStatusDidChangeNotification) =
    @"AXShowBordersEnabledStatusDidChangeNotification";
