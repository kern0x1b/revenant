#import "CharonCallKit.h"

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
