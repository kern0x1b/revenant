#import "RevenantUserNotifications.h"

void revenant_on_main(void (^work)(void))
{
    if ([NSThread isMainThread])
        work();
    else
        dispatch_sync(dispatch_get_main_queue(), work);
}

NSError *revenant_unsupported(NSString *reason)
{
    return [NSError errorWithDomain:NSCocoaErrorDomain code:NSFeatureUnsupportedError
                           userInfo:@{NSLocalizedDescriptionKey: reason}];
}
