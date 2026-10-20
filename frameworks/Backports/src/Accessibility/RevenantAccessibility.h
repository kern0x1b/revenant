#import <Foundation/Foundation.h>
#ifndef REVENANT_BRAILLE_ONLY
#import <Accessibility/Accessibility.h>
#endif

#ifndef AX_EXTERN
#define AX_EXTERN extern
#endif

NS_ASSUME_NONNULL_BEGIN

#pragma mark - AXTechnology (iOS 18.0)

API_AVAILABLE(ios(18.0), macos(15.0), tvos(18.0), watchos(11.0))
typedef NSString *const AXTechnology NS_TYPED_ENUM NS_SWIFT_NAME(AccessibilityTechnology);

API_AVAILABLE(ios(18.0), macos(15.0), tvos(18.0), watchos(11.0))
AX_EXTERN AXTechnology AXTechnologyVoiceOver;
API_AVAILABLE(ios(18.0), macos(15.0), tvos(18.0), watchos(11.0))
AX_EXTERN AXTechnology AXTechnologySwitchControl;
API_AVAILABLE(ios(18.0), macos(15.0), tvos(18.0), watchos(11.0))
AX_EXTERN AXTechnology AXTechnologyFullAccess;
API_AVAILABLE(ios(18.0), macos(15.0), tvos(18.0), watchos(11.0))
AX_EXTERN AXTechnology AXTechnologyHearingDevicePaired;
API_AVAILABLE(ios(18.0), macos(15.0), tvos(18.0), watchos(11.0))
AX_EXTERN AXTechnology AXTechnologyHearingDeviceActive;
API_AVAILABLE(ios(18.0), macos(15.0), tvos(18.0), watchos(11.0))
AX_EXTERN AXTechnology AXTechnologyAutomaticActivation;
API_AVAILABLE(ios(18.0), macos(15.0), tvos(18.0), watchos(11.0))
AX_EXTERN AXTechnology AXTechnologyHearingTest;
API_AVAILABLE(ios(18.0), macos(15.0), tvos(18.0), watchos(11.0))
AX_EXTERN AXTechnology AXTechnologyVoiceSwitch;

#pragma mark - AXRequest (iOS 18.0)

API_AVAILABLE(ios(18.0), macos(15.0), tvos(18.0), watchos(11.0))

#pragma mark - AXFeatureOverrideSession (iOS 18.2)

API_AVAILABLE(ios(18.2))

API_AVAILABLE(ios(18.2))
AX_EXTERN NSErrorDomain const AXFeatureOverrideSessionErrorDomain;

API_AVAILABLE(ios(18.2))

API_AVAILABLE(ios(18.2))

API_AVAILABLE(ios(18.2))

#pragma mark - AXBrailleTable, AXBrailleTranslationResult, AXBrailleTranslator (iOS 26.0)

API_AVAILABLE(ios(26.0))

API_AVAILABLE(ios(26.0))

API_AVAILABLE(ios(26.0))

NS_ASSUME_NONNULL_END
