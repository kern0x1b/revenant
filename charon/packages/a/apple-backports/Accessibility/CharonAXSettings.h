//
//  CharonAXSettings.h
//  Accessibility
//
//  The settings functions of 18.0, 17.0 and 26.1, and the Settings-section enumeration of 18.0, under
//  the names an application writes. AXSettings.h is not in the SDK this package compiles against - it
//  arrived after 16.4 - so these are transcribed: the names, the kinds, the parameter and return types
//  and the availability - the type's, and each enumeration case's own, which is not the same thing and
//  is why the cases carry theirs individually. Nothing else is transcribed. No line of Apple's prose is reproduced here and no body of
//  Apple's is copied; every body is in CharonAXSettings17.m, CharonAXSettings18.m or
//  CharonAXSettings26.m and is the port's own.
//
//  Why each answer is what it is, and the measurement behind it, is in
//  facts/Accessibility/Accessibility.md. In one line each, and the same line appears above every body:
//  this release carries no accessibility preference of any of these five kinds, so the value is NO and
//  cannot change, so the notification that announces the change is never posted.
//
//  Three of these are the framework's own C surface with no device behind them at all -
//  AXAssistiveAccessEnabled, AXOpenSettingsFeature and the Settings-section enumeration - and the port
//  answers them as a release with no assistive-access mode and no such Settings sections answers them.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(ios(17.0))
FOUNDATION_EXPORT BOOL AXPrefersHorizontalTextLayout(void);

API_AVAILABLE(ios(17.0))
FOUNDATION_EXPORT NSNotificationName const _Nonnull AXPrefersHorizontalTextLayoutDidChangeNotification;

API_AVAILABLE(ios(17.0))
FOUNDATION_EXPORT BOOL AXAnimatedImagesEnabled(void);

API_AVAILABLE(ios(17.0))
FOUNDATION_EXPORT NSNotificationName const _Nonnull AXAnimatedImagesEnabledDidChangeNotification;

API_AVAILABLE(ios(18.0))
FOUNDATION_EXPORT BOOL AXAssistiveAccessEnabled(void);

API_AVAILABLE(ios(18.0))
FOUNDATION_EXPORT BOOL AXPrefersNonBlinkingTextInsertionIndicator(void);

API_AVAILABLE(ios(18.0))
FOUNDATION_EXPORT NSNotificationName const _Nonnull AXPrefersNonBlinkingTextInsertionIndicatorDidChangeNotification;

// The sections the Settings app of 18.0 opens at. The cases are names and numbers from the header, and
// they are here because AXOpenSettingsFeature takes one: a caller on this release has nothing to open
// whatever it asks for, and the case is what the caller's switch matched.
//
// **The availability is per case, and the first version of this file had it only on the type**, which
// is what this file's own preamble says it transcribes and what it did not do. The type arrived with
// 18.0; one case with 18.2; and the last three with 26.0. Given only the type's annotation, a caller
// whose deployment target is 18.0 could use the 26.0 cases with no diagnostic at all, where the same
// caller against the SDK is told to guard the use:
//
//   warning: 'AXSettingsFeatureDwellControl' is only available on iOS 26.0 or newer
//            [-Wunguarded-availability-new]
//
// The knowledge was in a comment in CharonAXSettings18.m and nowhere in the declaration, which is the
// one place a compiler reads. The annotations are facts from the header: the case name, its number, and
// the iOS release that release attaches to that case.
typedef NS_ENUM(NSInteger, AXSettingsFeature) {
    AXSettingsFeaturePersonalVoiceAllowAppsToRequestToUse = 1,
    // The annotation goes between the name and the comma, and an annotated case carries no explicit
    // value and numbers itself from the one before. Written the other way round - the value first, then
    // the annotation - clang stops at the case with "expected '}' or ','"; and the two forms are not
    // interchangeable, so this is the shape the header has and the shape that compiles.
    AXSettingsFeatureAllowAppsToAddAudioToCalls API_AVAILABLE(ios(18.2)),
    AXSettingsFeatureAssistiveTouch API_AVAILABLE(ios(26.0)),
    AXSettingsFeatureAssistiveTouchDevices API_AVAILABLE(ios(26.0)),
    AXSettingsFeatureDwellControl API_AVAILABLE(ios(26.0))
} API_AVAILABLE(ios(18.0));

API_AVAILABLE(ios(18.0))
FOUNDATION_EXPORT void AXOpenSettingsFeature(AXSettingsFeature feature,
                                             void (^_Nullable completionHandler)(NSError *_Nullable error));

NS_ASSUME_NONNULL_END

API_AVAILABLE(ios(26.1))
FOUNDATION_EXPORT BOOL AXPrefersActionSliderAlternative(void);

API_AVAILABLE(ios(26.1))
FOUNDATION_EXPORT NSNotificationName const _Nonnull AXPrefersActionSliderAlternativeDidChangeNotification;

API_AVAILABLE(ios(26.1))
FOUNDATION_EXPORT BOOL AXShowBordersEnabled(void);

API_AVAILABLE(ios(26.1))
FOUNDATION_EXPORT NSNotificationName const _Nonnull AXShowBordersEnabledStatusDidChangeNotification;
