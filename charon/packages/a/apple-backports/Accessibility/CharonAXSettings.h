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

typedef NS_ENUM(NSInteger, AXSettingsFeature) {
    AXSettingsFeaturePersonalVoiceAllowAppsToRequestToUse = 1,
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
