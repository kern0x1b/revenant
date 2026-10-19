//
//  CharonAXSettings17.m
//  Accessibility
//
//  The two settings of 17.0, one object because one object carries the API of one release and these two
//  arrived together. Both answers and the measurement behind them are in
//  CharonAXSettingsCommon.h, which every settings function of this library answers from.
//

#import "CharonAXSettings.h"
#import "CharonAXSettingsCommon.h"

BOOL AXPrefersHorizontalTextLayout(void)
{
    // Off: no release the port carries has a preference that lays text out horizontally, measured in
    // CharonAXSettingsCommon.h's own terms - the preference surface it holds has no such name in it.
    return CharonAXSettingIsOffOnThisRelease();
}

NSNotificationName const AXPrefersHorizontalTextLayoutDidChangeNotification =
    @"AXPrefersHorizontalTextLayoutDidChangeNotification";

BOOL AXAnimatedImagesEnabled(void)
{
    return CharonAXSettingIsOffOnThisRelease();
}

NSNotificationName const AXAnimatedImagesEnabledDidChangeNotification =
    @"AXAnimatedImagesEnabledDidChangeNotification";
