#import "RevenantCookieStorage.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation NSHTTPCookieStorage (RevenantGroup9)

+ (NSHTTPCookieStorage *)sharedCookieStorageForGroupContainerIdentifier:(NSString *)identifier
{
    NSURL *container = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:identifier];
    return revenant_group_cookie_storage(identifier, container);
}

@end
