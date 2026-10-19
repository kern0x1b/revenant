//
//  CharonAXSettings26.m
//  Accessibility
//
//  The two settings of 26.1, one object because one object carries the API of one release and these two
//  arrived together. Both answers and the measurement behind them are in
//  CharonAXSettingsCommon.h.
//

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
