#import "CharonCallKit.h"

// iOS 6 loads no application extensions (facts/Foundation/CloudAndExtensions.md), so no identifier names a call
// directory extension here: each one is answered as the system answers an identifier it has no extension for, on a
// queue of its own, as the system's answers come.
@implementation CXCallDirectoryManager

+ (CXCallDirectoryManager *)sharedInstance
{
    static CXCallDirectoryManager *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

static NSError *charon_no_extension(void)
{
    return [NSError errorWithDomain:CXErrorDomainCallDirectoryManager code:CXErrorCodeCallDirectoryManagerErrorNoExtensionFound userInfo:nil];
}

- (void)reloadExtensionWithIdentifier:(NSString *)identifier completionHandler:(void (^)(NSError *error))completion
{
    if (!completion)
        return;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        completion(charon_no_extension());
    });
}

- (void)getEnabledStatusForExtensionWithIdentifier:(NSString *)identifier
                                 completionHandler:(void (^)(CXCallDirectoryEnabledStatus enabledStatus, NSError *error))completion
{
    if (!completion)
        return;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        completion(CXCallDirectoryEnabledStatusUnknown, charon_no_extension());
    });
}

@end
