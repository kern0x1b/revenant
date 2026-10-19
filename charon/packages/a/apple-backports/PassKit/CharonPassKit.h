// The shared piece of the PassKit objects: what a device with no wallet hardware says when one of
// these members is reached for, and the reason, in one place so the objects of the releases below do
// not each carry a second copy of the same sentence.
#import <PassKit/PassKit.h>

// The two 26.0 enumerations, with the SDK 26.2's own names and values.
//
// The SDK this package is built against -- 16.4 -- does not declare them at all: 16.4's
// PassKit.framework has no -authorizationStatusForCapability:, no
// -requestAuthorizationForCapability:completion: and no PKPassLibraryCapability. The 26.2 SDK names
// them, and these are its values, measured in
// iPhoneOS26.2.sdk/System/Library/Frameworks/PassKit.framework/Headers/PKPassLibrary.h:30-39:
//
//   typedef NS_ENUM(NSInteger, PKPassLibraryCapability) {
//       PKPassLibraryCapabilityBackgroundAddPasses,
//   } NS_SWIFT_NAME(PKPassLibrary.Capability) API_AVAILABLE(ios(26.0), watchos(26.0));
//
//   typedef NS_ENUM(NSInteger, PKPassLibraryAuthorizationStatus) {
//       PKPassLibraryAuthorizationStatusNotDetermined = -1,
//       PKPassLibraryAuthorizationStatusDenied         =  0,
//       PKPassLibraryAuthorizationStatusAuthorized     =  1,
//       PKPassLibraryAuthorizationStatusRestricted     =  2,
//   } NS_SWIFT_NAME(PKPassLibrary.AuthorizationStatus) API_AVAILABLE(ios(26.0), watchos(26.0));
//
// NotDetermined is -1, NOT 0. 0 is Denied, which is the answer that says the hardware refused.
//
// Declared ONLY where the build's own SDK does not have them, because a second typedef of the same
// enum is a hard error and an SDK that has them must keep its own. The discriminator is the SDK's own
// __IPHONE_OS_VERSION_MAX_ALLOWED, which is __IPHONE_16_4 against 16.4 and __IPHONE_26_x against 26.2
// (measured with `clang -E -dM` on each). The enumerations arrived in 26.0, so the guard is 26.0.
#if !defined(__IPHONE_26_0)

typedef NS_ENUM(NSInteger, PKPassLibraryCapability) {
    PKPassLibraryCapabilityBackgroundAddPasses = 0,
} __attribute__((availability(ios, introduced = 26.0)));

typedef NS_ENUM(NSInteger, PKPassLibraryAuthorizationStatus) {
    PKPassLibraryAuthorizationStatusNotDetermined = -1,
    PKPassLibraryAuthorizationStatusDenied = 0,
    PKPassLibraryAuthorizationStatusAuthorized = 1,
    PKPassLibraryAuthorizationStatusRestricted = 2,
} __attribute__((availability(ios, introduced = 26.0)));

#endif

// PKPassKitErrorDomain is LINKED, never defined: -PKPassKitErrorDomain is first exported at 6.0
// (measured through the gate's own first_releases over the armv7 cache of 6.1.3), so the release
// owns the string and this package names it. The code is the header's own PKUnsupportedVersionError
// (2), the nearest the enumeration comes to "this device cannot do that".
extern NSError *CharonPassKitNoHardwareError(void);
