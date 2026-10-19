#import "CharonAXSettings.h"
#import "CharonAXSettingsCommon.h"

BOOL AXPrefersHorizontalTextLayout(void)
{
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
