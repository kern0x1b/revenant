#import <AppTrackingTransparency/ATTrackingManager.h>

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
