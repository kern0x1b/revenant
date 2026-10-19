// The transport itself: the request, the connection, the answer.
//
// It is NSURLConnection and not the NSURLSession of the Foundation backports, on purpose. A CloudKit
// client is very often a daemon - an extension, a background agent, a sync process - and a library
// that can only answer over NSURLSession drags libFoundationBackports' whole session stack, its
// operation queue and its delegate dispatch, into a process that wanted a container. NSURLConnection
// is the release's own, it is there, and one CloudKit request is one connection.
//
// The contract of the transport is narrow and the whole of it is in `-performContainer:`:
//
//  * a request is JSON, under `https://api.apple-cloudkit.com/database/1/<container>/<environment>/…`,
//    with `Authorization: Bearer <token>` and `Content-Type: application/json`;
//  * a 2xx answer with a JSON body is handed back decoded, a 2xx one without is handed back nil;
//  * a 4xx or 5xx answer is a CKError built from the payload's own error members;
//  * a connection that never completed is CKErrorNetworkUnavailable or CKErrorNetworkFailure, the
//    two the CKErrorCode header names for it;
//  * the completion is called exactly once, and never on the caller's thread - the caller's own
//    thread is the one it called from, and CloudKit's own answer is on another.
//
// What is refused before a connection is made: no container identifier answers
// CKErrorBadContainer, and no token to send with answers CKErrorNotAuthenticated. Both are the codes
// the header names for those two cases, and both are worth refusing here rather than sending a
// request that cannot succeed.

#import "CharonCloudKit.h"
#import "CharonCKConstants.h"

#import <objc/runtime.h>

@interface CharonCKRequest : NSObject <NSURLConnectionDataDelegate>
@property (nonatomic, strong) NSMutableURLRequest *request;
@property (nonatomic, copy) CharonCKCompletion completion;
@property (nonatomic, assign) BOOL finished;
@property (nonatomic, strong) NSMutableData *body;
@property (nonatomic, assign) NSInteger status;
- (void)finishBody:(id)body error:(NSError *)error;
@end

@implementation CharonCKRequest

@synthesize request = _request;
@synthesize completion = _completion;
@synthesize finished = _finished;
@synthesize body = _body;
@synthesize status = _status;

@end

@implementation CharonCKTransport

// The two tables are private, set once by +initialize and read through -containerForDatabase and
// -environmentForDatabase. The library compiles with -Werror=objc-missing-property-synthesis, so a
// property the class owns is synthesised EXPLICITLY: @dynamic would be the wrong answer here, because
// +initialize below writes _containers and _environments, and those ivars exist only if the compiler
// synthesises them.
@synthesize containers = _containers;
@synthesize environments = _environments;

+ (instancetype)shared
{
    static CharonCKTransport *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[self alloc] init];
        shared->_containers = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsObjectPointerPersonality
                                                   valueOptions:NSPointerFunctionsObjectPointerPersonality];
        shared->_environments = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsObjectPointerPersonality
                                                      valueOptions:NSPointerFunctionsObjectPointerPersonality];
    });
    return shared;
}

- (void)setContainer:(CKContainer *)container forDatabase:(CKDatabase *)database environment:(NSString *)environment
{
    [self.containers setObject:container forKey:database];
    [self.environments setObject:environment forKey:database];
}

- (NSMapTable *)containerForDatabase
{
    return self.containers;
}

- (NSMapTable *)environmentForDatabase
{
    return self.environments;
}

// A container is in the production environment when its own environment says so. The key CloudKit's
// own tooling writes in the Info.plist of a shipped application is `CKContainerEnvironment`; a
// container that says neither is in development, which is the environment CloudKit creates a
// container in and the only one a container of a development build can be in.
- (NSString *)environmentForContainer:(CKContainer *)container
{
    id declared = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CKContainerEnvironment"];
    if ([declared isKindOfClass:[NSString class]] &&
        ([declared caseInsensitiveCompare:@"Production"] == NSOrderedSame ||
         [declared caseInsensitiveCompare:@"production"] == NSOrderedSame)) {
        return CharonCKProductionEnvironment;
    }
    return CharonCKDevelopmentEnvironment;
}

