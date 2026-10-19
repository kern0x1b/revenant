#import <PassKit/PassKit.h>

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

extern NSError *RevenantPassKitNoHardwareError(void);
