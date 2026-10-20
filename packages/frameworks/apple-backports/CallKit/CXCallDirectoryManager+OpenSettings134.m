#import <CallKit/CallKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation CXCallDirectoryManager (RevenantOpenSettings)

- (void)openSettingsWithCompletionHandler:(void (^)(NSError *error))completion
{
    if (!completion)
        return;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        completion([NSError errorWithDomain:NSCocoaErrorDomain code:NSFeatureUnsupportedError userInfo:nil]);
    });
}

@end
