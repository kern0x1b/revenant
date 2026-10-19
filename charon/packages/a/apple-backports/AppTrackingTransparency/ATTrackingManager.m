#import <AppTrackingTransparency/ATTrackingManager.h>

// iOS 6.1.3 has no tracking authorization: no tccd asks, no prompt is put up and no setting
// restricts the advertising identifier, whose AdSupport of the release exports
// -[ASIdentifierManager advertisingIdentifier] and no -trackingEnabled at all. The status a
// question gets is therefore never decided, and a request is answered at once with the status
// it already had, which is what the host answers for a platform that does not run the system
// either (facts/AppTrackingTransparency/ATTrackingManager.md).

@implementation ATTrackingManager

+ (ATTrackingManagerAuthorizationStatus)trackingAuthorizationStatus
{
    return ATTrackingManagerAuthorizationStatusNotDetermined;
}

+ (void)requestTrackingAuthorizationWithCompletionHandler:(void (^)(ATTrackingManagerAuthorizationStatus status))completion
{
    if (completion) {
        completion(ATTrackingManagerAuthorizationStatusNotDetermined);
    }
}

@end
