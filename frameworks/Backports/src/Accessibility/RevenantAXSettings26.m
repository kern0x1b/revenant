#import "RevenantAXSettings.h"
#import "RevenantAXSettingsCommon.h"

BOOL AXPrefersActionSliderAlternative(void)
{
    return RevenantAXSettingIsOffOnThisRelease();
}

NSNotificationName const AXPrefersActionSliderAlternativeDidChangeNotification =
    @"AXPrefersActionSliderAlternativeDidChangeNotification";

BOOL AXShowBordersEnabled(void)
{
    return RevenantAXSettingIsOffOnThisRelease();
}

NSNotificationName const AXShowBordersEnabledStatusDidChangeNotification =
    @"AXShowBordersEnabledStatusDidChangeNotification";
