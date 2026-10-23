#import <Foundation/Foundation.h>

__attribute__((visibility("hidden")))
@interface RevenantEphemeralCookieStorage : NSHTTPCookieStorage {
@package
    NSMutableArray *_storedCookies;
    NSHTTPCookieAcceptPolicy _policy;
    NSURL *_persistentURL;
    NSDate *_loaded;
}
@end

NSHTTPCookieStorage *revenant_ephemeral_cookie_storage(void);
NSHTTPCookieStorage *revenant_group_cookie_storage(NSString *identifier, NSURL *container);
