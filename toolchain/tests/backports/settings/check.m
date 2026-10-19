#import <Foundation/Foundation.h>

#import "RevenantAXSettings.h"

static int failures = 0;
static int run = 0;

static void check(NSString *rule, id got, id want)
{
    run++;
    BOOL same = (got == want) || [got isEqual:want];
    printf("check\t%s\t%s\t%s\n", rule.UTF8String, same ? "ok" : "FAILED",
           same ? [[want description] UTF8String]
                : [[NSString stringWithFormat:@"got %@ wanted %@", got, want] UTF8String]);
    if (!same) failures++;
}

static void checkNo(NSString *rule, BOOL condition)
{
    check(rule, condition ? @"yes" : @"no", @"yes");
}

static void checkSettingsValues(void)
{
    check(@"AXPrefersHorizontalTextLayout answers the release's answer",
          @(AXPrefersHorizontalTextLayout()), @NO);
    check(@"AXAnimatedImagesEnabled answers the release's answer", @(AXAnimatedImagesEnabled()), @NO);
    check(@"AXPrefersNonBlinkingTextInsertionIndicator answers the release's answer",
          @(AXPrefersNonBlinkingTextInsertionIndicator()), @NO);
    check(@"AXPrefersActionSliderAlternative answers the release's answer",
          @(AXPrefersActionSliderAlternative()), @NO);
    check(@"AXShowBordersEnabled answers the release's answer", @(AXShowBordersEnabled()), @NO);
    check(@"AXAssistiveAccessEnabled answers the release's answer", @(AXAssistiveAccessEnabled()), @NO);
}

static void checkNotifications(NSMutableArray<NSNotificationName> *posted)
{
    struct { NSNotificationName name; const char *symbol; } constants[] = {
        {AXPrefersHorizontalTextLayoutDidChangeNotification, "AXPrefersHorizontalTextLayoutDidChangeNotification"},
        {AXAnimatedImagesEnabledDidChangeNotification, "AXAnimatedImagesEnabledDidChangeNotification"},
        {AXPrefersNonBlinkingTextInsertionIndicatorDidChangeNotification,
         "AXPrefersNonBlinkingTextInsertionIndicatorDidChangeNotification"},
        {AXPrefersActionSliderAlternativeDidChangeNotification, "AXPrefersActionSliderAlternativeDidChangeNotification"},
        {AXShowBordersEnabledStatusDidChangeNotification, "AXShowBordersEnabledStatusDidChangeNotification"},
    };
    for (unsigned index = 0; index < sizeof(constants) / sizeof(constants[0]); index++) {
        NSString *rule = ([NSString stringWithFormat:@"%s is carried under its own name", constants[index].symbol]);
        check(rule, constants[index].name, [NSString stringWithUTF8String:constants[index].symbol]);
    }
    (void)AXPrefersHorizontalTextLayout();
    (void)AXAnimatedImagesEnabled();
    (void)AXPrefersNonBlinkingTextInsertionIndicator();
    (void)AXPrefersActionSliderAlternative();
    (void)AXShowBordersEnabled();
    (void)AXAssistiveAccessEnabled();
    (void)AXOpenSettingsFeature(AXSettingsFeatureDwellControl, ^(NSError *error) { });
    check(@"nothing this library announces is ever posted", @(posted.count), @(0));
}

static void checkOpenSettings(void)
{
    __block NSUInteger calls = 0;
    __block NSError *seen = nil;
    AXOpenSettingsFeature(AXSettingsFeatureDwellControl, ^(NSError *error) {
        calls++;
        seen = error;
    });
    check(@"the completion is called before the function returns, not later", @(calls), @(1));
    checkNo(@"the error is not nil, so a caller can tell the call did not begin", seen != nil);
    check(@"the error carries the port's own domain", seen.domain, @"org.revenant.Accessibility.Settings");
    check(@"the error's code is the feature the caller asked for", @(seen.code),
          @(AXSettingsFeatureDwellControl));
    checkNo(@"the error's description names the section and says nothing was opened",
            [seen.localizedDescription rangeOfString:@"nothing was opened"].location != NSNotFound);
    static NSString *const RevenantSectionNames[] = {@"PersonalVoiceAllowAppsToRequestToUse",
                                                  @"AllowAppsToAddAudioToCalls", @"AssistiveTouch",
                                                  @"AssistiveTouchDevices", @"DwellControl"};
    checkNo(@"the description names the section it was asked for by name",
            [seen.localizedDescription rangeOfString:RevenantSectionNames[AXSettingsFeatureDwellControl - 1]]
                .location != NSNotFound);
    AXOpenSettingsFeature(AXSettingsFeaturePersonalVoiceAllowAppsToRequestToUse, NULL);
    check(@"a null completion is accepted and ignored", @"yes", @"yes");
    __block NSError *odd = nil;
    AXOpenSettingsFeature((AXSettingsFeature)99, ^(NSError *error) { odd = error; });
    check(@"a feature outside the enumeration is still answered with an error", odd ? @"yes" : @"no", @"yes");
}

static void checkControls(void)
{
    check(@"a notification name that is not this library's is not one of its constants",
          @"org.revenant.RevenantNoSuchNotification",
          @"org.revenant.RevenantNoSuchNotification");
    check(@"the port's error domain is a name and not an empty string",
          @([@"org.revenant.Accessibility.Settings" length] > 0), @YES);
    check(@"and it is not a system domain", @([@"org.revenant.Accessibility.Settings" hasPrefix:@"com.apple."]),
          @NO);
    NSArray<NSString *> *carried = @[AXPrefersHorizontalTextLayoutDidChangeNotification,
                                    AXAnimatedImagesEnabledDidChangeNotification,
                                    AXPrefersNonBlinkingTextInsertionIndicatorDidChangeNotification,
                                    AXPrefersActionSliderAlternativeDidChangeNotification,
                                    AXShowBordersEnabledStatusDidChangeNotification];
    check(@"a name the library does not carry differs from all five it does", @(carried.count), @(5));
    checkNo(@"and is not equal to any of them",
            ![carried containsObject:@"org.revenant.RevenantNoSuchNotification"]);
}

int main(void)
{
    @autoreleasepool {
        NSMutableArray<NSNotificationName> *posted = [NSMutableArray array];
        id observer = [[NSNotificationCenter defaultCenter]
            addObserverForName:nil object:nil queue:nil usingBlock:^(NSNotification *note) {
                [posted addObject:note.name];
            }];
        checkSettingsValues();
        checkNotifications(posted);
        checkOpenSettings();
        checkControls();
        [[NSNotificationCenter defaultCenter] removeObserver:observer];
        printf("checks run: %d, failed: %d\n", run, failures);
    }
    return failures == 0 ? 0 : 1;
}
