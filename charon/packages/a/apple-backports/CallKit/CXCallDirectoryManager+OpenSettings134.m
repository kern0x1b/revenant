#import <CallKit/CallKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

// The settings page of call directories came with them; iOS 6 has none to open, and later releases give an
// application no public way to open theirs. The answer is the one the host's CallKit gives where it has no such
// page (Mac Catalyst, 2026-09-23): NSFeatureUnsupportedError.
@implementation CXCallDirectoryManager (CharonOpenSettings)

- (void)openSettingsWithCompletionHandler:(void (^)(NSError *error))completion
{
    if (!completion)
        return;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        completion([NSError errorWithDomain:NSCocoaErrorDomain code:NSFeatureUnsupportedError userInfo:nil]);
    });
}

@end