- (void)performContainer:(CKContainer *)container
                database:(CKDatabase *)database
             environment:(NSString *)environment
                  method:(NSString *)method
                    path:(NSString *)path
                    body:(NSDictionary *)body
              completion:(CharonCKCompletion)completion
{
    if (!completion) {
        return;
    }
    // A container with no identifier is a process with no iCloud container entitlement, which is what
    // the host's own CloudKit answers by raising `containerIdentifier can not be nil`. Raising takes
    // the process down and leaves a caller nothing to do; the code the header names for an
    // un-provisioned container does leave it something, so that is what this answers.
    NSString *identifier = container.containerIdentifier;
    if (!identifier.length) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            completion(nil, CharonCKBadContainer(nil));
        });
        return;
    }
    NSError *error = nil;
    NSString *token = [[CharonCKCredentials shared] tokenForContainer:identifier error:&error];
    if (!token) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            completion(nil, error ?: CharonCKNotAuthenticated());
        });
        return;
    }
    NSString *root = database ? [self databaseRootForContainer:identifier database:database environment:environment]
                              : [NSString stringWithFormat:@"%@/%@", containerEnvironmentRoot(identifier, environment), path];
    NSURL *url = [NSURL URLWithString:[CharonCKHost stringByAppendingFormat:@"/%@", root]];
    if (!url) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            completion(nil, CharonCKError(CKErrorInvalidArguments, @"The path is not a URL", nil));
        });
        return;
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = method;
    [request setValue:[NSString stringWithFormat:@"Bearer %@", token] forHTTPHeaderField:@"Authorization"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:identifier forHTTPHeaderField:@"X-CloudKit-Container"];
    if (body) {
        NSError *encoded = nil;
        NSData *json = [NSJSONSerialization dataWithJSONObject:body options:0 error:&encoded];
        if (!json) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                completion(nil, CharonCKError(CKErrorInvalidArguments, @"The request is not JSON", nil));
            });
            return;
        }
        request.HTTPBody = json;
    }
    [self send:request completion:completion];
}

// The database root of the interface: `database/1/<container>/<environment>/<scope>`.
static NSString *containerEnvironmentRoot(NSString *identifier, NSString *environment)
{
    return [NSString stringWithFormat:@"database/1/%@/%@", identifier, environment];
}

- (NSString *)databaseRootForContainer:(NSString *)identifier database:(CKDatabase *)database environment:(NSString *)environment
{
    CKDatabaseScope scope = database.databaseScope;
    NSString *root = (scope == CKDatabaseScopePublic) ? @"public"
                     : (scope == CKDatabaseScopeShared) ? @"shared" : @"private";
    return [NSString stringWithFormat:@"%@/%@", containerEnvironmentRoot(identifier, environment), root];
}

// The connection, and the one place the answer becomes a completion. `finished` is what makes the
// promise of exactly one call true: a connection that fails after its delegate was told, and a
// delegate that is told after a failure, both reach here, and only the first of them gets through.
- (void)send:(NSURLRequest *)request completion:(CharonCKCompletion)completion
{
    CharonCKRequest *pending = [[CharonCKRequest alloc] init];
    pending.request = [request mutableCopy];
    pending.completion = completion;
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:pending startImmediately:NO];
    if (!connection) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            completion(nil, CharonCKTransportError([NSError errorWithDomain:NSURLErrorDomain
                                                                       code:NSURLErrorUnknown
                                                                   userInfo:nil]));
        });
        return;
    }
    [connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [connection start];
}


@end

@implementation CharonCKRequest (CharonCKOneShot)

- (void)finishBody:(id)body error:(NSError *)error
{
    if (self.finished) {
        return;
    }
    self.finished = YES;
    CharonCKCompletion completion = self.completion;
    // CloudKit's own answer is never on the caller's thread, and a caller that has to check which
    // thread it is on has been handed something the framework did not.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        completion(body, error);
    });
}


- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSInteger status = [(NSHTTPURLResponse *)response statusCode];
        ((CharonCKRequest *)self).status = status;
    }
}

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request
        redirectResponse:(NSURLResponse *)redirectResponse
{
    // A CloudKit service does not redirect a database request, and a redirect that carried the
    // Authorization header somewhere else would be a token in the wrong place.
    return redirectResponse ? nil : request;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    CharonCKRequest *pending = (CharonCKRequest *)self;
    if (!pending.body) {
        pending.body = [NSMutableData data];
    }
    [(NSMutableData *)pending.body appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    CharonCKRequest *pending = (CharonCKRequest *)self;
    NSInteger status = pending.status;
    NSData *data = pending.body;
    if (status >= 400) {
        id payload = data.length ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
        [pending finishBody:nil error:CharonCKErrorFromPayload([payload isKindOfClass:[NSDictionary class]] ? payload : nil, nil)];
        return;
    }
    if (!data.length) {
        [pending finishBody:nil error:nil];
        return;
    }
    NSError *decoded = nil;
    id payload = [NSJSONSerialization JSONObjectWithData:data options:0 error:&decoded];
    if (!payload) {
        [pending finishBody:nil error:CharonCKTransportError(decoded)];
        return;
    }
    [pending finishBody:payload error:nil];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    CharonCKRequest *pending = (CharonCKRequest *)self;
    [pending finishBody:nil error:CharonCKTransportError(error)];
}

@end
