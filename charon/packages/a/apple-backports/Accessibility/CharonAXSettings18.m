//
//  CharonAXSettings18.m
//  Accessibility
//
//  The settings of 18.0, one object because one object carries the API of one release: the non-blinking
//  insertion indicator and its notification, whether assistive access is on, and opening the Settings
//  app at a named section.
//

#import "CharonAXSettings.h"
#import "CharonAXSettingsCommon.h"

// The domain the port's own error carries. Apple's header gives no domain and no error type for this
// call, so the port names its own rather than borrowing a name it would have to guess: a caller that
// reads NSError's domain gets a string that says who wrote the error, which is the one thing an error
// without a framework of its own can still be honest about.
NSErrorDomain const CharonAXSettingsErrorDomain = @"org.charon.Accessibility.Settings";

BOOL AXPrefersNonBlinkingTextInsertionIndicator(void)
{
    return CharonAXSettingIsOffOnThisRelease();
}

NSNotificationName const AXPrefersNonBlinkingTextInsertionIndicatorDidChangeNotification =
    @"AXPrefersNonBlinkingTextInsertionIndicatorDidChangeNotification";

BOOL AXAssistiveAccessEnabled(void)
{
    // Off, and the header's own contract is what makes it a reading rather than a placeholder: this
    // value cannot change in the life of a process, and a release with no assistive-access mode has no
    // process in which it would be on. The release this port carries has no such mode - the surface it
    // holds is preferences and nothing else, measured.
    return CharonAXSettingIsOffOnThisRelease();
}

void AXOpenSettingsFeature(AXSettingsFeature feature, void (^completionHandler)(NSError *_Nullable error))
{
    // This release's Settings app has none of the sections the enumeration names, whatever the caller's
    // deployment target is: the Settings app of 6.1.3 has no section for a personal voice, none for
    // adding audio to calls, no Assistive Touch, no Assistive Touch devices and no Dwell Control. The
    // release each of those arrived in is not written down here - it is on the case, in
    // CharonAXSettings.h, which is the one place a compiler reads it and where a caller finds it. So the
    // call cannot begin.
    //
    // The completion is called, and called once, and called before this function returns. That is a
    // decision and it is a forced one: the API takes a completion, and a caller that waits for a
    // completion that does not come waits forever. Calling it synchronously is the only answer that
    // leaves a caller able to carry on, and it is what the caller will see on a real device too.
    if (!completionHandler) {
        return;
    }
    // The section's own name and not its number. A caller reading this error wants to know which section
    // it asked for and could not get, and a number is not that; the names are the enumeration's own cases
    // and the table is here because a C function has nowhere else to keep them. A feature outside the
    // enumeration has no name, and the error then says so rather than naming a section that does not
    // exist.
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
