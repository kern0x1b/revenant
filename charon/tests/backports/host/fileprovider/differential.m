// One probe, built twice, and the two answers diffed.
//
// The keys are the lines macOS offers: getDomains, managerForDomain: and the error constants.
// Members the macOS header marks unavailable - +defaultManager, providerIdentifier,
// placeholderURLForURL: - do not enter this, and stay under "documentation" in
// facts/FileProvider/Manager.h, which is what the table says.
//
// The output is key<TAB>value, not prose: a diff of two of these is a verdict, and a verdict
// cannot be produced by reading a human-readable line with a pattern.
//
//   CHARON_PORT  when set, the probe calls the PORT's class by its renamed name, which is what
//                -DNSFileProviderManager=CharonFPManager gives the port's .m. The host build
//                calls Apple's own, and the two are diffed.

#import <Foundation/Foundation.h>

#ifdef CHARON_PORT
#import <FileProvider/FileProvider.h>
#define MGR CharonFPManager
#define ERRDOMAIN CharonFPErrorDomain
// The renamed class and the renamed domain come from the port's object, and the port's header
// declares only the category on them, so the two the probe CALLS are declared here. These are
// the three read-only members; the probe calls nothing that changes a machine's state.
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
    // getDomains: how many, and with what error. The port answers synchronously and the host
    // answers on a queue, so the probe waits either way and both answers are the same call.
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

    // managerForDomain: on a domain that is not registered. The host answers a manager; nil is the
    // answer the ledger's first guess gave and the header does not.
    NSFileProviderDomain *unregistered = [[NSFileProviderDomain alloc]
        initWithIdentifier:@"charon.probe.unregistered" displayName:@"charon probe"];
    printf("managerForDomain.isNil\t%s\n", [MGR managerForDomain:unregistered] ? "false" : "true");

    // The 16.0 member the macOS header declares with no availability gate, and which is READ-ONLY:
    // a lookup that answers a URL for an item. getIdentifierForUserVisibleFileAtURL: is in the same
    // header but is FILEPROVIDER_API_AVAILABILITY_V3_IOS - iOS-only - so it does not enter this.
    // The 16.0 member the macOS header declares with no availability gate, and which are
    // READ-ONLY: a lookup that answers a URL and a lookup that answers an identifier. Neither
    // changes a machine's state, and both are in the differential.
    {
        // An INSTANCE method, so it needs a manager; managerForDomain: is read-only and is already
        // measured above, and obtaining one changes nothing on either side.
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

    // The constants, by the domain's own spelling: the codes are Apple's, and a port that
    // exports the wrong number is caught here.
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
