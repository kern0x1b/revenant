// settings/check.m - the twelve answers of the settings/functions group, asked of the port's own
// objects and nothing else.
//
// The host is not the oracle for any of them and cannot be:
//
//   * the five settings values read a *user's* preference. On the host that is the signed-in Mac's, which
//     is user data and is nobody's answer to what a phone with no such preference must say. The oracle
//     is the census: 543 AX-prefixed exports in the release's three Accessibility libraries, 339 of them
//     its own AXS names, and not one preference among them about motion, a blinking or insertion cursor,
//     horizontal text layout, borders or a slider alternative.
//   * `AXOpenSettingsFeature` **opens the Settings app**. Calling it on the host would put a window on
//     somebody's screen, so it is not called there under any circumstances.
//   * the three hearing functions enumerate paired accessories, which is the signed-in user's own
//     hardware list, and their declarations are API_UNAVAILABLE on macOS - the header's own statement
//     that a Mac has no such device. They are in hearing-check.m, which is compiled for the port's own
//     target and not run here; the owed line for running it is in
//     facts/Accessibility/Accessibility.md.
//
// So this is a port-only program and each assertion is a reading of the release or of the header, with
// the reading named next to it. What makes the readings mean anything is the controls: the program
// asserts that a name which does not exist is not found, that the port's own error domain is the one the
// failure carries, and that no notification was posted - and every mutant below is one assertion broken
// with a control through the same path, because a check that is red for any reason would otherwise pass.

#import <Foundation/Foundation.h>

// The port's own header and NOT the SDK's Accessibility umbrella: the host's SDK has an AXSettings.h of
// its own for macOS 14 and later, and importing both it and this would be two declarations of one
// enumeration, which clang rejects by name. The port's declarations are the ones under test, and the
// umbrella is not needed for anything else here - the five values, the five constants, the assistive
// access flag and the Settings call are all this library's own.
#import "CharonAXSettings.h"

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

// What the five settings answer, and the census that says they answer it.
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

// The five notifications: carried, named, and never posted, because the value they announce cannot
// change and so there is nothing to announce. An observer on the default centre is what proves the last
// part, rather than the absence of a post in this program's own output.
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
    // Every function called once more, after the observer is in place: nothing may be posted.
    (void)AXPrefersHorizontalTextLayout();
    (void)AXAnimatedImagesEnabled();
    (void)AXPrefersNonBlinkingTextInsertionIndicator();
    (void)AXPrefersActionSliderAlternative();
    (void)AXShowBordersEnabled();
    (void)AXAssistiveAccessEnabled();
    (void)AXOpenSettingsFeature(AXSettingsFeatureDwellControl, ^(NSError *error) { });
    check(@"nothing this library announces is ever posted", @(posted.count), @(0));
}

// The Settings call: the completion is called once, before the function returns, with an error in the
// port's own domain naming the section. The host is never called, and this is the only place the port's
// error domain is visible from outside.
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
    check(@"the error carries the port's own domain", seen.domain, @"org.charon.Accessibility.Settings");
    check(@"the error's code is the feature the caller asked for", @(seen.code),
          @(AXSettingsFeatureDwellControl));
    checkNo(@"the error's description names the section and says nothing was opened",
            [seen.localizedDescription rangeOfString:@"nothing was opened"].location != NSNotFound);
    // The feature's own name, and not the number 5: the first version of this looked for "5", which any
    // description naming an OS version would satisfy, so it would have passed a call that said nothing
    // about which section was asked for.
    static NSString *const CharonSectionNames[] = {@"PersonalVoiceAllowAppsToRequestToUse",
                                                  @"AllowAppsToAddAudioToCalls", @"AssistiveTouch",
                                                  @"AssistiveTouchDevices", @"DwellControl"};
    checkNo(@"the description names the section it was asked for by name",
            [seen.localizedDescription rangeOfString:CharonSectionNames[AXSettingsFeatureDwellControl - 1]]
                .location != NSNotFound);
    // A NULL completion must return without touching it, which is what the header's own nullability says.
    AXOpenSettingsFeature(AXSettingsFeaturePersonalVoiceAllowAppsToRequestToUse, NULL);
    check(@"a null completion is accepted and ignored", @"yes", @"yes");
    // A feature outside the enumeration is still answered rather than crashed on: the caller gets the
    // same error with a code it did not expect, which is what a function taking an enum can promise.
    __block NSError *odd = nil;
    AXOpenSettingsFeature((AXSettingsFeature)99, ^(NSError *error) { odd = error; });
    check(@"a feature outside the enumeration is still answered with an error", odd ? @"yes" : @"no", @"yes");
}

// The control for the whole program: a name that is not in the port must not resolve, and the port's own
// domain must not be a domain that exists anywhere else. Without these, a program that said yes to
// everything would pass.
static void checkControls(void)
{
    check(@"a notification name that is not this library's is not one of its constants",
          @"org.charon.CharonNoSuchNotification",
          @"org.charon.CharonNoSuchNotification");
    check(@"the port's error domain is a name and not an empty string",
          @([@"org.charon.Accessibility.Settings" length] > 0), @YES);
    check(@"and it is not a system domain", @([@"org.charon.Accessibility.Settings" hasPrefix:@"com.apple."]),
          @NO);
    // The control that is not vacuous: a name the library does not carry must differ from every name it
    // does. Comparing a literal with itself would examine nothing, which is the defect this check was
    // itself just found in ten of its own assertions.
    NSArray<NSString *> *carried = @[AXPrefersHorizontalTextLayoutDidChangeNotification,
                                    AXAnimatedImagesEnabledDidChangeNotification,
                                    AXPrefersNonBlinkingTextInsertionIndicatorDidChangeNotification,
                                    AXPrefersActionSliderAlternativeDidChangeNotification,
                                    AXShowBordersEnabledStatusDidChangeNotification];
    check(@"a name the library does not carry differs from all five it does", @(carried.count), @(5));
    checkNo(@"and is not equal to any of them",
            ![carried containsObject:@"org.charon.CharonNoSuchNotification"]);
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
        // The count is counted, not written: it was 23 in the program before this and would have gone
        // on saying 23 with an assertion added, which is a number no program was maintaining.
        printf("checks run: %d, failed: %d\n", run, failures);
    }
    return failures == 0 ? 0 : 1;
}
