#import "RevenantAXSettings.h"
#import "RevenantAXSettingsCommon.h"

BOOL AXPrefersHorizontalTextLayout(void)
{
    return RevenantAXSettingIsOffOnThisRelease();
}

NSNotificationName const AXPrefersHorizontalTextLayoutDidChangeNotification =
    @"AXPrefersHorizontalTextLayoutDidChangeNotification";

BOOL AXAnimatedImagesEnabled(void)
{
    return RevenantAXSettingIsOffOnThisRelease();
}

NSNotificationName const AXAnimatedImagesEnabledDidChangeNotification =
    @"AXAnimatedImagesEnabledDidChangeNotification";
