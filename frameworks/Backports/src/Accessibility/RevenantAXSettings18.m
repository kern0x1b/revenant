#include "../revenant_impl.h"
#import "RevenantAXSettings.h"
#import "RevenantAXSettingsCommon.h"

NSErrorDomain const RevenantAXSettingsErrorDomain = @"org.revenant.Accessibility.Settings";

BOOL BACKPORT_IMPL(AXPrefersNonBlinkingTextInsertionIndicator)(void)
{
    return RevenantAXSettingIsOffOnThisRelease();
}

NSNotificationName const BACKPORT_IMPL(AXPrefersNonBlinkingTextInsertionIndicatorDidChangeNotification) =
    @"AXPrefersNonBlinkingTextInsertionIndicatorDidChangeNotification";

BOOL BACKPORT_IMPL(AXAssistiveAccessEnabled)(void)
{
    return RevenantAXSettingIsOffOnThisRelease();
}

void BACKPORT_IMPL(AXOpenSettingsFeature)(AXSettingsFeature feature, void (^completionHandler)(NSError *_Nullable error))
{
    if (!completionHandler) {
        return;
    }
    static NSString *const names[] = {@"PersonalVoiceAllowAppsToRequestToUse", @"AllowAppsToAddAudioToCalls",
                                      @"AssistiveTouch", @"AssistiveTouchDevices", @"DwellControl"};
    BOOL known = feature >= AXSettingsFeaturePersonalVoiceAllowAppsToRequestToUse &&
                 feature <= AXSettingsFeatureDwellControl;
    NSString *section = known ? names[feature - 1] : nil;
    NSString *reason = section
        ? [NSString stringWithFormat:
            @"the Settings app of this release has no section for %@, so nothing was opened", section]
        : [NSString stringWithFormat:
            @"the Settings app of this release has no section for AXSettingsFeature %ld, which is not one "
            @"of the sections this API names, so nothing was opened", (long)feature];
    completionHandler([NSError errorWithDomain:RevenantAXSettingsErrorDomain code:feature userInfo:@{
        NSLocalizedDescriptionKey: reason,
        @"AXSettingsFeature": @(feature),
    }]);
}
