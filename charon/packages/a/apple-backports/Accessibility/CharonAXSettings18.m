#import "CharonAXSettings.h"
#import "CharonAXSettingsCommon.h"

NSErrorDomain const CharonAXSettingsErrorDomain = @"org.charon.Accessibility.Settings";

BOOL AXPrefersNonBlinkingTextInsertionIndicator(void)
{
    return CharonAXSettingIsOffOnThisRelease();
}

NSNotificationName const AXPrefersNonBlinkingTextInsertionIndicatorDidChangeNotification =
    @"AXPrefersNonBlinkingTextInsertionIndicatorDidChangeNotification";

BOOL AXAssistiveAccessEnabled(void)
{
    return CharonAXSettingIsOffOnThisRelease();
}

void AXOpenSettingsFeature(AXSettingsFeature feature, void (^completionHandler)(NSError *_Nullable error))
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
    completionHandler([NSError errorWithDomain:CharonAXSettingsErrorDomain code:feature userInfo:@{
        NSLocalizedDescriptionKey: reason,
        @"AXSettingsFeature": @(feature),
    }]);
}
