#import "RevenantCloudKit.h"
#import "RevenantCKConstants.h"

#import <objc/runtime.h>

@interface RevenantCKRequest : NSObject <NSURLConnectionDataDelegate>
@property (nonatomic, strong) NSMutableURLRequest *request;
@property (nonatomic, copy) RevenantCKCompletion completion;
@property (nonatomic, assign) BOOL finished;
@property (nonatomic, strong) NSMutableData *body;
@property (nonatomic, assign) NSInteger status;
- (void)finishBody:(id)body error:(NSError *)error;
@end

@implementation RevenantCKRequest

@synthesize request = _request;
@synthesize completion = _completion;
@synthesize finished = _finished;
@synthesize body = _body;
@synthesize status = _status;

@end

@implementation RevenantCKTransport

@synthesize containers = _containers;
@synthesize environments = _environments;

+ (instancetype)shared
{
    static RevenantCKTransport *shared;
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

- (NSString *)environmentForContainer:(CKContainer *)container
{
    id declared = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CKContainerEnvironment"];
    if ([declared isKindOfClass:[NSString class]] &&
        ([declared caseInsensitiveCompare:@"Production"] == NSOrderedSame ||
         [declared caseInsensitiveCompare:@"production"] == NSOrderedSame)) {
        return RevenantCKProductionEnvironment;
    }
    return RevenantCKDevelopmentEnvironment;
}

- (void)performContainer:(CKContainer *)container
                database:(CKDatabase *)database
             environment:(NSString *)environment
                  method:(NSString *)method
                    path:(NSString *)path
                    body:(NSDictionary *)body
              completion:(RevenantCKCompletion)completion
{
    if (!completion) {
        return;
    }
    NSString *identifier = container.containerIdentifier;
    if (!identifier.length) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            completion(nil, RevenantCKBadContainer(nil));
        });
        return;
    }
    NSError *error = nil;
    NSString *token = [[RevenantCKCredentials shared] tokenForContainer:identifier error:&error];
    if (!token) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            completion(nil, error ?: RevenantCKNotAuthenticated());
        });
        return;
    }
    NSString *root = database ? [self databaseRootForContainer:identifier database:database environment:environment]
                              : [NSString stringWithFormat:@"%@/%@", containerEnvironmentRoot(identifier, environment), path];
    NSURL *url = [NSURL URLWithString:[RevenantCKHost stringByAppendingFormat:@"/%@", root]];
    if (!url) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            completion(nil, RevenantCKError(CKErrorInvalidArguments, @"The path is not a URL", nil));
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
                completion(nil, RevenantCKError(CKErrorInvalidArguments, @"The request is not JSON", nil));
            });
            return;
        }
        request.HTTPBody = json;
    }
    [self send:request completion:completion];
}

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

- (void)send:(NSURLRequest *)request completion:(RevenantCKCompletion)completion
{
    RevenantCKRequest *pending = [[RevenantCKRequest alloc] init];
    pending.request = [request mutableCopy];
    pending.completion = completion;
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:pending startImmediately:NO];
    if (!connection) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            completion(nil, RevenantCKTransportError([NSError errorWithDomain:NSURLErrorDomain
                                                                       code:NSURLErrorUnknown
                                                                   userInfo:nil]));
        });
        return;
    }
    [connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [connection start];
}


@end

@implementation RevenantCKRequest (RevenantCKOneShot)

- (void)finishBody:(id)body error:(NSError *)error
{
    if (self.finished) {
        return;
    }
    self.finished = YES;
    RevenantCKCompletion completion = self.completion;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        completion(body, error);
    });
}


- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSInteger status = [(NSHTTPURLResponse *)response statusCode];
        ((RevenantCKRequest *)self).status = status;
    }
}

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request
        redirectResponse:(NSURLResponse *)redirectResponse
{
    return redirectResponse ? nil : request;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    RevenantCKRequest *pending = (RevenantCKRequest *)self;
    if (!pending.body) {
        pending.body = [NSMutableData data];
    }
    [(NSMutableData *)pending.body appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    RevenantCKRequest *pending = (RevenantCKRequest *)self;
    NSInteger status = pending.status;
    NSData *data = pending.body;
    if (status >= 400) {
        id payload = data.length ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
        [pending finishBody:nil error:RevenantCKErrorFromPayload([payload isKindOfClass:[NSDictionary class]] ? payload : nil, nil)];
        return;
    }
    if (!data.length) {
        [pending finishBody:nil error:nil];
        return;
    }
    NSError *decoded = nil;
    id payload = [NSJSONSerialization JSONObjectWithData:data options:0 error:&decoded];
    if (!payload) {
        [pending finishBody:nil error:RevenantCKTransportError(decoded)];
        return;
    }
    [pending finishBody:payload error:nil];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    RevenantCKRequest *pending = (RevenantCKRequest *)self;
    [pending finishBody:nil error:RevenantCKTransportError(error)];
}

@end
