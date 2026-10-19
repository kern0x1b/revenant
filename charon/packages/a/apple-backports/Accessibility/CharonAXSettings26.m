#import "CharonAXSettings.h"
#import "CharonAXSettingsCommon.h"

BOOL AXPrefersActionSliderAlternative(void)
{
    return CharonAXSettingIsOffOnThisRelease();
}

NSNotificationName const AXPrefersActionSliderAlternativeDidChangeNotification =
    @"AXPrefersActionSliderAlternativeDidChangeNotification";

BOOL AXShowBordersEnabled(void)
{
    return CharonAXSettingIsOffOnThisRelease();
}

NSNotificationName const AXShowBordersEnabledStatusDidChangeNotification =
    @"AXShowBordersEnabledStatusDidChangeNotification";
