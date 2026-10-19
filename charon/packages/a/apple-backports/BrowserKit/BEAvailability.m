#import <Foundation/Foundation.h>

// Whether this device may run a browser engine of its own inside a web browser, iOS 18.4. The port's
// build SDK is charon@iphoneos-sdk 16.4, which predates BrowserKit, so the declaration the header of
// the 26.2 SDK gives is written here (facts/BrowserKit/BEAvailability.md).

typedef NS_ENUM(NSInteger, BEEligibilityContext) {
    BEEligibilityContextWebBrowser
};

@interface BEAvailability : NSObject

+ (void)isEligibleForContext:(BEEligibilityContext)context completionHandler:(void (^)(BOOL eligible, NSError *error))completionHandler;

@end

// Eligibility is the system's to decide, from an entitlement the vendor of the operating system grants
// and an operating system release that supports it. iOS 6.1.3 has neither: the release predates the
// entitlement by a decade and carries no BrowserKit, so nothing can be eligible on it, and the answer
// is the same for every context - the one context there is, and any other a caller passes, which the
// release has no meaning for either.
@implementation BEAvailability

+ (void)isEligibleForContext:(BEEligibilityContext)context completionHandler:(void (^)(BOOL eligible, NSError *error))completionHandler
{
    if (completionHandler) {
        completionHandler(NO, nil);
    }
}

@end
