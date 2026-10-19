#import <Foundation/Foundation.h>

#ifdef CHARON_PORT
#import <FileProvider/FileProvider.h>
#define MGR CharonFPManager
#define ERRDOMAIN CharonFPErrorDomain
@interface CharonFPManager : NSObject
+ (void)getDomainsWithCompletionHandler:(void (^)(NSArray *domains, NSError *error))completionHandler;
+ (instancetype)managerForDomain:(NSFileProviderDomain *)domain;
- (void)getUserVisibleURLForItemIdentifier:(NSFileProviderItemIdentifier)itemIdentifier
                         completionHandler:(void (^)(NSURL *url, NSError *error))completionHandler;
@end
extern NSString *const CharonFPErrorDomain;
#else
#import <FileProvider/FileProvider.h>
#define MGR NSFileProviderManager
#define ERRDOMAIN NSFileProviderErrorDomain
#endif

static void print_pair(const char *key, const char *value)
{
    printf("%s\t%s\n", key, value ? value : "(nil)");
}

int main(void) { @autoreleasepool {
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    __block NSArray *domains = nil;
    __block NSError *domainError = nil;
    [MGR getDomainsWithCompletionHandler:^(NSArray *got, NSError *error) {
        domains = got; domainError = error; dispatch_semaphore_signal(done);
    }];
    dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
    printf("getDomains.count\t%lu\n", (unsigned long)domains.count);
    print_pair("getDomains.error.domain", domainError.domain.UTF8String);
    printf("getDomains.error.code\t%ld\n", domainError ? (long)domainError.code : 0L);

    NSFileProviderDomain *unregistered = [[NSFileProviderDomain alloc]
        initWithIdentifier:@"charon.probe.unregistered" displayName:@"charon probe"];
    printf("managerForDomain.isNil\t%s\n", [MGR managerForDomain:unregistered] ? "false" : "true");

    {
        MGR *m = [MGR managerForDomain:unregistered];
        dispatch_semaphore_t itemDone = dispatch_semaphore_create(0);
        __block BOOL hasURL = NO;
        [m getUserVisibleURLForItemIdentifier:@"charon.probe"
                           completionHandler:^(NSURL *url, NSError *error) {
            hasURL = (url != nil); dispatch_semaphore_signal(itemDone);
        }];
        dispatch_semaphore_wait(itemDone, DISPATCH_TIME_FOREVER);
        printf("userVisibleURLForItem.isNil\t%s\n", hasURL ? "false" : "true");
    }

    NSError *noSuchItem = [NSError errorWithDomain:ERRDOMAIN
                                               code:NSFileProviderErrorNoSuchItem
                                           userInfo:@{NSLocalizedDescriptionKey: @"no such item"}];
    NSError *unreachable = [NSError errorWithDomain:ERRDOMAIN
                                                code:NSFileProviderErrorServerUnreachable
                                            userInfo:@{NSLocalizedDescriptionKey: @"server unreachable"}];
    print_pair("error.domain", noSuchItem.domain.UTF8String);
    printf("NoSuchItem\t%ld\n", (long)noSuchItem.code);
    printf("ServerUnreachable\t%ld\n", (long)unreachable.code);
    return 0;
} }
